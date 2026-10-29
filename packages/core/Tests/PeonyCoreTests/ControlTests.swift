import Darwin
import Foundation
import Testing
@testable import PeonyCore

/// `peony --json` prints these replies as they are, and agents parse them. A change to any pinned
/// string here breaks scripts in the wild, so it needs a `Control.version` bump.
struct ControlTests {
  typealias Tunnel = ControlSnapshot.Tunnel

  static let officeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
  static let homeID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
  static let office = ControlSnapshot.VPN(
    id: officeID, name: "Office", kind: .forti, endpoint: "vpn.example.com", hosts: ["git.corp.example:22", "wiki.corp.example"])
  static let home = ControlSnapshot.VPN(id: homeID, name: "Home", kind: .wireGuard, endpoint: "peony0", hosts: [])
  static let officeRef = ControlSnapshot.VPNRef(id: officeID, name: "Office")
  static let homeRef = ControlSnapshot.VPNRef(id: homeID, name: "Home")

  private func line(_ reply: ControlReply) throws -> String {
    String(decoding: try Control.line(reply), as: UTF8.self)
  }

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }

  // MARK: Golden JSON

  @Test func `a connected tunnel with its host checks`() throws {
    let since = try Date("2026-10-29T09:12:03Z", strategy: .iso8601)
    let reply = ControlReply.answered(.done, ControlSnapshot(
      tunnel: .on(Self.officeRef, address: "10.212.134.5", since: since, hosts: [
        .init(host: "git.corp.example", status: .reachable(milliseconds: 23)),
        .init(host: "wiki.corp.example", status: .unreachable),
      ]),
      vpns: [Self.office, Self.home]))
    let golden = #"""
      {"outcome":"done","tunnel":{"address":"10.212.134.5","hosts":[{"host":"git.corp.example","ms":23,"status":"reachable"},{"host":"wiki.corp.example","status":"unreachable"}],"since":"2026-10-29T09:12:03Z","state":"on","vpn":{"id":"00000000-0000-0000-0000-000000000001","name":"Office"}},"version":1,"vpns":[{"active":true,"endpoint":"vpn.example.com","hosts":["git.corp.example:22","wiki.corp.example"],"id":"00000000-0000-0000-0000-000000000001","kind":"forti","name":"Office"},{"active":false,"endpoint":"peony0","hosts":[],"id":"00000000-0000-0000-0000-000000000002","kind":"wireGuard","name":"Home"}]}

      """#
    #expect(try line(reply) == golden)
    #expect(try decode(ControlReply.self, golden) == reply)
  }

  @Test func `an adopted tunnel has no since, and a host still being checked says so`() throws {
    let reply = ControlReply.answered(.timedOut, ControlSnapshot(
      tunnel: .on(Self.homeRef, address: nil, since: nil, hosts: [.init(host: "nas.home", status: .checking)]),
      vpns: [Self.home]))
    let golden = #"""
      {"outcome":"timedOut","tunnel":{"hosts":[{"host":"nas.home","status":"checking"}],"state":"on","vpn":{"id":"00000000-0000-0000-0000-000000000002","name":"Home"}},"version":1,"vpns":[{"active":true,"endpoint":"peony0","hosts":[],"id":"00000000-0000-0000-0000-000000000002","kind":"wireGuard","name":"Home"}]}

      """#
    #expect(try line(reply) == golden)
    #expect(try decode(ControlReply.self, golden) == reply)
  }

  @Test func `off has no VPN and nothing is active`() throws {
    let reply = ControlReply.answered(.done, ControlSnapshot(tunnel: .off, vpns: [Self.home]))
    let golden = #"""
      {"outcome":"done","tunnel":{"state":"off"},"version":1,"vpns":[{"active":false,"endpoint":"peony0","hosts":[],"id":"00000000-0000-0000-0000-000000000002","kind":"wireGuard","name":"Home"}]}

      """#
    #expect(try line(reply) == golden)
    #expect(try decode(ControlReply.self, golden) == reply)
  }

  @Test func `a connect waiting on browser sign-in says so`() throws {
    let reply = ControlReply.answered(.timedOut, ControlSnapshot(tunnel: .connecting(Self.officeRef, signingIn: true), vpns: []))
    let golden = #"""
      {"outcome":"timedOut","tunnel":{"signingIn":true,"state":"connecting","vpn":{"id":"00000000-0000-0000-0000-000000000001","name":"Office"}},"version":1,"vpns":[]}

      """#
    #expect(try line(reply) == golden)
    #expect(try decode(ControlReply.self, golden) == reply)
  }

  @Test func `disconnecting names the VPN going down`() throws {
    let reply = ControlReply.answered(.interrupted, ControlSnapshot(tunnel: .disconnecting(Self.homeRef), vpns: []))
    let golden = #"""
      {"outcome":"interrupted","tunnel":{"state":"disconnecting","vpn":{"id":"00000000-0000-0000-0000-000000000002","name":"Home"}},"version":1,"vpns":[]}

      """#
    #expect(try line(reply) == golden)
    #expect(try decode(ControlReply.self, golden) == reply)
  }

  @Test func `a failure carries a command only when the fix is an install`() throws {
    let tool = ControlReply.answered(.failed, ControlSnapshot(
      tunnel: .failed(Self.officeRef, .init(
        message: "FortiGate needs openfortivpn, which isn't installed yet.",
        fix: .init(kind: .installTool, title: "Install openfortivpn", command: "brew install openfortivpn"))),
      vpns: []))
    let toolGolden = #"""
      {"outcome":"failed","tunnel":{"failure":{"fix":{"command":"brew install openfortivpn","kind":"installTool","title":"Install openfortivpn"},"message":"FortiGate needs openfortivpn, which isn't installed yet."},"state":"failed","vpn":{"id":"00000000-0000-0000-0000-000000000001","name":"Office"}},"version":1,"vpns":[]}

      """#
    #expect(try line(tool) == toolGolden)
    #expect(try decode(ControlReply.self, toolGolden) == tool)

    let trust = ControlReply.answered(.failed, ControlSnapshot(
      tunnel: .failed(Self.officeRef, .init(message: "The server's certificate isn't trusted.", fix: .init(kind: .trustCertificate, title: "Trust this server"))),
      vpns: []))
    let trustGolden = #"""
      {"outcome":"failed","tunnel":{"failure":{"fix":{"kind":"trustCertificate","title":"Trust this server"},"message":"The server's certificate isn't trusted."},"state":"failed","vpn":{"id":"00000000-0000-0000-0000-000000000001","name":"Office"}},"version":1,"vpns":[]}

      """#
    #expect(try line(trust) == trustGolden)
    #expect(try decode(ControlReply.self, trustGolden) == trust)

    let bare = ControlReply.answered(.failed, ControlSnapshot(tunnel: .failed(Self.homeRef, .init(message: "The connection dropped.", fix: nil)), vpns: []))
    #expect(try decode(ControlReply.self, try line(bare)) == bare)
  }

  @Test func `refusals share the envelope and explain themselves`() throws {
    let missing = ControlReply.refused(.noSuchVPN(query: "ofice", vpns: [Self.home]))
    let missingGolden = #"""
      {"error":{"code":"noSuchVPN","message":"No VPN is named \"ofice\". Run `peony list` to see them.","query":"ofice","vpns":[{"endpoint":"peony0","hosts":[],"id":"00000000-0000-0000-0000-000000000002","kind":"wireGuard","name":"Home"}]},"version":1}

      """#
    #expect(try line(missing) == missingGolden)
    #expect(try decode(ControlReply.self, missingGolden) == missing)

    let notRunning = ControlReply.refused(.notRunning)
    let notRunningGolden = #"""
      {"error":{"code":"notRunning","message":"Peony isn't running. `peony connect` opens it."},"version":1}

      """#
    #expect(try line(notRunning) == notRunningGolden)

    let disabled = ControlReply.refused(.disabled)
    let disabledGolden = #"""
      {"error":{"code":"disabled","message":"Agents can't control Peony right now. Turn it on in Peony Settings › Agents."},"version":1}

      """#
    #expect(try line(disabled) == disabledGolden)
    #expect(try decode(ControlReply.self, disabledGolden) == disabled)

    for refusal: ControlRefusal in [
      .ambiguous(query: "office", matches: [Self.office, Self.office]), .notRunning, .couldNotLaunch,
      .outdated(app: 2), .blocked(path: "/tmp/control.sock"), .pathTooLong,
    ] {
      #expect(try decode(ControlReply.self, try line(.refused(refusal))) == .refused(refusal))
    }
  }

  @Test func `a reply line is one line even when a name holds a newline`() throws {
    let odd = ControlSnapshot.VPN(id: Self.homeID, name: "Two\nLines", kind: .wireGuard, endpoint: "peony0", hosts: [])
    let data = try Control.line(ControlReply.answered(.done, ControlSnapshot(tunnel: .off, vpns: [odd])))
    #expect(data.filter { $0 == UInt8(ascii: "\n") }.count == 1)
    #expect(data.last == UInt8(ascii: "\n"))
  }

  @Test func `a reply from another version is refused`() throws {
    let future = #"{"outcome":"done","tunnel":{"state":"off"},"version":2,"vpns":[]}"#
    #expect(throws: DecodingError.self) { try decode(ControlReply.self, future) }
    #expect(Control.version(of: Data(future.utf8)) == 2)
    #expect(Control.version(of: Data("not json".utf8)) == nil)
  }

  // MARK: Secrets

  @Test func `usernames, realms and certificate pins never leave the profile`() throws {
    let forti = Profile(name: "Office", kind: .forti(.init(
      host: "vpn.example.com", login: .password(username: "alex-user"), trustedCert: "abab0123pin", realm: "staff-realm")))
    let campus = Profile(name: "Campus", kind: .openConnect(.init(
      server: "vpn.example.edu", serverProtocol: .gp, username: "sam-user", serverCert: "pin-sha256:campus-pin")))
    let openVPN = Profile(name: "Lab", kind: .openVPN(.init(username: "lab-user", server: "ovpn.example.com")))
    let reply = ControlReply.answered(.done, ControlSnapshot(
      tunnel: .off, vpns: [ControlSnapshot.VPN(forti), ControlSnapshot.VPN(campus), ControlSnapshot.VPN(openVPN)]))
    let json = try line(reply)
    for secret in ["alex-user", "staff-realm", "abab0123pin", "sam-user", "campus-pin", "lab-user"] {
      #expect(!json.contains(secret), "\(secret) leaked")
    }
    #expect(json.contains("vpn.example.com"))
    #expect(json.contains(#""kind":"openConnect""#))
  }

  // MARK: Requests

  @Test func `requests round-trip as one flat line`() throws {
    let connect = ControlRequest.connect(vpn: "Office", wait: try #require(WaitLimit(seconds: 120)))
    #expect(String(decoding: try Control.line(connect), as: UTF8.self) == #"{"command":"connect","timeout":120,"version":1,"vpn":"Office"}"# + "\n")
    #expect(String(decoding: try Control.line(ControlRequest.status), as: UTF8.self) == #"{"command":"status","version":1}"# + "\n")
    for request: ControlRequest in [.status, connect, .disconnect(wait: .disconnect)] {
      #expect(try decode(ControlRequest.self, String(decoding: try Control.line(request), as: UTF8.self)) == request)
    }
  }

  @Test(arguments: [
    #"{"version":1,"command":"trust"}"#,
    #"{"version":1,"command":"connect","timeout":90}"#,
    #"{"version":1,"command":"connect","vpn":"Office"}"#,
    #"{"version":1,"command":"connect","vpn":"Office","timeout":0}"#,
    #"{"version":1,"command":"disconnect","timeout":601}"#,
    #"{"version":1,"command":"disconnect","timeout":"30"}"#,
    #"{"version":1,"command":"disconnect","timeout":1.5}"#,
    #"{"command":"status"}"#,
    #"{"version":2,"command":"status"}"#,
  ])
  func `a malformed request is refused`(json: String) {
    #expect(throws: DecodingError.self) { try decode(ControlRequest.self, json) }
  }

  @Test func `a wait is 1 to 600 seconds`() {
    #expect(WaitLimit(seconds: 0) == nil)
    #expect(WaitLimit(seconds: -1) == nil)
    #expect(WaitLimit(seconds: 601) == nil)
    #expect(WaitLimit(seconds: 1)?.seconds == 1)
    #expect(WaitLimit(seconds: 600)?.seconds == 600)
    #expect(WaitLimit.connect.seconds == 90)
    #expect(WaitLimit.disconnect.seconds == 30)
  }

  // MARK: Name resolution

  @Test func `a name matches exactly, ignoring case and surrounding spaces`() {
    let vpns = [Self.office, Self.home]
    #expect(ControlPolicy.resolve("Office", among: vpns) == .success(Self.officeID))
    #expect(ControlPolicy.resolve("oFFICE", among: vpns) == .success(Self.officeID))
    #expect(ControlPolicy.resolve("  home ", among: vpns) == .success(Self.homeID))
  }

  @Test func `an id matches, and wins over a VPN named like it`() {
    let impostor = ControlSnapshot.VPN(id: UUID(), name: Self.officeID.uuidString, kind: .tailscale, endpoint: "Tailscale", hosts: [])
    let vpns = [impostor, Self.office]
    #expect(ControlPolicy.resolve(Self.officeID.uuidString, among: vpns) == .success(Self.officeID))
    #expect(ControlPolicy.resolve(Self.officeID.uuidString.lowercased(), among: vpns) == .success(Self.officeID))
  }

  @Test func `a prefix or a typo matches nothing`() {
    let vpns = [Self.office, Self.home]
    #expect(ControlPolicy.resolve("off", among: vpns) == .failure(.noSuchVPN(query: "off", vpns: vpns)))
    #expect(ControlPolicy.resolve("ofice", among: vpns) == .failure(.noSuchVPN(query: "ofice", vpns: vpns)))
    #expect(ControlPolicy.resolve("", among: vpns) == .failure(.noSuchVPN(query: "", vpns: vpns)))
    #expect(ControlPolicy.resolve(UUID().uuidString, among: vpns).isFailure)
  }

  @Test func `two VPNs with one name are ambiguous, and both are listed`() {
    let twin = ControlSnapshot.VPN(id: UUID(), name: "office", kind: .openVPN, endpoint: "ovpn.example.com", hosts: [])
    let vpns = [Self.office, Self.home, twin]
    #expect(ControlPolicy.resolve("Office", among: vpns) == .failure(.ambiguous(query: "Office", matches: [Self.office, twin])))
    #expect(ControlPolicy.resolve(twin.id.uuidString, among: vpns) == .success(twin.id))
  }

  // MARK: Settled

  @Test func `settled means off, failed, or on with every host checked`() {
    let failure = ControlSnapshot.Failure(message: "x", fix: nil)
    #expect(Tunnel.off.isSettled)
    #expect(Tunnel.failed(Self.officeRef, failure).isSettled)
    #expect(Tunnel.on(Self.officeRef, address: "10.0.0.5", since: nil, hosts: []).isSettled)
    #expect(Tunnel.on(Self.officeRef, address: "10.0.0.5", since: nil, hosts: [
      .init(host: "a", status: .reachable(milliseconds: 4)), .init(host: "b", status: .unreachable),
    ]).isSettled)
    #expect(!Tunnel.on(Self.officeRef, address: "10.0.0.5", since: nil, hosts: [
      .init(host: "a", status: .reachable(milliseconds: 4)), .init(host: "b", status: .checking),
    ]).isSettled)
    #expect(!Tunnel.connecting(Self.officeRef, signingIn: false).isSettled)
    #expect(!Tunnel.disconnecting(Self.officeRef).isSettled)
  }

  // MARK: What a request does first

  static let checked = Tunnel.on(officeRef, address: "10.0.0.5", since: nil, hosts: [.init(host: "a", status: .unreachable)])
  static let checking = Tunnel.on(officeRef, address: "10.0.0.5", since: nil, hosts: [.init(host: "a", status: .checking)])
  static let officeFailed = Tunnel.failed(officeRef, .init(message: "x", fix: nil))

  @Test func `connecting what's already on or coming up never restarts it`() {
    let up = ControlPolicy.Goal.up(Self.officeID)
    #expect(ControlPolicy.plan(up, Self.checked) == .done)
    #expect(ControlPolicy.plan(up, Self.checking) == .join)
    #expect(ControlPolicy.plan(up, .connecting(Self.officeRef, signingIn: true)) == .join)
  }

  @Test func `connecting starts from anything else, after a teardown finishes`() {
    let up = ControlPolicy.Goal.up(Self.officeID)
    #expect(ControlPolicy.plan(up, .off) == .start)
    #expect(ControlPolicy.plan(up, Self.officeFailed) == .start)
    #expect(ControlPolicy.plan(up, .on(Self.homeRef, address: nil, since: nil, hosts: [])) == .start)
    #expect(ControlPolicy.plan(up, .connecting(Self.homeRef, signingIn: false)) == .start)
    #expect(ControlPolicy.plan(up, .failed(Self.homeRef, .init(message: "x", fix: nil))) == .start)
    #expect(ControlPolicy.plan(up, .disconnecting(Self.homeRef)) == .waitForOff)
    #expect(ControlPolicy.plan(up, .disconnecting(Self.officeRef)) == .waitForOff)
  }

  @Test func `disconnecting acts on any tunnel that isn't already off`() {
    #expect(ControlPolicy.plan(.down, .off) == .done)
    #expect(ControlPolicy.plan(.down, Self.officeFailed) == .start)
    #expect(ControlPolicy.plan(.down, .disconnecting(Self.officeRef)) == .join)
    #expect(ControlPolicy.plan(.down, Self.checked) == .start)
    #expect(ControlPolicy.plan(.down, .connecting(Self.officeRef, signingIn: true)) == .start)
  }

  // MARK: How a wait ends

  @Test func `a connect is done once its VPN is on and every host was checked`() {
    let up = ControlPolicy.Goal.up(Self.officeID)
    #expect(ControlPolicy.outcome(up, Self.checked, replaced: false) == .done)
    #expect(ControlPolicy.outcome(up, .on(Self.officeRef, address: nil, since: nil, hosts: []), replaced: false) == .done)
    #expect(ControlPolicy.outcome(up, Self.checking, replaced: false) == nil)
    #expect(ControlPolicy.outcome(up, .connecting(Self.officeRef, signingIn: true), replaced: false) == nil)
    #expect(ControlPolicy.outcome(up, Self.officeFailed, replaced: false) == .failed)
  }

  @Test func `a connect is interrupted by another request, another VPN, or a closed sign-in window`() {
    let up = ControlPolicy.Goal.up(Self.officeID)
    for tunnel in [Self.checked, Self.checking, Self.officeFailed, .connecting(Self.officeRef, signingIn: false), .off] {
      #expect(ControlPolicy.outcome(up, tunnel, replaced: true) == .interrupted)
    }
    #expect(ControlPolicy.outcome(up, .off, replaced: false) == .interrupted)
    #expect(ControlPolicy.outcome(up, .disconnecting(Self.officeRef), replaced: false) == .interrupted)
    #expect(ControlPolicy.outcome(up, .connecting(Self.homeRef, signingIn: false), replaced: false) == .interrupted)
    #expect(ControlPolicy.outcome(up, .on(Self.homeRef, address: nil, since: nil, hosts: []), replaced: false) == .interrupted)
    #expect(ControlPolicy.outcome(up, .failed(Self.homeRef, .init(message: "x", fix: nil)), replaced: false) == .interrupted)
  }

  @Test func `a disconnect is done once nothing is up, whoever else asked`() {
    for replaced in [false, true] {
      #expect(ControlPolicy.outcome(.down, .off, replaced: replaced) == .done)
      #expect(ControlPolicy.outcome(.down, Self.officeFailed, replaced: replaced) == .done)
    }
    #expect(ControlPolicy.outcome(.down, .disconnecting(Self.officeRef), replaced: false) == nil)
    #expect(ControlPolicy.outcome(.down, .disconnecting(Self.officeRef), replaced: true) == .interrupted)
    #expect(ControlPolicy.outcome(.down, .connecting(Self.homeRef, signingIn: false), replaced: true) == .interrupted)
    #expect(ControlPolicy.outcome(.down, Self.checked, replaced: true) == .interrupted)
  }

  // MARK: Exit codes

  @Test func `every reply exits with its documented code`() {
    let snapshot = ControlSnapshot(tunnel: .off, vpns: [])
    let table: [(ControlReply, Int32)] = [
      (.answered(.done, snapshot), 0),
      (.answered(.failed, snapshot), 1),
      (.answered(.timedOut, snapshot), 5),
      (.answered(.interrupted, snapshot), 6),
      (.refused(.noSuchVPN(query: "x", vpns: [])), 4),
      (.refused(.ambiguous(query: "x", matches: [])), 4),
      (.refused(.notRunning), 3),
      (.refused(.couldNotLaunch), 3),
      (.refused(.outdated(app: 2)), 3),
      (.refused(.blocked(path: "/x")), 3),
      (.refused(.pathTooLong), 3),
      (.refused(.disabled), 3),
    ]
    for (reply, code) in table {
      #expect(reply.exitCode == code, "\(reply)")
    }
    #expect(ControlReply.usageExitCode == 2)
  }

  // MARK: Socket path

  @Test func `the socket sits next to the profiles, unless the path is too long for a socket`() {
    #expect(Control.socketPath(home: URL(filePath: "/Users/alex")) == "/Users/alex/Library/Application Support/Peony/control.sock")
    #expect(Control.socketPath(home: URL(filePath: "/Users/" + String(repeating: "a", count: 120))) == nil)
  }
}

/// The control socket, end to end over real Unix sockets in a short temporary directory.
struct ControlSocketTests {
  static let reply = ControlReply.answered(.done, ControlSnapshot(tunnel: .off, vpns: [ControlTests.home]))

  private actor Calls {
    var count = 0
    func record() { count += 1 }
  }

  private func temporaryPath() throws -> String {
    var template = Array("/tmp/pc.XXXXXX".utf8CString)
    guard mkdtemp(&template) != nil else { throw POSIXError(.EIO) }
    return String(decoding: template.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self) + "/control.sock"
  }

  /// Connects as a raw client, sends `bytes`, and returns what came back before the server closed.
  private func exchange(_ bytes: Data, at path: String) async throws -> Data {
    try await withCheckedThrowingContinuation { done in
      DispatchQueue.global().async { done.resume(with: Result { try exchangeNow(bytes, at: path) }) }
    }
  }

  private func exchangeNow(_ bytes: Data, at path: String) throws -> Data {
    let fd = try ControlSocket.connect(to: path).get()
    defer { close(fd) }
    if !bytes.isEmpty { #expect(ControlSocket.write(bytes, to: fd)) }
    var received = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = read(fd, &chunk, chunk.count)
      guard count > 0 else { return received }
      received.append(contentsOf: chunk[..<count])
    }
  }

  @Test func `a request gets the app's reply, over a socket only this user can open`() async throws {
    let path = try temporaryPath()
    let listener = try ControlSocket.serve(at: path) { request in
      request == .status ? Self.reply : .refused(.notRunning)
    }
    defer { listener.close() }
    #expect(await ControlSocket.send(.status, to: path, timeout: .seconds(2)) == Self.reply)

    var info = stat()
    #expect(stat(path, &info) == 0)
    #expect(info.st_mode & 0o777 == 0o600)
  }

  @Test func `a second server leaves a live socket to the first`() async throws {
    let path = try temporaryPath()
    let first = try ControlSocket.serve(at: path) { _ in Self.reply }
    defer { first.close() }
    #expect(throws: ControlSocket.Problem.inUse) {
      _ = try ControlSocket.serve(at: path) { _ in .refused(.couldNotLaunch) }
    }
    #expect(await ControlSocket.send(.status, to: path, timeout: .seconds(2)) == Self.reply)
  }

  @Test func `a socket left by a crashed app is replaced`() async throws {
    let path = try temporaryPath()
    // What a crash leaves: a socket file bound by a process that's gone.
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.utf8)) }
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    close(fd)
    #expect(bound == 0)
    #expect(FileManager.default.fileExists(atPath: path))

    let listener = try ControlSocket.serve(at: path) { _ in Self.reply }
    defer { listener.close() }
    #expect(await ControlSocket.send(.status, to: path, timeout: .seconds(2)) == Self.reply)
  }

  @Test func `a file that isn't a socket is left alone`() async throws {
    let path = try temporaryPath()
    #expect(FileManager.default.createFile(atPath: path, contents: Data("keep".utf8)))
    #expect(throws: ControlSocket.Problem.notASocket) {
      _ = try ControlSocket.serve(at: path) { _ in Self.reply }
    }
    #expect(FileManager.default.contents(atPath: path) == Data("keep".utf8))
  }

  @Test func `closing removes the socket, and then nobody is running`() async throws {
    let path = try temporaryPath()
    let listener = try ControlSocket.serve(at: path) { _ in Self.reply }
    listener.close()
    #expect(!FileManager.default.fileExists(atPath: path))
    #expect(await ControlSocket.send(.status, to: path, timeout: .seconds(1)) == .refused(.notRunning))
  }

  @Test func `a path too long for a socket is refused on both sides`() async throws {
    let path = "/tmp/" + String(repeating: "p", count: 120)
    #expect(throws: ControlSocket.Problem.pathTooLong) {
      _ = try ControlSocket.serve(at: path) { _ in Self.reply }
    }
    #expect(await ControlSocket.send(.status, to: path, timeout: .seconds(1)) == .refused(.pathTooLong))
  }

  @Test func `an app that never answers times out as not running`() async throws {
    let path = try temporaryPath()
    let listener = try ControlSocket.serve(at: path) { _ in
      try? await Task.sleep(for: .seconds(30))
      return Self.reply
    }
    defer { listener.close() }
    let start = ContinuousClock.now
    #expect(await ControlSocket.send(.status, to: path, timeout: .milliseconds(200)) == .refused(.notRunning))
    #expect(ContinuousClock.now - start < .seconds(1))
  }

  @Test func `garbage, an overlong line and a silent client are closed without reaching the app`() async throws {
    let path = try temporaryPath()
    let calls = Calls()
    let listener = try ControlSocket.serve(at: path) { _ in
      await calls.record()
      return Self.reply
    }
    defer { listener.close() }

    #expect(try await exchange(Data("hello\n".utf8), at: path).isEmpty)
    let overlong = Data(#"{"version":1,"command":"connect","timeout":90,"vpn":""#.utf8) + Data(repeating: UInt8(ascii: "a"), count: 5000) + Data("\"}\n".utf8)
    #expect(try await exchange(overlong, at: path).isEmpty)
    let start = ContinuousClock.now
    #expect(try await exchange(Data(), at: path).isEmpty)
    #expect(ContinuousClock.now - start < .seconds(4))
    #expect(await calls.count == 0)
  }

  @Test func `a request from another version is told the app is outdated`() async throws {
    let path = try temporaryPath()
    let listener = try ControlSocket.serve(at: path) { _ in Self.reply }
    defer { listener.close() }
    let answer = try await exchange(Data((#"{"version":2,"command":"status"}"# + "\n").utf8), at: path)
    #expect(try JSONDecoder().decode(ControlReply.self, from: answer) == .refused(.outdated(app: Control.version)))
  }

  @Test func `concurrent requests are all answered`() async throws {
    let path = try temporaryPath()
    let listener = try ControlSocket.serve(at: path) { _ in
      try? await Task.sleep(for: .milliseconds(100))
      return Self.reply
    }
    defer { listener.close() }
    let replies = await withTaskGroup(of: ControlReply.self) { group in
      for _ in 0..<20 {
        group.addTask { await ControlSocket.send(.status, to: path, timeout: .seconds(5)) }
      }
      return await group.reduce(into: []) { $0.append($1) }
    }
    #expect(replies == Array(repeating: Self.reply, count: 20))
  }
}

struct LineBufferTests {
  @Test func `a line ends at the first newline, and the rest is ignored`() {
    var buffer = LineBuffer(limit: 16)
    #expect(buffer.append(Data("{\"a\"".utf8)) == .incomplete)
    #expect(buffer.append(Data(":1}\nmore".utf8)) == .line(Data("{\"a\":1}".utf8)))
  }

  @Test func `a line over the limit is refused, with or without its newline`() {
    var open = LineBuffer(limit: 4)
    #expect(open.append(Data("abcd".utf8)) == .incomplete)
    #expect(open.append(Data("e".utf8)) == .tooLong)
    var closed = LineBuffer(limit: 4)
    #expect(closed.append(Data("abcde\n".utf8)) == .tooLong)
    var exact = LineBuffer(limit: 4)
    #expect(exact.append(Data("abcd\n".utf8)) == .line(Data("abcd".utf8)))
  }
}

private extension Result {
  var isFailure: Bool {
    if case .failure = self { true } else { false }
  }
}
