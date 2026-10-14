import Foundation
import Testing
@testable import PeonyCore

/// openvpn runs as root with a config anyone with the user's privileges can write, so these
/// cover the ways a line could run a program, open a file, or read differently to OpenVPN.
struct OpenVPNConfigTests {
  static let accepted = [
    "# Automatically generated OpenVPN client config file",
    "# Généré pour alex, avec un commentaire accentué",
    "setenv FORWARD_COMPATIBLE 1",
    "setenv opt block-outside-dns",
    "client",
    "server-poll-timeout 4",
    "nobind",
    "remote vpn.example.com 1194 udp",
    "remote vpn.example.com 443 tcp",
    "dev tun",
    "dev-type tun",
    "remote-cert-tls server",
    "tls-version-min 1.2",
    "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305",
    "providers legacy default",
    "pull-filter ignore \"route-ipv6\"",
    "auth-user-pass",
    "  --persist-tun",
    "; verb 4",
    "verb 3",
    "<ca>",
    "-----BEGIN CERTIFICATE-----",
    "MIIBszCCAVmgAwIBAgIUQ1RfZXhhbXBsZV9jYV9mb3JfcGVvbnkwCgYIKoZIzj0E",
    "-----END CERTIFICATE-----",
    "</ca>",
    "<cert>",
    "-----BEGIN CERTIFICATE-----",
    "MIIBrjCCAVSgAwIBAgIUY2xpZW50X2NlcnRfZm9yX3Blb255X3Rlc3RzMAoGCCqG",
    "-----END CERTIFICATE-----",
    "</cert>",
    "<key>",
    "-----BEGIN PRIVATE KEY-----",
    "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgcGVvbnlfdGVzdF9r",
    "-----END PRIVATE KEY-----",
    "</key>",
    "key-direction 1",
    "<tls-auth>",
    "-----BEGIN OpenVPN Static key V1-----",
    "0123456789abcdef0123456789abcdef",
    "-----END OpenVPN Static key V1-----",
    "</tls-auth>",
  ]

  @Test func `a realistic client config passes, normalized`() throws {
    let config = try OpenVPNConfig(validating: "\u{FEFF}" + Self.accepted.joined(separator: "\r\n") + "\r\n")
    #expect(config.server == "vpn.example.com")
    #expect(config.text == Self.accepted.joined(separator: "\n") + "\n")
  }

  static func problem(_ text: String) -> OpenVPNConfig.Problem? {
    do {
      _ = try OpenVPNConfig(validating: text)
      return nil
    } catch {
      return error
    }
  }

  @Test(arguments: [
    ("up /tmp/evil.sh", "up"),
    ("  --down /tmp/evil.sh", "down"),
    ("\"route-up\" /tmp/evil.sh", "route-up"),
    ("'tls-verify' /tmp/evil.sh", "tls-verify"),
    ("ipchange /tmp/evil.sh", "ipchange"),
    ("auth-user-pass-verify /tmp/evil.sh via-file", "auth-user-pass-verify"),
    ("learn-address /tmp/evil.sh", "learn-address"),
    ("dns-updown /tmp/evil.sh", "dns-updown"),
    ("script-security 2", "script-security"),
    ("plugin /tmp/evil.so", "plugin"),
    ("iproute /tmp/evil", "iproute"),
    ("engine dynamic", "engine"),
    ("providers legacy /tmp/evil.dylib", "providers"),
    ("pkcs11-providers /tmp/evil.so", "pkcs11-providers"),
    ("setenv opt up /tmp/evil.sh", "up"),
  ])
  func `directives that run programs are refused`(line: String, directive: String) {
    #expect(Self.problem("remote vpn.example.com\n\(line)\n") == .runsCommands(directive: directive, line: 2))
  }

