import Foundation

/// The kinds of VPN the add and edit form offers, without their settings.
public enum VPNType: String, CaseIterable, Identifiable, Sendable {
  case forti, openConnect, openVPN, wireGuard, netBird, tailscale

  public var id: Self { self }

  public init(_ kind: Profile.Kind) {
    switch kind {
    case .forti: self = .forti
    case .openConnect: self = .openConnect
    case .openVPN: self = .openVPN
    case .wireGuard: self = .wireGuard
    case .netBird: self = .netBird
    case .tailscale: self = .tailscale
    }
  }

  public var title: String {
    switch self {
    case .forti: "FortiGate"
    case .openConnect: "AnyConnect & more"
    case .openVPN: "OpenVPN"
    case .wireGuard: "WireGuard"
    case .netBird: "NetBird"
    case .tailscale: "Tailscale"
    }
  }

  /// The client this kind runs, and how to install it.
  public var tool: (name: String, install: String) {
    switch self {
    case .forti: ("openfortivpn", "brew install openfortivpn")
    case .openConnect: ("openconnect", "brew install openconnect")
    case .openVPN: ("openvpn", "brew install openvpn")
    case .wireGuard: ("wg-quick", "brew install wireguard-tools")
    case .netBird: ("netbird", "brew install netbirdio/tap/netbird")
    case .tailscale: ("tailscale", "brew install --cask tailscale-app")
    }
  }
}

/// The add and edit VPN form as one value, so what it accepts is tested without a window.
///
/// Every kind keeps its own settings, so switching kinds while adding doesn't lose what was typed
/// for another. Secrets start empty: an empty field keeps what the Keychain already holds.
public struct ProfileDraft: Equatable, Sendable {
  public enum Field: Hashable, Sendable {
    case name, server, port, username, password, trustedCert, serverCert, config, interface, managementURL, hosts
  }

  public enum FortiLogin: String, CaseIterable, Identifiable, Sendable {
    case password, browser

    public var id: Self { self }

    public var title: String {
      switch self {
      case .password: "Password"
      case .browser: "Browser (SSO)"
      }
    }
  }

  /// What Save writes. A nil secret keeps the one in the Keychain.
  public struct Saved: Equatable, Sendable {
    public var profile: Profile
    public var secret: String?
    public var openVPNPassword: String?
  }

  public var name: String
  /// Changing it clears `secret`, so a password typed for one kind never shows up as another's config.
  public var type: VPNType {
    didSet { if type != oldValue { secret = "" } }
  }
  public var forti: Profile.Forti
  public var fortiLogin: FortiLogin
  public var fortiUsername: String
  public var openConnect: Profile.OpenConnect
  public var wireGuard: Profile.WireGuard
  public var openVPN: Profile.OpenVPN
  public var netBird: Profile.NetBird
  /// The password, or the whole config for WireGuard and OpenVPN.
  public var secret: String
  public var openVPNPassword: String
  /// The hosts to check once connected, as typed: separated by commas, spaces or new lines.
  public var hosts: String
  public let hasSavedSecret: Bool
  public let hasSavedOpenVPNPassword: Bool

  public init(_ profile: Profile? = nil, hasSavedSecret: Bool = false, hasSavedOpenVPNPassword: Bool = false) {
    let kind = profile?.kind ?? .forti(.init())
    name = profile?.name ?? ""
    type = VPNType(kind)
    forti = if case .forti(let settings) = kind { settings } else { .init() }
    switch forti.login {
    case .password(let username):
      fortiLogin = .password
      fortiUsername = username
    case .browser:
      fortiLogin = .browser
      fortiUsername = ""
    }
    openConnect = if case .openConnect(let settings) = kind { settings } else { .init() }
    wireGuard = if case .wireGuard(let settings) = kind { settings } else { .init() }
    openVPN = if case .openVPN(let settings) = kind { settings } else { .init() }
    netBird = if case .netBird(let settings) = kind { settings } else { .init() }
    secret = ""
    openVPNPassword = ""
    hosts = profile?.destinations.joined(separator: ", ") ?? ""
    self.hasSavedSecret = hasSavedSecret
    self.hasSavedOpenVPNPassword = hasSavedOpenVPNPassword
  }

  /// What's wrong with each field, worded to show under it. Empty when the draft can be saved.
  public var problems: [Field: String] { evaluate(id: UUID()).problems }

  /// The profile and secrets to save under `id`, or nil while `problems` isn't empty.
  public func saved(id: UUID) -> Saved? { evaluate(id: id).saved }

