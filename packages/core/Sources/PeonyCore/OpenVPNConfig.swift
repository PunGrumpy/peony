import Foundation

/// Checks an OpenVPN client config before root ever sees it.
///
/// OpenVPN runs scripts and loads plugins as root, and opens whatever paths a config names, so a
/// pasted `.ovpn` could run commands or read and write any file. Only client options that do
/// neither get through; anything else is refused, including options newer OpenVPNs add.
///
/// Lines are split the way OpenVPN 2.7's `parse_line` splits them (quotes, backslashes, `--`,
/// comments, inline `<ca>` blocks), and anything the two could read differently is refused:
/// bytes outside printable ASCII, and lines long enough that OpenVPN would cut them in two.
public struct OpenVPNConfig: Sendable {
  /// The config as OpenVPN will read it: `\n` line endings and no byte-order mark.
  public let text: String
  /// The host on the first `remote` line, for the panel.
  public let server: String

  public enum Problem: Error, Equatable, CustomStringConvertible {
    case empty
    case missingRemote
    case runsCommands(directive: String, line: Int)
    case usesFiles(directive: String, line: Int)
    case unsupported(directive: String, line: Int)
    case unclosedBlock(tag: String, line: Int)
    case unreadableLine(Int)

    public var description: String {
      switch self {
      case .empty: "The configuration is empty."
      case .missingRemote: "The configuration needs a remote line naming the server."
      case .runsCommands(let directive, let line):
        "Line \(line) uses \(directive), which can run programs as root. Peony doesn't allow it; remove the line."
      case .usesFiles(let directive, let line) where OpenVPNConfig.inlineBlocks.contains(directive):
        "Line \(line) points \(directive) at a file. Paste the file between <\(directive)> and </\(directive)> instead, so root never opens a path from the config."
      case .usesFiles(let directive, let line):
        "Line \(line) has OpenVPN open a file as root through \(directive). Peony doesn't allow it."
      case .unsupported(let directive, let line):
        "Line \(line) uses \(directive). Peony only accepts client options it has checked are safe to run as root, and this isn't one."
      case .unclosedBlock(let tag, let line): "The <\(tag)> block on line \(line) never ends with </\(tag)>."
      case .unreadableLine(let line):
        "Line \(line) can't be checked. Keep it to plain ASCII under 255 characters, with matching quotes."
      }
    }
  }

  /// Directives that run a program or load code into OpenVPN.
  static let runsCommands: Set<String> = [
    "up", "down", "route-up", "route-pre-down", "ipchange", "tls-verify", "auth-user-pass-verify",
    "client-connect", "client-disconnect", "client-crresponse", "learn-address", "dns-updown",
    "tls-crypt-v2-verify", "script-security", "plugin", "iproute", "engine", "providers", "pkcs11-providers",
  ]

  /// Directives whose argument is a path root would read or write.
  static let opensFiles: Set<String> = [
    "config", "cd", "chroot", "tmp-dir", "dev-node", "capath", "askpass", "secret", "dh", "log", "log-append",
    "status", "writepid", "replay-persist", "ifconfig-pool-persist", "client-config-dir", "genkey",
    "tls-export-cert", "port-share", "auth-gen-token-secret",
  ]

  /// Blocks accepted inline. Written on one line with an argument instead, each names a file.
  static let inlineBlocks: Set<String> = [
    "ca", "cert", "key", "extra-certs", "pkcs12", "tls-auth", "tls-crypt", "tls-crypt-v2", "crl-verify",
    "auth-user-pass", "http-proxy-user-pass", "connection",
  ]