  @Test(arguments: [
    ("ca /etc/ssl/cert.pem", "ca"),
    ("tls-auth ta.key 1", "tls-auth"),
    ("crl-verify /etc/crl.pem dir", "crl-verify"),
    ("auth-user-pass /etc/master.passwd", "auth-user-pass"),
    ("askpass /etc/master.passwd", "askpass"),
    ("config /tmp/other.ovpn", "config"),
    ("cd /tmp", "cd"),
    ("chroot /tmp", "chroot"),
    ("tmp-dir /tmp", "tmp-dir"),
    ("dev-node /dev/disk0", "dev-node"),
    ("log /etc/sudoers", "log"),
    ("log-append /etc/sudoers", "log-append"),
    ("status /etc/sudoers 1", "status"),
    ("writepid /etc/sudoers", "writepid"),
    ("secret /etc/master.passwd", "secret"),
    ("http-proxy proxy.example.com 8080 /etc/master.passwd basic", "http-proxy"),
    ("socks-proxy proxy.example.com 1080 /etc/master.passwd", "socks-proxy"),
  ])
  func `directives that open files are refused`(line: String, directive: String) {
    #expect(Self.problem("remote vpn.example.com\n\(line)\n") == .usesFiles(directive: directive, line: 2))
  }

  @Test(arguments: [
    ("daemon", "daemon"),
    ("management 127.0.0.1 7505", "management"),
    ("user nobody", "user"),
    ("UP /tmp/evil.sh", "UP"),
    ("setenv PATH /tmp/evil", "setenv PATH"),
    ("setenv opt", "setenv opt"),
    ("dev ../../etc/sudoers", "dev ../../etc/sudoers"),
  ])
  func `anything off the list is refused`(line: String, directive: String) {
    #expect(Self.problem("remote vpn.example.com\n\(line)\n") == .unsupported(directive: directive, line: 2))
  }

  @Test(arguments: [
    "verb 3" + String(repeating: " ", count: 250) + "up /tmp/evil.sh",
    "remote vpn.example.com\u{00A0}up /tmp/evil.sh",
    "remote vpn.example.com\u{0}up /tmp/evil.sh",
    "verb 3\rup /tmp/evil.sh",
    "pull-filter ignore \"route",
    "remote vpn\\.example.com",
  ])
  func `lines OpenVPN could read differently are refused`(line: String) {
    #expect(Self.problem("remote vpn.example.com\n\(line)\n") == .unreadableLine(2))
  }

  @Test func `a proxy may still find its own credentials`() throws {
    let config = try OpenVPNConfig(validating: "remote vpn.example.com\nhttp-proxy proxy.example.com 8080 auto-nct\n")
    #expect(config.server == "vpn.example.com")
  }

  @Test func `inline blocks hold data, not directives`() throws {
    let config = try OpenVPNConfig(validating: "remote vpn.example.com\n<ca>\nup /tmp/evil.sh\n</ca>\n")
    #expect(config.server == "vpn.example.com")
  }

  @Test func `a block ends where OpenVPN ends it`() {
    let text = "remote vpn.example.com\n<ca>\nAAAA\n   </ca> trailing text\nup /tmp/evil.sh\n</ca>\n"
    #expect(Self.problem(text) == .runsCommands(directive: "up", line: 5))
  }

  @Test func `a block tag is still a directive`() {
    #expect(Self.problem("remote vpn.example.com\n--<up>\n/bin/sh\n</up>\n") == .runsCommands(directive: "up", line: 2))
    #expect(Self.problem("remote vpn.example.com\n<management>\nx\n</management>\n") == .unsupported(directive: "management", line: 2))
  }

  @Test func `connection blocks are checked line by line`() {
    let text = "<connection>\nremote vpn.example.com 1194\nup /tmp/evil.sh\n</connection>\n"
    #expect(Self.problem(text) == .runsCommands(directive: "up", line: 3))
  }

  @Test func `the server can come from a connection block`() throws {
    let config = try OpenVPNConfig(validating: "client\n<connection>\nremote backup.example.com 443 tcp\n</connection>\n")
    #expect(config.server == "backup.example.com")
  }

  @Test func `block contents must be plain`() {
    #expect(Self.problem("remote vpn.example.com\n<ca>\n\u{00A0}</ca>\nup /tmp/evil.sh\n</ca>\n") == .unreadableLine(3))
  }

  @Test func `an unclosed block is refused`() {
    #expect(Self.problem("remote vpn.example.com\n<key>\nAAAA\n") == .unclosedBlock(tag: "key", line: 2))
  }

  @Test func `empty and serverless configs are refused`() {
    #expect(Self.problem(" \n\n") == .empty)
    #expect(Self.problem("client\ndev tun\n") == .missingRemote)
  }

