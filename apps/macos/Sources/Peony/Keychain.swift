import Foundation
import Security

/// Passwords and configs, one generic-password item per profile. An OpenVPN profile can need
/// both a config and a password, so its password gets a second item.
nonisolated enum Keychain {
  private static let service = "app.peony.Peony"

  enum Item {
    /// The profile's password, or its WireGuard or OpenVPN config.
    case secret
    /// The password that goes with an OpenVPN config.
    case openVPNPassword

    func account(_ id: UUID) -> String {
      switch self {
      case .secret: id.uuidString
      case .openVPNPassword: "\(id.uuidString).password"
      }
    }
  }

  enum Read {
    case secret(String)
    case missing
    /// The item belongs to an earlier build. Ad-hoc signing gives every build a new identity,
    /// and macOS would ask for the login keychain password to share it, so we never let it ask.
    case locked
  }

  static func secret(for id: UUID, _ item: Item = .secret) -> Read {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: item.account(id),
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
  static func hasSecret(for id: UUID, _ item: Item = .secret) -> Bool {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: item.account(id),
      kSecReturnAttributes: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
  }

  struct SaveError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
      let reason = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
      return "Peony couldn't save this to your Keychain (\(reason)). Enter it again and save."
    }
  }

  static func setSecret(_ secret: String, for id: UUID, _ item: Item = .secret, label: String) throws(SaveError) {
    let match: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: item.account(id),
    ]
    // Replace rather than update, so the item's access list names this build of Peony.
    deleteSecret(for: id, item)
    var item = match
    item[kSecValueData] = Data(secret.utf8)
    item[kSecAttrLabel] = label
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw SaveError(status: status) }
  }

  static func deleteSecret(for id: UUID, _ item: Item = .secret) {
    let status = SecItemDelete([
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: item.account(id),
    ] as CFDictionary)
    guard status != errSecSuccess, status != errSecItemNotFound else { return }
    // An item an older build made isn't ours to delete, but Apple's security tool may.
    let tool = Process()
    tool.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    tool.arguments = ["delete-generic-password", "-s", service, "-a", item.account(id)]
    tool.standardOutput = FileHandle.nullDevice
    tool.standardError = FileHandle.nullDevice
    try? tool.run()
    tool.waitUntilExit()
  }
}
