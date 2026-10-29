import Foundation

/// The contract between Peony.app and `peony`, the command-line tool scripts and AI agents use.
///
/// `peony` writes one `ControlRequest` as a line of JSON to a Unix socket the app listens on, and the
/// app answers with one `ControlReply` line, then closes. The app stays the only owner of the tunnel:
/// through here you can only read status, connect a VPN by name, or disconnect. Secrets, certificate
/// trust, the helper, the log and editing VPNs aren't part of it, and adding them needs a security review.
public enum Control {
  /// Bump when the JSON changes shape. Each side refuses a version it doesn't speak.
  public static let version = 1

  /// `~/Library/Application Support/Peony/control.sock`, next to `profiles.json`. Nil when the path
  /// doesn't fit in `sockaddr_un`, so callers can say so instead of truncating it.
  public static func socketPath(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String? {
    let path = home.appending(path: "Library/Application Support/Peony/control.sock").path(percentEncoded: false)
    return path.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path) ? path : nil
  }

  /// One value as one line of JSON, the newline included. Keys are sorted so the output is stable.
  public static func line(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value) + Data("\n".utf8)
  }

  /// A reply as `peony --json` prints it, and as the MCP tools return it.
  public static func envelope(_ reply: ControlReply) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(reply)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
  }

  /// The `version` a line of JSON claims, whatever else it holds.
  public static func version(of line: Data) -> Int? {
    struct Versioned: Decodable { var version: Int }
    return try? JSONDecoder().decode(Versioned.self, from: line).version
  }
}

/// How long `connect` or `disconnect` waits for the tunnel to settle. Always 1–600 seconds, so a
/// stuck client can't hold a waiter in the app forever.
public struct WaitLimit: Equatable, Sendable {
  public static let range = 1...600
  public static let connect = WaitLimit(checked: 90)
  public static let disconnect = WaitLimit(checked: 30)

  public let seconds: Int

  /// Nil outside `range`.
  public init?(seconds: Int) {
    guard Self.range.contains(seconds) else { return nil }
    self.seconds = seconds
  }

  private init(checked seconds: Int) {
    self.seconds = seconds
  }

  public var duration: Duration { .seconds(seconds) }
}

public enum ControlRequest: Equatable, Sendable {
  case status
  /// `vpn` is a VPN's name or id, matched by `ControlPolicy.resolve`.
  case connect(vpn: String, wait: WaitLimit)
  case disconnect(wait: WaitLimit)

  /// Reading status never opens Peony; changing the tunnel does.
  public var launchesApp: Bool {
    switch self {
    case .status: false
    case .connect, .disconnect: true
    }
  }
}

/// Everything an agent can learn about Peony, as one value. The app builds it at the moment it replies.
public struct ControlSnapshot: Equatable, Sendable {
  public var tunnel: Tunnel
  public var vpns: [VPN]

  public init(tunnel: Tunnel, vpns: [VPN]) {
    self.tunnel = tunnel
    self.vpns = vpns
  }

  /// The app's tunnel with only what's safe to hand out. Each payload rides on the case it belongs
  /// to, so an address can't appear on a failed tunnel and an "off" tunnel has no VPN.
  public enum Tunnel: Equatable, Sendable {
    case off
    case connecting(VPNRef, signingIn: Bool)
    case disconnecting(VPNRef)
    /// `address` is nil while macOS hasn't reported one; `since` is nil for a tunnel Peony adopted.
    case on(VPNRef, address: String?, since: Date?, hosts: [Host])
    case failed(VPNRef, Failure)

    public var vpn: VPNRef? {
      switch self {
      case .off: nil
      case .connecting(let vpn, _), .disconnecting(let vpn), .on(let vpn, _, _, _), .failed(let vpn, _): vpn
      }
    }

    /// Whether the tunnel has stopped changing: off, failed, or on with every host checked once.
    public var isSettled: Bool {
      switch self {
      case .off, .failed: true
      case .connecting, .disconnecting: false
      case .on(_, _, _, let hosts): !hosts.contains { $0.status == .checking }
      }
    }
  }

