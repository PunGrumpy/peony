import Darwin
import Foundation
import Testing
@testable import PeonyCore

struct TunnelProcessTests {
  @Test func `a client that exits on interrupt ends with its status`() async throws {
    let run = try Run(script: """
      trap 'kill $! 2>/dev/null; echo bye; exit 3' INT
      \(Run.idle)
      """)
    defer { run.cleanUp() }
    try await run.waitUntilReady()

    let ending = await run.process.stop(.plain)

    #expect(ending == .exited(3))
    #expect(run.recorder.lines.last == "bye")
    #expect(run.recorder.status == 3)
  }

  @Test func `a client hung after the link-down line gets a second interrupt and exits within the grace`() async throws {
    let run = try Run(script: """
      n=0
      on_int() {
        kill $! 2>/dev/null
        n=$((n+1))
        if [ $n -ge 2 ]; then exit 5; fi
        echo "INFO:   Closed connection to gateway."
      }
      trap on_int INT
      \(Run.idle)
      """)
    defer { run.cleanUp() }
    try await run.waitUntilReady()

    let start = ContinuousClock.now
    let ending = await run.process.stop(.forti)
    let elapsed = ContinuousClock.now - start

    #expect(ending == .exited(5))
    #expect(elapsed >= .milliseconds(900))
    // Under the 8 s limit proves the second interrupt ended it. CI may be compiling alongside.
    #expect(elapsed < .seconds(6))
  }

  @Test func `a client that ignores interrupts is abandoned at the limit`() async throws {
    let run = try Run(script: """
      trap '' INT
      \(Run.idle)
      """)
    defer { run.cleanUp() }
    try await run.waitUntilReady()

    var plan = TeardownPlan.plain
    plan.limit = .milliseconds(300)
    let ending = await run.process.stop(plan)
    #expect(ending == .abandoned)

    let seen = run.recorder.lines
    run.terminate()
    try await Task.sleep(for: .milliseconds(500))
    #expect(run.recorder.lines == seen)
    #expect(run.recorder.status == nil)
  }

  @Test func `plain never sends a second interrupt`() async throws {
    let run = try Run(script: """
      on_int() { kill $! 2>/dev/null; echo x >> "$COUNT"; echo "INFO:   Closed connection to gateway."; }
      trap on_int INT
      \(Run.idle)
      """)
    defer { run.cleanUp() }
    try await run.waitUntilReady()

    var plan = TeardownPlan.plain
    plan.logoutGrace = .milliseconds(100)
    plan.limit = .milliseconds(1200)
    let ending = await run.process.stop(plan)

    #expect(ending == .abandoned)
    #expect(run.interruptCount == 1)
  }

  @Test func `forti recognises the closing line as logged by openfortivpn`() {
    #expect(TeardownPlan.forti.isLinkDown("INFO:   Closed connection to gateway."))
    #expect(!TeardownPlan.forti.isLinkDown("INFO:   Tunnel is up and running."))
    #expect(!TeardownPlan.plain.isLinkDown("INFO:   Closed connection to gateway."))
  }

  @Test func `partial output is flushed at exit`() async throws {
    let run = try Run(script: "printf 'one\\ntwo'", ready: false)
    defer { run.cleanUp() }

    try await run.recorder.wait { $0.status != nil }

    #expect(run.recorder.lines == ["one", "two"])
    #expect(run.recorder.status == 0)
  }

  @Test func `output split across reads comes back as whole lines`() async throws {
    let run = try Run(script: """
      printf 'caf\\303'; sleep 0.2; printf '\\251 au '; sleep 0.2; printf 'lait\\nnext\\n'
      """, ready: false)
    defer { run.cleanUp() }

    try await run.recorder.wait { $0.status != nil }

    #expect(run.recorder.lines == ["café au lait", "next"])
  }

  @Test func `two stops join and interrupt once`() async throws {
    let run = try Run(script: """
      trap 'kill $! 2>/dev/null; echo x >> "$COUNT"; exit 3' INT
      \(Run.idle)
      """)
    defer { run.cleanUp() }
    try await run.waitUntilReady()

    async let first = run.process.stop(.plain)
    async let second = run.process.stop(.plain)
    let endings = await [first, second]

    #expect(endings == [.exited(3), .exited(3)])
    #expect(run.interruptCount == 1)
  }

  @Test func `stopping a client that already exited returns its status`() async throws {
    let run = try Run(script: "exit 7", ready: false)
    defer { run.cleanUp() }
    try await run.recorder.wait { $0.status != nil }

    #expect(await run.process.stop(.plain) == .exited(7))
  }
}

/// A `/bin/sh` script run as a client. Scripts set their traps before they print the ready line,
/// so a signal sent after the wait can't arrive too early. `idle` blocks in `wait` so traps run at once.
private struct Run {
  static let idle = """
    trap 'kill $! 2>/dev/null; exit 0' TERM
    echo "pid $$"
    echo ready
    while :; do sleep 31 & wait $!; done
    """

  let process: TunnelProcess
  let recorder = Recorder()
  private let directory: URL
  private let countFile: URL

  init(script: String, ready: Bool = true) throws {
    directory = FileManager.default.temporaryDirectory.appending(path: "peony-tunnel-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    countFile = directory.appending(path: "interrupts")
    process = TunnelProcess(executable: "/bin/sh", arguments: ["-c", "COUNT='\(countFile.path)'\n" + script])
    let recorder = recorder
    try process.start(input: Data(), onLine: { recorder.add($0) }, onExit: { recorder.exit($0) })
  }

  func waitUntilReady() async throws {
    try await recorder.wait { $0.lines.contains("ready") }
  }

  var interruptCount: Int {
    ((try? String(contentsOf: countFile, encoding: .utf8)) ?? "").split(separator: "\n").count
  }

  /// Asks a script that is still running to leave, which also ends the `sleep` it started.
  /// Once, to the PID the script reported, because later the number could belong to someone else.
  /// A script that never got as far as reporting it gets an interrupt instead.
  func terminate() {
    guard recorder.status == nil, recorder.claimTermination() else { return }
    if let pid = recorder.pid { kill(pid, SIGTERM) } else { process.interrupt() }
  }

  func cleanUp() {
    terminate()
    try? FileManager.default.removeItem(at: directory)
  }
}

private final class Recorder: @unchecked Sendable {
  struct Snapshot {
    var lines: [String] = []
    var status: Int32?
  }

  private let lock = NSLock()
  private var current = Snapshot()
  private var terminated = false

  var lines: [String] { read().lines }
  var status: Int32? { read().status }

  var pid: pid_t? {
    lines.first { $0.hasPrefix("pid ") }.flatMap { pid_t($0.dropFirst(4)) }
  }

  func add(_ line: String) { lock.withLock { current.lines.append(line) } }
  func exit(_ status: Int32) { lock.withLock { current.status = status } }

  func claimTermination() -> Bool {
    lock.withLock {
      defer { terminated = true }
      return !terminated
    }
  }

  func wait(timeout: Duration = .seconds(30), until done: (Snapshot) -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !done(read()) {
      guard ContinuousClock.now < deadline else { throw TimedOut() }
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  private func read() -> Snapshot { lock.withLock { current } }
}

private struct TimedOut: Error {}
