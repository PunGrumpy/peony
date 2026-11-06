import Darwin
import Foundation
import Testing
@testable import PeonyCore

struct ProbeTests {
  @Test func `an open port answers`() async throws {
    let listener = try Listener()
    defer { close(listener.socket) }
    let ms = await Probe.connect(to: try #require(Probe.Target("127.0.0.1:\(listener.port)")))
    #expect(ms != nil)
  }

  @Test func `a closed port doesn't`() async throws {
    let listener = try Listener()
    close(listener.socket)
    let ms = await Probe.connect(to: try #require(Probe.Target("127.0.0.1:\(listener.port)")))
    #expect(ms == nil)
  }

  @Test func `a silent host times out`() async throws {
    // TEST-NET-1 never answers, so only the timeout can end the probe.
    let start = ContinuousClock.now
    let ms = await Probe.connect(to: try #require(Probe.Target("192.0.2.1:443")), timeout: .milliseconds(200))
    #expect(ms == nil)
    #expect(ContinuousClock.now - start < .seconds(2))
  }

  @Test func `a host is rechecked sooner the more it has failed`() {
    let seconds = (0...7).map { Probe.recheckDelay(failures: $0) }
    #expect(seconds == [30, 1, 2, 4, 8, 30, 30, 30].map { .seconds($0) })
  }

  @Test func `a host that starts answering shows up within about a second`() async throws {
    let reserved = try Listener()
    let port = reserved.port
    close(reserved.socket)
    let target = try #require(Probe.Target("127.0.0.1:\(port)"))

    // Opening the port inside the first failing report keeps the test from racing the one second recheck.
    let opened = Box<Listener?>(nil)
    defer { if let listener = opened.value { close(listener.socket) } }
    let reports = Reports { ms in
      if ms == nil, opened.value == nil { opened.value = try? Listener(port: port) }
    }
    let watching = Task { await Probe.watch([target], report: reports.record) }
    defer { watching.cancel() }

    try #require(await reports.wait(until: { !$0.isEmpty }, within: .seconds(10)))
    try #require(opened.value != nil)
    try #require(await reports.wait(until: { $0.contains { $0.milliseconds != nil } }, within: .seconds(10)))

    let all = reports.all
    let failed = try #require(all.first { $0.milliseconds == nil })
    let answered = try #require(all.first { $0.milliseconds != nil })
    // Well under the 30 s it used to take. `recheckDelay` pins the exact schedule, and CI may be compiling alongside.
    #expect(answered.at - failed.at < .seconds(10))
  }

  @Test func `a silent host doesn't hold back a fast one`() async throws {
    let listener = try Listener()
    defer { close(listener.socket) }
    let silent = try #require(Probe.Target("silent.invalid:443"))
    let fast = try #require(Probe.Target("127.0.0.1:\(listener.port)"))
    let reports = Reports()
    let watching = Task {
      await Probe.watch([silent, fast], check: { target in
        if target == silent {
          try? await Task.sleep(for: .seconds(60))
          return nil
        }
        return await Probe.connect(to: target)
      }, report: reports.record)
    }
    defer { watching.cancel() }

    try #require(await reports.wait(until: { $0.contains { $0.index == 1 } }, within: .seconds(10)))
    #expect(!reports.all.contains { $0.index == 0 })
  }

  @Test func `cancelling ends the watch`() async throws {
    let listener = try Listener()
    defer { close(listener.socket) }
    let target = try #require(Probe.Target("127.0.0.1:\(listener.port)"))
    let reports = Reports()
    let watching = Task { await Probe.watch([target], report: reports.record) }

    // An answering host sleeps 30 s before its next check, which cancelling has to cut short.
    try #require(await reports.wait(until: { !$0.isEmpty }, within: .seconds(10)))
    let start = ContinuousClock.now
    watching.cancel()
    await watching.value
    #expect(ContinuousClock.now - start < .seconds(5))
  }
}

private final class Box<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: Value

  init(_ value: Value) { stored = value }

  var value: Value {
    get { lock.withLock { stored } }
    set { lock.withLock { stored = newValue } }
  }

  func update(_ change: (inout Value) -> Void) {
    lock.withLock { change(&stored) }
  }
}

/// What `Probe.watch` reported, and when.
private final class Reports: @unchecked Sendable {
  struct Entry {
    var index: Int
    var milliseconds: Int?
    var at: ContinuousClock.Instant
  }

  private let entries = Box<[Entry]>([])
  private let onReport: @Sendable (Int?) -> Void

  init(onReport: @escaping @Sendable (Int?) -> Void = { _ in }) {
    self.onReport = onReport
  }

  var all: [Entry] { entries.value }

  var record: @Sendable (Int, Int?) async -> Void {
    { [self] index, ms in
      onReport(ms)
      entries.update { $0.append(Entry(index: index, milliseconds: ms, at: .now)) }
    }
  }

  func wait(until condition: ([Entry]) -> Bool, within limit: Duration) async -> Bool {
    let deadline = ContinuousClock.now + limit
    while ContinuousClock.now < deadline {
      if condition(all) { return true }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return condition(all)
  }
}

/// A TCP socket listening on a free loopback port.
private struct Listener {
  let socket: Int32
  let port: UInt16

  init(port: UInt16 = 0) throws {
    let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    var reuse: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    address.sin_port = port.bigEndian
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let bound = withUnsafeMutablePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, length) == 0 && listen(fd, 1) == 0 && getsockname(fd, $0, &length) == 0
      }
    }
    guard bound else {
      close(fd)
      throw POSIXError(.EADDRNOTAVAIL)
    }
    socket = fd
    self.port = UInt16(bigEndian: address.sin_port)
  }
}
