import Foundation

/// A VPN the user added. Everything here is safe to keep in a plain file;
/// passwords and WireGuard and OpenVPN configs live in the Keychain, keyed by `id`.
public struct Profile: Codable, Hashable, Identifiable, Sendable {
  public var id: UUID
  public var name: String
  public var kind: Kind
  /// `host` or `host:port` to check once the tunnel is up, so "connected" means
  /// "I can reach my stuff". Port defaults to 443.
  public var destinations: [String]

  public init(id: UUID = UUID(), name: String, kind: Kind, destinations: [String] = []) {
    self.id = id
    self.name = name
    self.kind = kind
    self.destinations = destinations
  }

  public enum Kind: Codable, Hashable, Sendable {
    case forti(Forti)
    case openConnect(OpenConnect)
    case wireGuard(WireGuard)
    case openVPN(OpenVPN)
    case netBird(NetBird)
    /// The Tailscale client. Its account and login server live in Tailscale itself.
    case tailscale
  }

  /// FortiGate SSL-VPN through openfortivpn.
  public struct Forti: Codable, Hashable, Sendable {
    public var host: String
    public var port: Int
    public var username: String
    /// SHA-256 digest of a gateway certificate to trust even if it doesn't validate.
    public var trustedCert: String?
    public var realm: String?

    public init(host: String = "", port: Int = 443, username: String = "", trustedCert: String? = nil, realm: String? = nil) {
      self.host = host
      self.port = port
      self.username = username
      self.trustedCert = trustedCert
      self.realm = realm
    }
  }

  /// Cisco AnyConnect, GlobalProtect, Pulse and friends through openconnect.
  public struct OpenConnect: Codable, Hashable, Sendable {
    public enum ServerProtocol: String, Codable, CaseIterable, Sendable {
      case anyconnect, gp, pulse, nc, f5, fortinet, array

      public var title: String {
        switch self {
        case .anyconnect: "Cisco AnyConnect"
        case .gp: "Palo Alto GlobalProtect"
        case .pulse: "Pulse / Ivanti Secure"
        case .nc: "Juniper Network Connect"
        case .f5: "F5 BIG-IP"
        case .fortinet: "Fortinet (openconnect)"
        case .array: "Array Networks"
        }
      }
    }

    public var server: String
    public var serverProtocol: ServerProtocol
    public var username: String
    /// `pin-sha256:…` or a SHA-1/SHA-256 fingerprint openconnect should accept.
    public var serverCert: String?

    public init(server: String = "", serverProtocol: ServerProtocol = .anyconnect, username: String = "", serverCert: String? = nil) {
      self.server = server
      self.serverProtocol = serverProtocol
      self.username = username
      self.serverCert = serverCert
    }
  }

  /// A wg-quick configuration. The whole file holds a private key, so it lives in the Keychain;
  /// this only remembers the interface name wg-quick should use.
  public struct WireGuard: Codable, Hashable, Sendable {
    public var interfaceName: String

    public init(interfaceName: String = "peony0") {
      self.interfaceName = interfaceName
    }
  }

  /// An OpenVPN client config. It holds private keys, so it lives in the Keychain with the password;
  /// this remembers the username and the server the config names.
  public struct OpenVPN: Codable, Hashable, Sendable {
    /// Empty when the server only checks the certificate.
    public var username: String
    /// The host on the config's first `remote` line, kept here because the config itself is secret.
    public var server: String

    public init(username: String = "", server: String = "") {
      self.username = username
      self.server = server
    }
  }

  /// The NetBird daemon. Leave the URL empty for NetBird's own cloud.
  public struct NetBird: Codable, Hashable, Sendable {
    public var managementURL: String

    public init(managementURL: String = "") {
      self.managementURL = managementURL
    }
  }

  public var kindTitle: String {
    switch kind {
    case .forti: "FortiGate"
    case .openConnect(let settings): settings.serverProtocol.title
    case .wireGuard: "WireGuard"
    case .openVPN: "OpenVPN"
    case .netBird: "NetBird"
    case .tailscale: "Tailscale"
    }
  }

  /// A one-line description of where this profile goes, for the panel.
  public var endpoint: String {
    switch kind {
    case .forti(let forti): forti.port == 443 ? forti.host : "\(forti.host):\(forti.port)"
    case .openConnect(let settings): settings.server
    case .wireGuard(let settings): settings.interfaceName
    case .openVPN(let settings): settings.server
    case .netBird(let settings): settings.managementURL.isEmpty ? "NetBird Cloud" : Self.hostOnly(settings.managementURL)
    case .tailscale: "Tailscale"
    }
  }

  /// Whether connecting needs a password from the Keychain.
  public var needsPassword: Bool {
    switch kind {
    case .forti, .openConnect: true
    case .openVPN(let settings): !settings.username.isEmpty
    case .wireGuard, .netBird, .tailscale: false
    }
  }

  /// Whether the Keychain holds this profile's whole config, private key and all.
  public var keepsConfigInKeychain: Bool {
    switch kind {
    case .wireGuard, .openVPN: true
    case .forti, .openConnect, .netBird, .tailscale: false
    }
  }

  static func hostOnly(_ url: String) -> String {
    URLComponents(string: url)?.host ?? url
  }
}