  /// Whether the fields only advanced users fill in hold anything.
  public var hasAdvancedValues: Bool {
    switch type {
    case .forti: forti.trustedCert != nil || forti.realm != nil
    case .openConnect: openConnect.serverCert != nil
    case .openVPN, .wireGuard, .netBird, .tailscale: false
    }
  }

  /// The one validation pass: every field is checked, so the form can show every problem at once.
  private func evaluate(id: UUID) -> (saved: Saved?, problems: [Field: String]) {
    var problems: [Field: String] = [:]

    func check<T>(_ field: Field, _ validate: () throws -> T) -> T? {
      do {
        return try validate()
      } catch let failure as Validation.Failure {
        if case .invalid(let name, let reason) = failure { problems[field] = "\(name) \(reason)." }
      } catch let problem as OpenVPNConfig.Problem {
        problems[field] = problem == .empty ? Self.required : problem.description
      } catch let problem as WireGuardConfig.Problem {
        problems[field] = problem == .empty ? Self.required : problem.description
      } catch {
        problems[field] = error.localizedDescription
      }
      return nil
    }

    /// Empty is fine when the Keychain already holds one.
    func password(_ value: String, saved: Bool, field: Field = .password) -> String? {
      if value.isEmpty {
        if !saved { problems[field] = Self.required }
        return nil
      }
      return check(field) { try Validation.secretLine(value, field: "Password") }
    }

    func required(_ field: Field, _ value: String) -> Bool {
      guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
      problems[field] = Self.required
      return false
    }

    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    _ = required(.name, trimmedName)

    var kind: Profile.Kind?
    var secretToSave: String?
    var openVPNPasswordToSave: String?
    switch type {
    case .forti:
      var settings = forti
      if required(.server, settings.host), let host = check(.server, { try Validation.host(settings.host) }) { settings.host = host }
      if let port = check(.port, { try Validation.port(settings.port) }) { settings.port = port }
      switch fortiLogin {
      case .password:
        if required(.username, fortiUsername), let username = check(.username, { try Validation.secretLine(fortiUsername, field: "Username") }) {
          settings.login = .password(username: username)
        }
        secretToSave = password(secret, saved: hasSavedSecret)
      case .browser:
        settings.login = .browser
      }
      if let cert = settings.trustedCert { settings.trustedCert = check(.trustedCert) { try Validation.sha256Digest(cert) } }
      kind = .forti(settings)
    case .openConnect:
      var settings = openConnect
      if required(.server, settings.server), let server = check(.server, { try Validation.server(settings.server) }) { settings.server = server }
      if required(.username, settings.username), let username = check(.username, { try Validation.secretLine(settings.username, field: "Username") }) {
        settings.username = username
      }
      secretToSave = password(secret, saved: hasSavedSecret)
      if let cert = settings.serverCert { settings.serverCert = check(.serverCert) { try Validation.serverCertPin(cert) } }
      kind = .openConnect(settings)
    case .openVPN:
      var settings = openVPN
      _ = check(.username) { try Validation.secretLine(settings.username, field: "Username", allowEmpty: true) }
      if !secret.isEmpty || !hasSavedSecret, let config = check(.config, { try OpenVPNConfig(validating: secret) }) {
        secretToSave = config.text
        settings.server = config.server
      }
      if !settings.username.isEmpty { openVPNPasswordToSave = password(openVPNPassword, saved: hasSavedOpenVPNPassword) }
      kind = .openVPN(settings)
    case .wireGuard:
      var settings = wireGuard
      if let name = check(.interface, { try Validation.interfaceName(settings.interfaceName) }) { settings.interfaceName = name }
      if !secret.isEmpty || !hasSavedSecret { secretToSave = check(.config) { try WireGuardConfig.validate(secret) } }
      kind = .wireGuard(settings)
    case .netBird:
      var settings = netBird
      if !settings.managementURL.isEmpty, let url = check(.managementURL, { try Validation.server(settings.managementURL, field: "Management URL") }) {
        settings.managementURL = url
      }
      kind = .netBird(settings)
    case .tailscale:
      kind = .tailscale
    }

    let destinations = hosts.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" }).map(String.init)
    if let bad = destinations.first(where: { Probe.Target($0) == nil }) {
      problems[.hosts] = "“\(bad)” isn't a host or host:port."
    }

    guard problems.isEmpty, let kind else { return (nil, problems) }
    let profile = Profile(id: id, name: trimmedName, kind: kind, destinations: destinations)
    return (Saved(profile: profile, secret: secretToSave, openVPNPassword: openVPNPasswordToSave), [:])
  }

  private static let required = "Required."
}