  /// Client options that neither run anything nor open a path. Everything else is refused.
  static let allowed: Set<String> = inlineBlocks.union([
    "allow-compression", "allow-pull-fqdn", "auth", "auth-nocache", "auth-retry", "bind", "block-ipv6",
    "block-outside-dns", "cipher", "client", "comp-lzo", "comp-noadapt", "compat-mode", "compress",
    "connect-retry", "connect-retry-max", "connect-timeout", "data-ciphers", "data-ciphers-fallback", "dev",
    "dev-type", "dhcp-option", "disable-dco", "disable-occ", "dns", "ecdh-curve", "errors-to-stderr",
    "explicit-exit-notify", "fast-io", "float", "fragment", "hand-window", "http-proxy", "http-proxy-option",
    "http-proxy-retry", "ifconfig", "ifconfig-ipv6", "ifconfig-nowarn", "ignore-unknown-option", "inactive",
    "keepalive", "key-direction", "link-mtu", "local", "lport", "max-packet-size",
    "mlock", "mssfix", "mtu-disc", "mute", "mute-replay-warnings", "ncp-ciphers", "nice", "nobind",
    "ns-cert-type", "passtos", "peer-fingerprint", "persist-key", "persist-local-ip", "persist-remote-ip",
    "persist-tun", "ping", "ping-exit", "ping-restart", "ping-timer-rem", "port", "proto", "pull",
    "pull-filter", "push-peer-info", "rcvbuf", "redirect-gateway", "redirect-private", "remote",
    "remote-cert-eku", "remote-cert-ku", "remote-cert-tls", "remote-random", "remote-random-hostname",
    "reneg-bytes", "reneg-pkts", "reneg-sec", "replay-window", "resolv-retry", "route", "route-delay",
    "route-gateway", "route-ipv6", "route-ipv6-gateway", "route-metric", "route-nopull", "rport",
    "server-poll-timeout", "session-timeout", "setenv", "sndbuf", "socket-flags", "socks-proxy",
    "socks-proxy-retry", "static-challenge", "suppress-timestamps", "tls-cert-profile", "tls-cipher",
    "tls-ciphersuites", "tls-client", "tls-exit", "tls-groups", "tls-timeout", "tls-version-max",
    "tls-version-min", "topology", "tran-window", "tun-ipv6", "tun-mtu", "tun-mtu-extra", "tun-mtu-max", "verb",
    "verify-hash", "verify-x509-name",
  ])

  /// `setenv` variables profile generators write. Others could change what OpenVPN's DNS script runs.
  static let setenvNames: Set<String> = [
    "FORWARD_COMPATIBLE", "PUSH_PEER_INFO", "CLIENT_CERT", "REMOTE_RANDOM_HOSTNAME", "SERVER_POLL_TIMEOUT",
  ]

  /// OpenVPN reads 256 bytes at a time, so a longer line arrives as two and the second is read as
  /// its own directive. 254 leaves room for the newline in both of its buffers.
  static let maxLineBytes = 254

  public init(validating text: String) throws(Problem) {
    var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    if normalized.unicodeScalars.first == "\u{FEFF}" { normalized.unicodeScalars.removeFirst() }
    let lines = normalized.components(separatedBy: "\n")
    guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { throw .empty }

    var remotes: [String] = []
    try Self.check(lines[...], remotes: &remotes)
    guard let server = remotes.first else { throw .missingRemote }
    self.text = normalized
    self.server = server
  }

  /// Checks a run of lines, numbered by their index plus one, and the `<connection>` blocks inside.
  private static func check(_ lines: ArraySlice<String>, remotes: inout [String]) throws(Problem) {
    var index = lines.startIndex
    while index < lines.endIndex {
      let number = index + 1
      var tokens = try parseLine(lines[index], number: number)
      index += 1
      guard !tokens.isEmpty else { continue }
      if tokens[0].count >= 3, tokens[0].hasPrefix("--") { tokens[0].removeFirst(2) }

      guard tokens.count == 1, tokens[0].hasPrefix("<"), tokens[0].hasSuffix(">") else {
        try checkDirective(tokens, line: number, remotes: &remotes)
        continue
      }
      let tag = String(tokens[0].dropFirst().dropLast())
      guard inlineBlocks.contains(tag) else {
        throw runsCommands.contains(tag) ? .runsCommands(directive: tag, line: number) : .unsupported(directive: tag, line: number)
      }
      // OpenVPN ends a block at the first line that starts with the closing tag once leading spaces go.
      let close = "</\(tag)>"
      guard let end = lines[index...].firstIndex(where: { line in line.drop(while: { $0 == " " || $0 == "\t" }).hasPrefix(close) }) else {
        throw .unclosedBlock(tag: tag, line: number)
      }
      for content in index...end where !isPlain(lines[content]) {
        throw .unreadableLine(content + 1)
      }
      if tag == "connection" { try check(lines[index..<end], remotes: &remotes) }
      index = end + 1
    }
  }

