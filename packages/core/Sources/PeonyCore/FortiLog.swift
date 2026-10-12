import Foundation

/// Something meaningful a tunnel process reported on its output.
public enum TunnelEvent: Equatable, Sendable {
  case tunnelUp
  case authenticationFailed
  /// The gateway presented a certificate that isn't trusted. `digest` is the
  /// pin the tool suggests trusting, when it printed one.
  case certificateRejected(digest: String?)
  /// sudo refused to run without a password: the sudoers rule is missing or doesn't match.
  case sudoNeedsPassword
  case error(String)
}

/// Reads openfortivpn's line-oriented log output.
///
/// The certificate failure spans several lines (the reason, then the suggested
/// `--trusted-cert` digest), so the parser keeps a little state between lines.
public struct FortiLogParser: Sendable {
  private var awaitingDigest = false

  public init() {}

  public mutating func consume(_ rawLine: String) -> TunnelEvent? {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    guard !line.isEmpty else { return nil }

    if awaitingDigest, let digest = Self.trustedCertDigest(in: line) {
      awaitingDigest = false
      return .certificateRejected(digest: digest)
    }
    if line.contains("Tunnel is up and running") {
      return .tunnelUp
    }
    if line.hasPrefix("sudo:"), line.contains("password is required") {
      return .sudoNeedsPassword
    }
    if line.contains("certificate validation failed") {
      awaitingDigest = true
      return nil
    }
    if line.contains("Could not authenticate") {
      return .authenticationFailed
    }
    if line.hasPrefix("ERROR:") {
      // A cert failure with no digest line still has to surface.
      if awaitingDigest {
        awaitingDigest = false
        return .certificateRejected(digest: nil)
      }
      let message = line.dropFirst("ERROR:".count).trimmingCharacters(in: .whitespaces)
      return .error(message)
    }
    return nil
  }

  static func trustedCertDigest(in line: String) -> String? {
    guard let match = line.firstMatch(of: /--trusted-cert\s+([0-9a-fA-F]{64})/) else { return nil }
    return String(match.1).lowercased()
  }
}
