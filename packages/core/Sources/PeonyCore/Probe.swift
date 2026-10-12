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
    let connection = NWConnection(host: NWEndpoint.Host(target.host), port: port, using: .tcp)
    let start = ContinuousClock.now
    let outcome = OneShot()

    return await withCheckedContinuation { continuation in
      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          let elapsed = ContinuousClock.now - start
          let ms = Int(elapsed.components.seconds * 1000) + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
          if outcome.claim() { continuation.resume(returning: max(ms, 1)) }
          connection.cancel()
        case .failed, .waiting:
          if outcome.claim() { continuation.resume(returning: nil) }
          connection.cancel()
        default:
          break
        }
      }
      connection.start(queue: .global(qos: .utility))
      DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(timeout.components.seconds * 1000))) {
        if outcome.claim() { continuation.resume(returning: nil) }
        connection.cancel()
      }
    }
  }
}

/// Lets exactly one of several racing callbacks resume a continuation.
private final class OneShot: @unchecked Sendable {
  private let lock = NSLock()
  private var claimed = false

  func claim() -> Bool {
    lock.withLock {
      defer { claimed = true }
      return !claimed
    }
  }
}