  public struct VPNRef: Equatable, Sendable, Codable {
    public var id: UUID
    public var name: String

    public init(id: UUID, name: String) {
      self.id = id
      self.name = name
    }
  }

  public struct Failure: Equatable, Sendable, Codable {
    public var message: String
    public var fix: Fix?

    public init(message: String, fix: Fix?) {
      self.message = message
      self.fix = fix
    }
  }

  /// What would most likely fix a failure. Only `installTool` carries something to run; every other
  /// kind is a button in Peony that the user has to press.
  public struct Fix: Equatable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable { case installHelper, installTool, trustCertificate, editProfile }

    public var kind: Kind
    public var title: String
    public var command: String?

    public init(kind: Kind, title: String, command: String? = nil) {
      self.kind = kind
      self.title = title
      self.command = command
    }
  }

  /// One destination the user asked Peony to check once the tunnel is up.
  public struct Host: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
      case checking
      case reachable(milliseconds: Int)
      case unreachable
    }

    public var host: String
    public var status: Status

    public init(host: String, status: Status) {
      self.host = host
      self.status = status
    }
  }

  /// One saved VPN, with only the fields an agent needs to pick one.
  public struct VPN: Equatable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable { case forti, openConnect, wireGuard, openVPN, netBird, tailscale }

    public var id: UUID
    public var name: String
    public var kind: Kind
    public var endpoint: String
    /// The destinations Peony checks once this VPN is up, as the user typed them.
    public var hosts: [String]

    public init(id: UUID, name: String, kind: Kind, endpoint: String, hosts: [String]) {
      self.id = id
      self.name = name
      self.kind = kind
      self.endpoint = endpoint
      self.hosts = hosts
    }

    /// Copies the safe fields only. Usernames, realms and certificate pins never leave the profile.
    public init(_ profile: Profile) {
      let kind: Kind = switch profile.kind {
      case .forti: .forti
      case .openConnect: .openConnect
      case .wireGuard: .wireGuard
      case .openVPN: .openVPN
      case .netBird: .netBird
      case .tailscale: .tailscale
      }
      self.init(id: profile.id, name: profile.name, kind: kind, endpoint: profile.endpoint, hosts: profile.destinations)
    }
  }
}

public enum ControlOutcome: String, Equatable, Sendable, Codable {
  /// Connected with every host checked once, disconnected, or status answered.
  case done
  case failed
  /// The wait ran out with the tunnel still connecting or disconnecting.
  case timedOut
  /// Someone else connected or disconnected while this request waited, or the sign-in window was closed.
  case interrupted
}

public enum ControlRefusal: Error, Equatable, Sendable {
  case noSuchVPN(query: String, vpns: [ControlSnapshot.VPN])
  case ambiguous(query: String, matches: [ControlSnapshot.VPN])
  /// Nothing answered on the socket, or the app quit before it replied.
  case notRunning
  case couldNotLaunch
  /// The app speaks another `Control.version`, usually because it was upgraded while running.
  case outdated(app: Int)
  /// The socket refused the connection, typically an agent sandbox that blocks Unix sockets.
  case blocked(path: String)
  /// The home folder's path is too long for a Unix socket, so the app can't serve one.
  case pathTooLong
  /// The user turned off "Let agents control Peony" in Settings.
  case disabled

  public var message: String {
    switch self {
    case .noSuchVPN(let query, _):
      "No VPN is named \"\(query)\". Run `peony list` to see them."
    case .ambiguous(let query, let matches):
      "\(matches.count) VPNs are named \"\(query)\". Use one's id from `peony list --json` instead."
    case .notRunning:
      "Peony isn't running. `peony connect` opens it."
    case .couldNotLaunch:
      "Peony didn't open, or didn't answer within 10 seconds."
    case .outdated:
      "Peony is running a different version than this `peony`. Quit Peony and open it again."
    case .blocked(let path):
      "Not allowed to reach Peony at \(path). If this runs in a sandbox, allow that Unix socket."
    case .pathTooLong:
      "Your home folder's path is too long for Peony's control socket, so `peony` can't reach the app."
    case .disabled:
      "Agents can't control Peony right now. Turn it on in Peony Settings › Agents."
    }
  }
}

