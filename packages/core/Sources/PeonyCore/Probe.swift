import Foundation
import Network

/// Checks whether a destination answers on TCP, and how fast.
public enum Probe {
  public struct Target: Equatable, Sendable {
    public var host: String
    public var port: UInt16

    /// Parses `host` or `host:port`; the port defaults to 443.
    public init?(_ text: String) {
      let trimmed = text.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { return nil }
      if let colon = trimmed.lastIndex(of: ":"), let port = UInt16(trimmed[trimmed.index(after: colon)...]) {
        host = String(trimmed[..<colon])
        self.port = port
      } else {
        host = trimmed
        port = 443
      }
      guard !host.isEmpty else { return nil }
    }
  }

  /// Milliseconds to a completed TCP handshake, or nil if it fails or takes longer than `timeout`.
  public static func connect(to target: Target, timeout: Duration = .seconds(3)) async -> Int? {
    guard let port = NWEndpoint.Port(rawValue: target.port) else { return nil }
    // Whichever finishes second is cancelled, so a fast answer leaves no timer behind.
    return await withTaskGroup(of: Int?.self) { group in
      group.addTask { await handshake(host: target.host, port: port) }
      group.addTask {
        try? await Task.sleep(for: timeout)
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first
    }
  }

  /// Seconds until a host is checked again: 30 once it answers; 1, 2, 4, 8 after consecutive failures, then 30.
  public static func recheckDelay(failures: Int) -> Duration {
    switch failures {
    case 1...4: .seconds(1 << (failures - 1))
    default: .seconds(30)
    }
  }

  /// Checks each host on its own schedule until cancelled, reporting every result as it lands.
  public static func watch(
    _ targets: [Target],
    timeout: Duration = .seconds(3),
    report: @escaping @Sendable (Int, Int?) async -> Void
  ) async {
    await withTaskGroup(of: Void.self) { group in
      for (index, target) in targets.enumerated() {
        group.addTask {
          var failures = 0
          while !Task.isCancelled {
            let ms = await connect(to: target, timeout: timeout)
            // A cancelled check reads as a failure, which isn't news to anyone.
            guard !Task.isCancelled else { return }
            await report(index, ms)
            failures = ms == nil ? failures + 1 : 0
            let delay = recheckDelay(failures: failures)
            // Tolerance lets macOS fold the slow wakeups in with others, which matters on battery.
            let tolerance: Duration = delay == .seconds(30) ? .seconds(10) : .zero
            guard (try? await Task.sleep(for: delay, tolerance: tolerance)) != nil else { return }
          }
        }
      }
    }
  }

  private static func handshake(host: String, port: NWEndpoint.Port) async -> Int? {
    let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
    let outcome = Outcome()
    let start = ContinuousClock.now
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        outcome.resolve(max(Int((ContinuousClock.now - start) / .milliseconds(1)), 1))
        connection.cancel()
      case .failed, .waiting, .cancelled:
        outcome.resolve(nil)
        connection.cancel()
      default:
        break
      }
    }
    return await withTaskCancellationHandler {
      connection.start(queue: .global(qos: .utility))
      return await withCheckedContinuation { outcome.wait($0) }
    } onCancel: {
      outcome.resolve(nil)
      connection.cancel()
    }
  }
}

/// Resumes a continuation exactly once with whichever callback settles first,
/// including one that lands before the continuation exists.
private final class Outcome: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Int?, Never>?
  private var result: Int??

  func wait(_ continuation: CheckedContinuation<Int?, Never>) {
    lock.lock()
    if let result {
      lock.unlock()
      continuation.resume(returning: result)
    } else {
      self.continuation = continuation
      lock.unlock()
    }
  }

  func resolve(_ value: Int?) {
    let waiting: CheckedContinuation<Int?, Never>? = lock.withLock {
      guard result == nil else { return nil }
      result = .some(value)
      defer { continuation = nil }
      return continuation
    }
    waiting?.resume(returning: value)
  }
}
