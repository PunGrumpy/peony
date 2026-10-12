import Foundation
import Security

/// Passwords and WireGuard configs, one generic-password item per profile.
nonisolated enum Keychain {
  private static let service = "app.peony.Peony"

  enum Read {
    case secret(String)
    case missing
    /// The item belongs to an earlier build. Ad-hoc signing gives every build a new identity,
    /// and macOS would ask for the login keychain password to share it, so we never let it ask.
    case locked
  }

  static func secret(for id: UUID) -> Read {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: id.uuidString,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    // kSecUseAuthenticationUIFail doesn't stop the legacy keychain's access prompt; this does.
    SecKeychainSetUserInteractionAllowed(false)
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    SecKeychainSetUserInteractionAllowed(true)
    switch status {
    case errSecSuccess:
      guard let data = result as? Data else { return .missing }
      return .secret(String(decoding: data, as: UTF8.self))
    case errSecItemNotFound:
      return .missing
    default:
      return .locked
    }
  }

  /// Whether a secret is saved, without reading it. Reading the data is what makes macOS
  /// ask permission, so checks like "is there a password yet?" never do.
  static func hasSecret(for id: UUID) -> Bool {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: id.uuidString,
      kSecReturnAttributes: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
  }

  static func setSecret(_ secret: String, for id: UUID, label: String) {
    let match: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: id.uuidString,
    ]
    // Replace rather than update, so the item's access list names this build of Peony.
    deleteSecret(for: id)
    var item = match
    item[kSecValueData] = Data(secret.utf8)
    item[kSecAttrLabel] = label
    SecItemAdd(item as CFDictionary, nil)
  }

  static func deleteSecret(for id: UUID) {
    let status = SecItemDelete([
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: id.uuidString,
    ] as CFDictionary)
    guard status != errSecSuccess, status != errSecItemNotFound else { return }
    // An item an older build made isn't ours to delete, but Apple's security tool may.
    let tool = Process()
    tool.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    tool.arguments = ["delete-generic-password", "-s", service, "-a", id.uuidString]
    tool.standardOutput = FileHandle.nullDevice
    tool.standardError = FileHandle.nullDevice
    try? tool.run()
    tool.waitUntilExit()
  }
}
