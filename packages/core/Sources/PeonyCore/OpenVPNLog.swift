import Foundation

/// Reads openvpn's output for the moments Peony cares about.
///
/// A fatal error is printed on one line and followed by "Exiting due to fatal error", so the
/// parser keeps the line before it.
public struct OpenVPNLogParser: Sendable {
  private var previous: String?

  public init() {}

  public mutating func consume(_ rawLine: String) -> TunnelEvent? {
    var line = rawLine.trimmingCharacters(in: .whitespaces)
    if let stamp = line.prefixMatch(of: /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?: us=\d+)?\s/) {
      line = String(line[stamp.range.upperBound...])
    }
    guard !line.isEmpty else { return nil }
    defer { previous = line }

    if line.hasPrefix("Initialization Sequence Completed") {
      return .tunnelUp
    }
    if line.contains("AUTH_FAILED") {
      return .authenticationFailed
    }
    if line.hasPrefix("sudo:"), line.contains("password is required") {
      return .sudoNeedsPassword
    }
    if line.hasPrefix("ERROR:") {
      return .error(line.dropFirst("ERROR:".count).trimmingCharacters(in: .whitespaces))
    }
    if line.hasPrefix("Options error:") {
      return .error(line)
    }
    if line == "Exiting due to fatal error" {
      return .error(previous ?? line)
    }
    return nil
  }
}
