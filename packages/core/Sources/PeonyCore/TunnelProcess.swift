import Darwin
import Foundation

/// How to take one kind of client down.
public struct TeardownPlan: Sendable {
  /// A line that means the tunnel is gone and only a courtesy logout is left.
  public var isLinkDown: @Sendable (String) -> Bool
  /// How long a client may spend on that logout before it gets a second interrupt.
  public var logoutGrace: Duration
  /// When to stop waiting altogether, counted from the first interrupt.
  public var limit: Duration

  /// openfortivpn restores routes and DNS, prints this line, then opens a new connection to log out.
  /// That connect doesn't retry when interrupted, so with an unreachable gateway only a second interrupt ends it.
  public static let forti = TeardownPlan(
    isLinkDown: { $0.contains("Closed connection to gateway.") }, logoutGrace: .seconds(1), limit: .seconds(8))

  /// Clients that finish on the first interrupt.
  public static let plain = TeardownPlan(isLinkDown: { _ in false }, logoutGrace: .seconds(1), limit: .seconds(8))
}

/// One long-lived client, with its output as whole lines. No callback fires after `stop` returns.
public final class TunnelProcess: @unchecked Sendable {
  public enum Ending: Equatable, Sendable {
    case exited(Int32)
    /// Still running when the limit passed. Its output and exit are no longer reported.
    case abandoned
  }

  private struct Teardown {
    var plan: TeardownPlan
    var linkIsDown = false
  }

  private let executable: String
  private let arguments: [String]
  private let process = Process()
  private let queue = DispatchQueue(label: "app.peony.tunnel-process")

  // Everything below is touched only on `queue`, which also delivers the callbacks.
  private var onLine: (@Sendable (String) -> Void)?
  private var onExit: (@Sendable (Int32) -> Void)?
  private var source: DispatchSourceRead?
  private var readFD: Int32 = -1
  private var partial = Data()
  private var silenced = false
  private var ending: Ending?
  private var teardown: Teardown?
  private var waiters: [CheckedContinuation<Ending, Never>] = []

  public init(executable: String, arguments: [String]) {
    self.executable = executable
    self.arguments = arguments
  }

  /// `input` goes to the client's stdin and isn't kept: it can hold a password.
  public func start(
    input: Data, onLine: @escaping @Sendable (String) -> Void, onExit: @escaping @Sendable (Int32) -> Void
  ) throws {
    let stdin = Pipe()
    let output = Pipe()
    process.executableURL = URL(filePath: executable)
    process.arguments = arguments
    process.standardInput = stdin
    process.standardOutput = output
    process.standardError = output

    // Non-blocking, so the exit handler can take what is left without waiting for a
    // grandchild that still holds the pipe open.
    let reader = output.fileHandleForReading
    readFD = reader.fileDescriptor
    _ = fcntl(readFD, F_SETFL, fcntl(readFD, F_GETFL) | O_NONBLOCK)
    self.onLine = onLine
    self.onExit = onExit

    let source = DispatchSource.makeReadSource(fileDescriptor: readFD, queue: queue)
    source.setEventHandler { [self] in drain() }
    source.setCancelHandler { try? reader.close() }
    self.source = source
    source.resume()

    process.terminationHandler = { [self] finished in
      let status = finished.terminationStatus
      queue.async { self.exited(status) }
    }

    do {
      try process.run()
    } catch {
      process.terminationHandler = nil
      source.cancel()
      self.source = nil
      self.onLine = nil
      self.onExit = nil
      try? stdin.fileHandleForWriting.close()
      try? output.fileHandleForWriting.close()
      throw error
    }

    // Our copies of the child's ends, closed so the pipe can reach end of file.
    try? stdin.fileHandleForReading.close()
    try? output.fileHandleForWriting.close()
    let writer = stdin.fileHandleForWriting
    _ = fcntl(writer.fileDescriptor, F_SETNOSIGPIPE, 1)
    try? writer.write(contentsOf: input)
    try? writer.close()
  }

  /// One SIGINT, without waiting. `Process.interrupt` signals the client's whole process group, not
  /// only its first process, and that's what sudo and the helper have always received.
  public func interrupt() {
    if process.isRunning { process.interrupt() }
  }

  /// SIGINT. When a line matches `isLinkDown`, allow `logoutGrace`, then SIGINT again.
  /// At `limit` gives up with `.abandoned`. Resumes on exit, with no polling. A second call joins the first.
  public func stop(_ plan: TeardownPlan) async -> Ending {
    await withCheckedContinuation { continuation in
      queue.async { [self] in
        if let ending {
          continuation.resume(returning: ending)
          return
        }
        waiters.append(continuation)
        guard teardown == nil else { return }
        teardown = Teardown(plan: plan)
        interrupt()
        queue.asyncAfter(deadline: .now() + plan.limit.dispatchInterval) { [self] in
          guard ending == nil else { return }
          silenced = true
          resolve(.abandoned)
        }
      }
    }
  }

  // MARK: On the queue

  private func drain() {
    var buffer = [UInt8](repeating: 0, count: 4096)
    while source != nil {
      let count = read(readFD, &buffer, buffer.count)
      if count > 0 {
        receive(buffer[..<count])
      } else if count == 0 {
        source?.cancel()
        source = nil
      } else if errno != EINTR {
        break
      }
    }
  }

  private func receive(_ bytes: ArraySlice<UInt8>) {
    partial.append(contentsOf: bytes)
    while let newline = partial.firstIndex(of: 0x0A) {
      let line = String(decoding: partial[partial.startIndex..<newline], as: UTF8.self)
      partial.removeSubrange(partial.startIndex...newline)
      emit(line)
    }
  }

  private func emit(_ line: String) {
    guard !silenced else { return }
    if var current = teardown, !current.linkIsDown, current.plan.isLinkDown(line) {
      current.linkIsDown = true
      teardown = current
      queue.asyncAfter(deadline: .now() + current.plan.logoutGrace.dispatchInterval) { [self] in
        if ending == nil { interrupt() }
      }
    }
    onLine?(line)
  }

  private func exited(_ status: Int32) {
    drain()
    if !partial.isEmpty {
      let rest = String(decoding: partial, as: UTF8.self)
      partial.removeAll()
      emit(rest)
    }
    source?.cancel()
    source = nil
    if !silenced { onExit?(status) }
    onLine = nil
    onExit = nil
    resolve(.exited(status))
  }

  private func resolve(_ result: Ending) {
    guard ending == nil else { return }
    ending = result
    let waiting = waiters
    waiters.removeAll()
    for waiter in waiting { waiter.resume(returning: result) }
  }
}

extension Duration {
  fileprivate var dispatchInterval: DispatchTimeInterval {
    let (seconds, attoseconds) = components
    return .nanoseconds(Int(seconds) * 1_000_000_000 + Int(attoseconds / 1_000_000_000))
  }
}