public enum ControlReply: Equatable, Sendable {
  case answered(ControlOutcome, ControlSnapshot)
  case refused(ControlRefusal)

  /// What `peony` exits with for a usage error. It never reaches the app, so it has no reply.
  public static let usageExitCode: Int32 = 2

  /// The CLI's exit status. One table, so scripts can rely on it.
  public var exitCode: Int32 {
    switch self {
    case .answered(.done, _): 0
    case .answered(.failed, _): 1
    case .answered(.timedOut, _): 5
    case .answered(.interrupted, _): 6
    case .refused(.noSuchVPN), .refused(.ambiguous): 4
    case .refused(.notRunning), .refused(.couldNotLaunch), .refused(.outdated), .refused(.blocked), .refused(.pathTooLong), .refused(.disabled): 3
    }
  }
}

/// The decisions a control request makes, as pure functions of a snapshot, so they're tested without an app.
public enum ControlPolicy {
  public enum Goal: Equatable, Sendable {
    case up(UUID)
    case down
  }

  /// What a request does first, given the tunnel as it is.
  public enum Plan: Equatable, Sendable {
    /// The tunnel is already where the goal wants it.
    case done
    /// It's already on its way there: wait alongside whoever asked first, without restarting it.
    case join
    /// Ask the app to connect or disconnect, then wait.
    case start
    /// A tunnel is going down. Connecting now would race its teardown, so look again shortly.
    case waitForOff
  }

  /// A name or an id to exactly one VPN. An id wins; otherwise the trimmed name must match exactly,
  /// ignoring case. Never a prefix: a typo must not connect the wrong network.
  public static func resolve(_ query: String, among vpns: [ControlSnapshot.VPN]) -> Result<UUID, ControlRefusal> {
    let query = query.trimmingCharacters(in: .whitespaces)
    if let id = UUID(uuidString: query), vpns.contains(where: { $0.id == id }) { return .success(id) }
    let matches = vpns.filter { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(query) == .orderedSame }
    switch matches.count {
    case 0: return .failure(.noSuchVPN(query: query, vpns: vpns))
    case 1: return .success(matches[0].id)
    default: return .failure(.ambiguous(query: query, matches: matches))
    }
  }

  /// Repeating a request never restarts a tunnel: connecting the VPN that's already on or coming up,
  /// or disconnecting when nothing is up, only waits. Disconnecting a failed tunnel clears it to off,
  /// so the next `status` doesn't still report the failure.
  public static func plan(_ goal: Goal, _ tunnel: ControlSnapshot.Tunnel) -> Plan {
    switch (goal, tunnel) {
    case (.up(let id), .on(let vpn, _, _, _)) where vpn.id == id: tunnel.isSettled ? .done : .join
    case (.up(let id), .connecting(let vpn, _)) where vpn.id == id: .join
    case (.up, .disconnecting): .waitForOff
    case (.up, _): .start
    case (.down, .off): .done
    case (.down, .disconnecting): .join
    case (.down, .connecting), (.down, .on), (.down, .failed): .start
    }
  }

  /// How a wait ends, or nil to keep waiting. `replaced` is true once someone else asked for a
  /// connect or disconnect after this request.
  public static func outcome(_ goal: Goal, _ tunnel: ControlSnapshot.Tunnel, replaced: Bool) -> ControlOutcome? {
    switch goal {
    case .up(let id):
      if replaced || tunnel.vpn?.id != id { return .interrupted }
      switch tunnel {
      case .on: return tunnel.isSettled ? .done : nil
      case .connecting: return nil
      case .failed: return .failed
      case .off, .disconnecting: return .interrupted
      }
    case .down:
      switch tunnel {
      case .off, .failed: return .done
      case .connecting, .on, .disconnecting: return replaced ? .interrupted : nil
      }
    }
  }
}

// MARK: JSON