  @Test func `problems read as sentences`() {
    #expect(OpenVPNConfig.Problem.runsCommands(directive: "up", line: 4).description
      == "Line 4 uses up, which can run programs as root. Peony doesn't allow it; remove the line.")
    #expect(OpenVPNConfig.Problem.usesFiles(directive: "ca", line: 7).description
      == "Line 7 points ca at a file. Paste the file between <ca> and </ca> instead, so root never opens a path from the config.")
    #expect(OpenVPNConfig.Problem.usesFiles(directive: "log", line: 2).description
      == "Line 2 has OpenVPN open a file as root through log. Peony doesn't allow it.")
  }
}

struct OpenVPNRequestTests {
  @Test func `the auth file holds the username, then the password`() throws {
    let request = HelperRequest.OpenVPNRequest(config: "", username: "alex", password: "p@ss word")
    #expect(try request.authFile() == "alex\np@ss word\n")
  }

  @Test func `certificate-only profiles have no auth file`() throws {
    #expect(try HelperRequest.OpenVPNRequest(config: "", username: "", password: "").authFile() == nil)
  }

  @Test(arguments: [
    ("alex", "secret\nroot", Validation.Failure.invalid(field: "Password", reason: "can't contain line breaks or control characters")),
    ("alex\nroot", "secret", Validation.Failure.invalid(field: "Username", reason: "can't contain line breaks or control characters")),
    ("alex", "", Validation.Failure.invalid(field: "Password", reason: "is empty")),
  ])
  func `credentials can't add lines to the auth file`(username: String, password: String, failure: Validation.Failure) {
    let request = HelperRequest.OpenVPNRequest(config: "", username: username, password: password)
    #expect(throws: failure) { try request.authFile() }
  }

  @Test func `requests round-trip as JSON`() throws {
    let request = HelperRequest.openVPN(.init(config: "remote vpn.example.com\n", username: "alex", password: "hunter2"))
    let data = try JSONEncoder().encode(request)
    #expect(try JSONDecoder().decode(HelperRequest.self, from: data) == request)
  }
}

struct OpenVPNLogParserTests {
  @Test(arguments: [
    "2026-10-14 09:30:12 Initialization Sequence Completed",
    "2026-10-14 09:30:12 us=482113 Initialization Sequence Completed",
    "2026-10-14 09:30:12 Initialization Sequence Completed With Errors",
  ])
  func `tunnel up`(line: String) {
    var parser = OpenVPNLogParser()
    #expect(parser.consume(line) == .tunnelUp)
  }

  @Test(arguments: [
    "2026-10-14 09:30:12 AUTH: Received control message: AUTH_FAILED",
    "2026-10-14 09:30:12 AUTH: Received control message: AUTH_FAILED,Invalid username or password",
  ])
  func `login failure`(line: String) {
    var parser = OpenVPNLogParser()
    #expect(parser.consume(line) == .authenticationFailed)
  }

  @Test func `sudo without the helper rule`() {
    var parser = OpenVPNLogParser()
    #expect(parser.consume("sudo: a password is required") == .sudoNeedsPassword)
  }

  @Test func `the helper's own refusals`() {
    var parser = OpenVPNLogParser()
    #expect(parser.consume("ERROR:  Line 4 uses up, which can run programs as root. Peony doesn't allow it; remove the line.")
      == .error("Line 4 uses up, which can run programs as root. Peony doesn't allow it; remove the line."))
  }

  @Test func `options errors`() {
    var parser = OpenVPNLogParser()
    let line = "Options error: Unrecognized option or missing or extra parameter(s) in /var/run/peony/openvpn.conf:12: tls-cryptt (2.7.8)"
    #expect(parser.consume(line) == .error(line))
  }

  @Test func `a fatal error reports the line before it`() {
    var parser = OpenVPNLogParser()
    #expect(parser.consume("2026-10-14 09:30:12 Cannot open utun device: Operation not permitted (errno=1)") == nil)
    #expect(parser.consume("2026-10-14 09:30:12 Exiting due to fatal error") == .error("Cannot open utun device: Operation not permitted (errno=1)"))
  }

  @Test func `ordinary lines are ignored`() {
    var parser = OpenVPNLogParser()
    #expect(parser.consume("2026-10-14 09:30:11 TCP/UDP: Preserving recently used remote address: [AF_INET]203.0.113.7:1194") == nil)
  }
}
