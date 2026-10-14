import Foundation

/// The contract between the app and `peony-helper`, the small root tool that
/// starts and stops tunnels.
///
/// The app runs `sudo -n <installedPath> run` and writes one JSON `HelperRequest`
/// to its stdin. Secrets travel that way so they never appear in `ps` or on disk
/// for longer than the tunnel takes to read them.
public enum Helper {
  /// Bump whenever the helper's behaviour changes; the app reinstalls on mismatch.
  public static let version = "2"
  public static let installedPath = "/Library/PrivilegedHelperTools/app.peony.helper"
  public static let sudoersPath = "/etc/sudoers.d/peony"
  /// Root-only scratch space for generated configs.
  public static let runDirectory = "/var/run/peony"
}

public enum HelperRequest: Codable, Equatable, Sendable {
  case forti(FortiRequest)
  case openConnect(OpenConnectRequest)
  case wireGuardUp(WireGuardRequest)
  case wireGuardDown(interfaceName: String)
  case openVPN(OpenVPNRequest)
  /// Interrupt any openfortivpn, openconnect or openvpn Peony started.
  case stop

  public struct FortiRequest: Codable, Equatable, Sendable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String
    public var trustedCert: String?
    public var realm: String?

    public init(host: String, port: Int, username: String, password: String, trustedCert: String?, realm: String?) {
      self.host = host
      self.port = port
      self.username = username
      self.password = password
      self.trustedCert = trustedCert
      self.realm = realm
    }

    /// Validates every field and renders openfortivpn's config file.
    public func configFile() throws(Validation.Failure) -> String {
      var lines = [
        "host = \(try Validation.host(host))",
        "port = \(try Validation.port(port))",
        "username = \(try Validation.secretLine(username, field: "Username"))",
        "password = \(try Validation.secretLine(password, field: "Password"))",
      ]
      if let trustedCert, !trustedCert.isEmpty {
        lines.append("trusted-cert = \(try Validation.sha256Digest(trustedCert))")
      }
      if let realm, !realm.isEmpty {
        lines.append("realm = \(try Validation.secretLine(realm, field: "Realm"))")
      }
      return lines.joined(separator: "\n") + "\n"
    }
  }

  public struct OpenConnectRequest: Codable, Equatable, Sendable {
    public var server: String
    public var serverProtocol: Profile.OpenConnect.ServerProtocol
    public var username: String
    public var password: String
    public var serverCert: String?

    public init(server: String, serverProtocol: Profile.OpenConnect.ServerProtocol, username: String, password: String, serverCert: String?) {
      self.server = server
      self.serverProtocol = serverProtocol
      self.username = username
      self.password = password
      self.serverCert = serverCert
    }

    /// Validated arguments for openconnect. The password goes to stdin, never here.
    public func arguments() throws(Validation.Failure) -> [String] {
      var arguments = [
        "--protocol=\(serverProtocol.rawValue)",
        "--user=\(try Validation.secretLine(username, field: "Username"))",
        "--passwd-on-stdin",
        "--non-inter",
      ]
      if let serverCert, !serverCert.isEmpty {
        arguments.append("--servercert=\(try Validation.serverCertPin(serverCert))")
      }
      _ = try Validation.secretLine(password, field: "Password")
      arguments.append(try Validation.server(server))
      return arguments
    }
  }

  public struct WireGuardRequest: Codable, Equatable, Sendable {
    public var interfaceName: String
    public var config: String

    public init(interfaceName: String, config: String) {
      self.interfaceName = interfaceName
      self.config = config
    }
  }

  public struct OpenVPNRequest: Codable, Equatable, Sendable {
    public var config: String
    /// Empty when the server only checks the certificate.
    public var username: String
    public var password: String

    public init(config: String, username: String, password: String) {
      self.config = config
      self.username = username
      self.password = password
    }

    /// The validated `--auth-user-pass` file: the username, then the password. Nil without a username.
    public func authFile() throws(Validation.Failure) -> String? {
      guard !username.isEmpty else { return nil }
      return "\(try Validation.secretLine(username, field: "Username"))\n\(try Validation.secretLine(password, field: "Password"))\n"
    }
  }
}

/// Where Homebrew puts the tools Peony drives. Only these directories are
/// searched, so a stray binary elsewhere on PATH can't be picked up as root.
/// openvpn is a daemon, so Homebrew links it into `sbin` rather than `bin`.
public enum Tools {
  public static let searchDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/homebrew/sbin", "/usr/local/sbin"]

  public static func find(_ name: String) -> String? {
    searchDirectories
      .map { "\($0)/\(name)" }
      .first { FileManager.default.isExecutableFile(atPath: $0) }
  }
}