extension ControlRequest: Codable {
  private enum CodingKeys: String, CodingKey { case version, command, vpn, timeout }
  private enum Command: String, Codable { case status, connect, disconnect }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try container.checkVersion(forKey: .version)
    switch try container.decode(Command.self, forKey: .command) {
    case .status:
      self = .status
    case .connect:
      self = .connect(vpn: try container.decode(String.self, forKey: .vpn), wait: try container.decodeWait(forKey: .timeout))
    case .disconnect:
      self = .disconnect(wait: try container.decodeWait(forKey: .timeout))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Control.version, forKey: .version)
    switch self {
    case .status:
      try container.encode(Command.status, forKey: .command)
    case .connect(let vpn, let wait):
      try container.encode(Command.connect, forKey: .command)
      try container.encode(vpn, forKey: .vpn)
      try container.encode(wait.seconds, forKey: .timeout)
    case .disconnect(let wait):
      try container.encode(Command.disconnect, forKey: .command)
      try container.encode(wait.seconds, forKey: .timeout)
    }
  }
}

extension ControlReply: Codable {
  private enum CodingKeys: String, CodingKey { case version, outcome, tunnel, vpns, error }

  /// A VPN in the reply's list, marked when it's the tunnel's.
  private struct Listed: Codable {
    var vpn: ControlSnapshot.VPN
    var active: Bool

    private enum CodingKeys: String, CodingKey { case active }

    init(_ vpn: ControlSnapshot.VPN, active: Bool) {
      self.vpn = vpn
      self.active = active
    }

    init(from decoder: any Decoder) throws {
      vpn = try ControlSnapshot.VPN(from: decoder)
      active = try decoder.container(keyedBy: CodingKeys.self).decode(Bool.self, forKey: .active)
    }

    func encode(to encoder: any Encoder) throws {
      try vpn.encode(to: encoder)
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(active, forKey: .active)
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try container.checkVersion(forKey: .version)
    if container.contains(.error) {
      self = .refused(try container.decode(ControlRefusal.self, forKey: .error))
    } else {
      let vpns = try container.decode([Listed].self, forKey: .vpns).map(\.vpn)
      let snapshot = ControlSnapshot(tunnel: try container.decode(ControlSnapshot.Tunnel.self, forKey: .tunnel), vpns: vpns)
      self = .answered(try container.decode(ControlOutcome.self, forKey: .outcome), snapshot)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Control.version, forKey: .version)
    switch self {
    case .answered(let outcome, let snapshot):
      try container.encode(outcome, forKey: .outcome)
      try container.encode(snapshot.tunnel, forKey: .tunnel)
      let active = snapshot.tunnel.vpn?.id
      try container.encode(snapshot.vpns.map { Listed($0, active: $0.id == active) }, forKey: .vpns)
    case .refused(let refusal):
      try container.encode(refusal, forKey: .error)
    }
  }
}

extension ControlRefusal: Codable {
  private enum CodingKeys: String, CodingKey { case code, message, query, vpns, app, path }
  private enum Code: String, Codable { case noSuchVPN, ambiguous, notRunning, couldNotLaunch, outdated, blocked, pathTooLong, disabled }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Code.self, forKey: .code) {
    case .noSuchVPN:
      self = .noSuchVPN(query: try container.decode(String.self, forKey: .query), vpns: try container.decode([ControlSnapshot.VPN].self, forKey: .vpns))
    case .ambiguous:
      self = .ambiguous(query: try container.decode(String.self, forKey: .query), matches: try container.decode([ControlSnapshot.VPN].self, forKey: .vpns))
    case .notRunning: self = .notRunning
    case .couldNotLaunch: self = .couldNotLaunch
    case .outdated: self = .outdated(app: try container.decode(Int.self, forKey: .app))
    case .blocked: self = .blocked(path: try container.decode(String.self, forKey: .path))
    case .pathTooLong: self = .pathTooLong
    case .disabled: self = .disabled
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(message, forKey: .message)
    switch self {
    case .noSuchVPN(let query, let vpns):
      try container.encode(Code.noSuchVPN, forKey: .code)
      try container.encode(query, forKey: .query)
      try container.encode(vpns, forKey: .vpns)
    case .ambiguous(let query, let matches):
      try container.encode(Code.ambiguous, forKey: .code)
      try container.encode(query, forKey: .query)
      try container.encode(matches, forKey: .vpns)
    case .notRunning:
      try container.encode(Code.notRunning, forKey: .code)
    case .couldNotLaunch:
      try container.encode(Code.couldNotLaunch, forKey: .code)
    case .outdated(let app):
      try container.encode(Code.outdated, forKey: .code)
      try container.encode(app, forKey: .app)
    case .blocked(let path):
      try container.encode(Code.blocked, forKey: .code)
      try container.encode(path, forKey: .path)
    case .pathTooLong:
      try container.encode(Code.pathTooLong, forKey: .code)
    case .disabled:
      try container.encode(Code.disabled, forKey: .code)
    }
  }
}