  private static func checkDirective(_ tokens: [String], line: Int, remotes: inout [String]) throws(Problem) {
    let name = tokens[0]
    let arguments = Array(tokens.dropFirst())
    // OpenSSL's own providers keep old ciphers like BF-CBC working; any other name is a library to load.
    if name == "providers", !arguments.isEmpty, arguments.allSatisfy(["default", "legacy", "base"].contains) { return }
    if runsCommands.contains(name) { throw .runsCommands(directive: name, line: line) }
    if opensFiles.contains(name) || (inlineBlocks.contains(name) && !arguments.isEmpty) {
      throw .usesFiles(directive: name, line: line)
    }
    guard allowed.contains(name) else { throw .unsupported(directive: name, line: line) }

    switch name {
    case "setenv" where arguments.first == "opt":
      // OpenVPN carries out the rest of a `setenv opt` line as a directive of its own.
      guard arguments.count > 1 else { throw .unsupported(directive: "setenv opt", line: line) }
      try checkDirective(Array(arguments.dropFirst()), line: line, remotes: &remotes)
    case "setenv":
      let variable = arguments.first ?? ""
      guard setenvNames.contains(variable) || variable.hasPrefix("UV_") || variable.hasPrefix("IV_") else {
        throw .unsupported(directive: "setenv \(variable)", line: line)
      }
    case "dev":
      // Any other name is opened as /dev/<name>.
      if let device = arguments.first, device.wholeMatch(of: /(tun|tap|utun)[0-9]{0,3}/) == nil {
        throw .unsupported(directive: "dev \(device)", line: line)
      }
    case "http-proxy" where arguments.count > 2 && !["auto", "auto-nct"].contains(arguments[2]),
         "socks-proxy" where arguments.count > 2:
      throw .usesFiles(directive: name, line: line)
    case "remote":
      if let host = arguments.first { remotes.append(host) }
    default:
      break
    }
  }

  /// Splits a line into arguments exactly as OpenVPN's `parse_line` does, and refuses the line
  /// wherever OpenVPN would, or where a byte outside printable ASCII could make the two disagree.
  static func parseLine(_ line: String, number: Int) throws(Problem) -> [String] {
    guard line.utf8.count <= maxLineBytes else { throw .unreadableLine(number) }
    enum State { case between, unquoted, quoted, singleQuoted }
    let backslashByte = UInt8(ascii: "\\"), quote = UInt8(ascii: "\""), singleQuote = UInt8(ascii: "'")
    func isSpace(_ byte: UInt8) -> Bool { byte == 0 || byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") }

    var tokens: [String] = []
    var token: [UInt8] = []
    var state = State.between
    var backslash = false
    let bytes = Array(line.utf8)
    // One step past the last byte reads the end of the line, which OpenVPN treats as a space.
    for position in 0...bytes.count {
      let byte = position < bytes.count ? bytes[position] : 0
      guard position == bytes.count || byte == UInt8(ascii: "\t") || (0x20..<0x7F).contains(byte) else {
        throw .unreadableLine(number)
      }
      if !backslash, byte == backslashByte, state != .singleQuoted {
        backslash = true
        continue
      }
      var out: UInt8 = 0
      var done = false
      switch state {
      case .between:
        if !isSpace(byte) {
          if byte == UInt8(ascii: "#") || byte == UInt8(ascii: ";") { return tokens }
          if !backslash, byte == quote {
            state = .quoted
          } else if !backslash, byte == singleQuote {
            state = .singleQuoted
          } else {
            out = byte
            state = .unquoted
          }
        }
      case .unquoted:
        if !backslash, isSpace(byte) { done = true } else { out = byte }
      case .quoted:
        if !backslash, byte == quote { done = true } else { out = byte }
      case .singleQuoted:
        if byte == singleQuote { done = true } else { out = byte }
      }
      if done {
        tokens.append(String(decoding: token, as: UTF8.self))
        token = []
        state = .between
      }
      if backslash, out != 0, !(out == backslashByte || out == quote || isSpace(out)) { throw .unreadableLine(number) }
      backslash = false
      if out != 0 { token.append(out) }
    }
    guard state == .between else { throw .unreadableLine(number) }
    return tokens
  }

  /// Block contents aren't split into arguments, but OpenVPN still looks for the closing tag in them.
  private static func isPlain(_ line: String) -> Bool {
    line.utf8.count <= maxLineBytes && line.utf8.allSatisfy { $0 == UInt8(ascii: "\t") || (0x20..<0x7F).contains($0) }
  }
}
