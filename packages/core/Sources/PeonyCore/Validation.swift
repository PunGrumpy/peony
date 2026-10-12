import Foundation

/// Input checks shared by the app (to explain problems while typing) and the
/// privileged helper (which trusts nothing). Every value that reaches a root
/// process passes through one of these.
public enum Validation {
  public enum Failure: Error, Equatable, CustomStringConvertible {
    case invalid(field: String, reason: String)

    public var description: String {
      switch self {
      case .invalid(let field, let reason): "\(field): \(reason)"
      }
    }
  }

  /// A DNS name or IPv4/IPv6 literal. No spaces, no shell or config syntax.
  public static func host(_ value: String, field: String = "Server") throws(Failure) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { throw .invalid(field: field, reason: "is empty") }
    guard trimmed.count <= 253, trimmed.wholeMatch(of: /[A-Za-z0-9.\-:\[\]]+/) != nil, !trimmed.hasPrefix("-") else {
      throw .invalid(field: field, reason: "should be a hostname or IP address, like vpn.example.com")
    }
    return trimmed
  }

  /// A URL or hostname, optionally with a port and path, for openconnect and NetBird.
  public static func server(_ value: String, field: String = "Server") throws(Failure) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { throw .invalid(field: field, reason: "is empty") }
    guard trimmed.count <= 512, trimmed.wholeMatch(of: /[A-Za-z0-9.\-:\/_~%?=&\[\]]+/) != nil, !trimmed.hasPrefix("-") else {
      throw .invalid(field: field, reason: "should look like vpn.example.com or https://vpn.example.com/group")
    }
    return trimmed
  }

  public static func port(_ value: Int) throws(Failure) -> Int {
    guard (1...65535).contains(value) else { throw .invalid(field: "Port", reason: "must be between 1 and 65535") }
    return value
  }

  /// Usernames and passwords end up in a line-based config file, so control
  /// characters (newlines especially) would let one value inject another key.
  public static func secretLine(_ value: String, field: String, allowEmpty: Bool = false) throws(Failure) -> String {
    guard allowEmpty || !value.isEmpty else { throw .invalid(field: field, reason: "is empty") }
    guard value.count <= 1024, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
      throw .invalid(field: field, reason: "can't contain line breaks or control characters")
    }
    return value
  }

  /// A SHA-256 certificate digest as 64 hex characters, colons optional.
  public static func sha256Digest(_ value: String, field: String = "Trusted certificate") throws(Failure) -> String {
    let hex = value.replacingOccurrences(of: ":", with: "").lowercased().trimmingCharacters(in: .whitespaces)
    guard hex.wholeMatch(of: /[0-9a-f]{64}/) != nil else {
      throw .invalid(field: field, reason: "should be a 64-character SHA-256 fingerprint")
    }
    return hex
  }

  /// openconnect's `--servercert` value: `pin-sha256:<base64>` or a hex fingerprint.
  public static func serverCertPin(_ value: String) throws(Failure) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard trimmed.wholeMatch(of: /(pin-sha256:[A-Za-z0-9+\/=]{43,44}|(sha1:|sha256:)?[0-9a-fA-F:]{40,95})/) != nil else {
      throw .invalid(field: "Server certificate", reason: "should be pin-sha256:… or a hex fingerprint")
    }
    return trimmed
  }

  /// wg-quick names the interface after the file; macOS wants a short, simple name.
  public static func interfaceName(_ value: String) throws(Failure) -> String {
    guard value.wholeMatch(of: /[a-z][a-z0-9_\-]{0,14}/) != nil else {
      throw .invalid(field: "Interface", reason: "use 1–15 lowercase letters, digits, - or _, starting with a letter")
    }
    return value
  }
}