extension ControlSnapshot.Tunnel: Codable {
  private enum CodingKeys: String, CodingKey { case state, vpn, signingIn, address, since, hosts, failure }
  private enum State: String, Codable { case off, connecting, disconnecting, on, failed }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    func vpn() throws -> ControlSnapshot.VPNRef { try container.decode(ControlSnapshot.VPNRef.self, forKey: .vpn) }
    switch try container.decode(State.self, forKey: .state) {
    case .off:
      self = .off
    case .connecting:
      self = .connecting(try vpn(), signingIn: try container.decode(Bool.self, forKey: .signingIn))
    case .disconnecting:
      self = .disconnecting(try vpn())
    case .on:
      let since = try container.decodeIfPresent(String.self, forKey: .since).map { try Date($0, strategy: .iso8601) }
      self = .on(try vpn(), address: try container.decodeIfPresent(String.self, forKey: .address), since: since,
                 hosts: try container.decode([ControlSnapshot.Host].self, forKey: .hosts))
    case .failed:
      self = .failed(try vpn(), try container.decode(ControlSnapshot.Failure.self, forKey: .failure))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(vpn, forKey: .vpn)
    switch self {
    case .off:
      try container.encode(State.off, forKey: .state)
    case .connecting(_, let signingIn):
      try container.encode(State.connecting, forKey: .state)
      try container.encode(signingIn, forKey: .signingIn)
    case .disconnecting:
      try container.encode(State.disconnecting, forKey: .state)
    case .on(_, let address, let since, let hosts):
      try container.encode(State.on, forKey: .state)
      try container.encodeIfPresent(address, forKey: .address)
      // Formatted here rather than by the encoder's date strategy, so every encoder writes the same text.
      try container.encodeIfPresent(since?.formatted(.iso8601), forKey: .since)
      try container.encode(hosts, forKey: .hosts)
    case .failed(_, let failure):
      try container.encode(State.failed, forKey: .state)
      try container.encode(failure, forKey: .failure)
    }
  }
}

extension ControlSnapshot.Host: Codable {
  private enum CodingKeys: String, CodingKey { case host, status, ms }
  private enum Code: String, Codable { case checking, reachable, unreachable }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    host = try container.decode(String.self, forKey: .host)
    status = switch try container.decode(Code.self, forKey: .status) {
    case .checking: .checking
    case .reachable: .reachable(milliseconds: try container.decode(Int.self, forKey: .ms))
    case .unreachable: .unreachable
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(host, forKey: .host)
    switch status {
    case .checking:
      try container.encode(Code.checking, forKey: .status)
    case .reachable(let milliseconds):
      try container.encode(Code.reachable, forKey: .status)
      try container.encode(milliseconds, forKey: .ms)
    case .unreachable:
      try container.encode(Code.unreachable, forKey: .status)
    }
  }
}

private extension KeyedDecodingContainer {
  func checkVersion(forKey key: Key) throws {
    let version = try decode(Int.self, forKey: key)
    guard version == Control.version else {
      throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Control version \(version), expected \(Control.version)")
    }
  }

  func decodeWait(forKey key: Key) throws -> WaitLimit {
    guard let wait = WaitLimit(seconds: try decode(Int.self, forKey: key)) else {
      throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "A timeout must be \(WaitLimit.range) seconds")
    }
    return wait
  }
}
