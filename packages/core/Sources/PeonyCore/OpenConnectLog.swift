import Foundation

/// Reads openconnect's output for the moments Peony cares about.
public struct OpenConnectLogParser: Sendable {
  public init() {}

  public func consume(_ rawLine: String) -> TunnelEvent? {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    guard !line.isEmpty else { return nil }

    if line.hasPrefix("Configured as") || line.contains("ESP session established")
      || line.contains("DTLS connected") || line.hasPrefix("Connected as") {
      return .tunnelUp
    }
    if let match = line.firstMatch(of: /--servercert\s+(pin-sha256:[A-Za-z0-9+\/=]+)/) {
      return .certificateRejected(digest: String(match.1))
    }
    if line.contains("Login failed") || line.contains("Failed to obtain WebVPN cookie")
      || line.contains("authentication failed") {
      return .authenticationFailed
    }
    if line.hasPrefix("sudo:"), line.contains("password is required") {
      return .sudoNeedsPassword
    }
    if line.hasPrefix("ERROR:") {
      return .error(line.dropFirst("ERROR:".count).trimmingCharacters(in: .whitespaces))
    }
    if line.hasPrefix("Failed to") || line.hasPrefix("Unknown protocol") {
      return .error(line)
    }
    return nil
  }
}
