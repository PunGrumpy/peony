import Foundation
import Observation
import OSLog
import PeonyCore
import PeonyUI

/// The one tunnel that's up, or on its way. Peony keeps a single connection on
/// purpose: two VPNs fighting over routes and DNS is the problem it exists to solve.
@Observable
final class Connection {
  private(set) var profileID: UUID?
  private(set) var state: TunnelState = .off
  private(set) var since: Date?
  /// The tunnel tool's output, for the log window.
  private(set) var log: [String] = []

  @ObservationIgnored private var process: Process?
  @ObservationIgnored private var kind: Profile.Kind?
  @ObservationIgnored private var before = InterfaceSnapshot(ipv4: [:])
  @ObservationIgnored private var failure: TunnelFailure?
  @ObservationIgnored private var pendingText = ""
  @ObservationIgnored private var fortiParser = FortiLogParser()
  @ObservationIgnored private let logger = Logger(subsystem: "app.peony", category: "connection")

  // MARK: Connect

  func connect(_ profile: Profile) async {
    if profileID != nil, state != .off {
      await disconnect()
    }
    profileID = profile.id
    kind = profile.kind
    UserDefaults.standard.set(profile.id.uuidString, forKey: Self.lastProfileKey)
    state = .connecting
    since = nil
    failure = nil
    log.removeAll()
    pendingText = ""
    fortiParser = FortiLogParser()
    before = InterfaceSnapshot.current()

    if let problem = preflight(profile) {
      state = .failed(problem)
      return
    }

    var secret = ""
    if profile.needsPassword || { if case .wireGuard = profile.kind { true } else { false } }() {
      switch Keychain.secret(for: profile.id) {
      case .secret(let saved):
        secret = saved
      case .missing:
        state = .failed(TunnelFailure(message: "\(profile.name) doesn't have a password yet.", fix: .editProfile))
        return
      case .locked:
        state = .failed(TunnelFailure(
          message: "Peony was updated and can't read the password saved by the old version. Enter it once more in Settings.",
          fix: .editProfile))
        return
      }
    }

    switch profile.kind {
    case .forti(let settings):
      let request = HelperRequest.forti(.init(
        host: settings.host, port: settings.port, username: settings.username,
        password: secret,
        trustedCert: settings.trustedCert, realm: settings.realm))
      launchHelper(request)

    case .openConnect(let settings):
      let request = HelperRequest.openConnect(.init(
        server: settings.server, serverProtocol: settings.serverProtocol, username: settings.username,
        password: secret, serverCert: settings.serverCert))
      launchHelper(request)

    case .wireGuard(let settings):
      let request = HelperRequest.wireGuardUp(.init(
        interfaceName: settings.interfaceName, config: secret))
      let result = await runHelper(request)
      appendLog(result.output)
      if result.status == 0 {
        markUp()
      } else {
        state = .failed(failure ?? TunnelFailure(message: lastErrorLine(result.output) ?? "wg-quick couldn't bring the tunnel up.", fix: .editProfile))
      }

    case .netBird(let settings):
      var arguments = ["up"]
      if !settings.managementURL.isEmpty { arguments += ["--management-url", settings.managementURL] }
      await bringUp(.netBird, arguments: arguments,
                    fallback: "NetBird didn't connect. If it asked you to sign in, finish that in your browser and try again.")

    case .tailscale:
      // Bare `up` keeps the exit node and other settings chosen in Tailscale,
      // but would wait on a browser if nobody is signed in.
      guard let status = await Daemon.tailscale.status(), !status.needsLogin else {
        state = .failed(TunnelFailure(message: "Tailscale isn't running, signed in or approved yet. Open the Tailscale app, finish signing in, then connect again."))
        return
      }
      await bringUp(.tailscale, arguments: ["up"], fallback: "Tailscale didn't connect.")
    }
  }

  private func bringUp(_ daemon: Daemon, arguments: [String], fallback: String) async {
    let result = try? await Command.run(daemon.executable, arguments: arguments)
    appendLog(result?.text ?? "")
    await refreshDaemon()
    if state == .connecting {
      let detail = result.flatMap { lastErrorLine($0.text) }
      state = .failed(TunnelFailure(message: detail ?? fallback))
    }
  }

  /// Catches what would otherwise fail deep inside a root process, with a fix the user can act on.
  private func preflight(_ profile: Profile) -> TunnelFailure? {
    let tool: (name: String, install: String) = switch profile.kind {
    case .forti: ("openfortivpn", "brew install openfortivpn")
    case .openConnect: ("openconnect", "brew install openconnect")
    case .wireGuard: ("wg-quick", "brew install wireguard-tools")
    case .netBird: ("netbird", "brew install netbirdio/tap/netbird")
    case .tailscale: ("tailscale", "brew install --cask tailscale-app")
    }
    if AppTools.find(tool.name) == nil {
      return TunnelFailure(
        message: "\(profile.kindTitle) needs \(tool.name), which isn't installed yet.",
        fix: .installTool(name: tool.name, command: tool.install))
    }
    if profile.kind.daemon != nil { return nil }
    if HelperInstaller.status != .installed {
      return TunnelFailure(
        message: "Peony needs a one-time admin approval to set up routes and DNS for VPNs.",
        fix: .installHelper)
    }
    if profile.needsPassword || { if case .wireGuard = profile.kind { true } else { false } }() {
      if !Keychain.hasSecret(for: profile.id) {
        let what = profile.needsPassword ? "a password" : "a configuration"
        return TunnelFailure(message: "\(profile.name) doesn't have \(what) yet.", fix: .editProfile)
      }
    }
    return nil
  }

  // MARK: Adopt

  private static let lastProfileKey = "lastProfileID"

  /// Picks up a tunnel that's already running: one Peony started before it was quit,
  /// crashed or updated, or a NetBird or Tailscale connection made elsewhere. Without this the panel
  /// would say "Not connected" over a live tunnel, and connecting again would stack a second one.
  func adopt(from profiles: [Profile]) async {
    guard state == .off else { return }
    let last = UserDefaults.standard.string(forKey: Self.lastProfileKey).flatMap(UUID.init)
    let lastProfile = profiles.first { $0.id == last }
    let snapshot = InterfaceSnapshot.current()

    func running(_ name: String) async -> Bool {
      (try? await Command.run("/usr/bin/pgrep", "-x", name))?.succeeded == true
    }

    if await running("openfortivpn"), let address = snapshot.fortiAddress {
      let profile = lastProfile.flatMap { if case .forti = $0.kind { $0 } else { nil } }
        ?? profiles.first { if case .forti = $0.kind { true } else { false } }
      take(profile, address: address)
    } else if await running("openconnect") {
      let profile = lastProfile.flatMap { if case .openConnect = $0.kind { $0 } else { nil } }
        ?? profiles.first { if case .openConnect = $0.kind { true } else { false } }
      take(profile, address: snapshot.ipv4.first { $0.key.hasPrefix("utun") && !InterfaceSnapshot.isCGNAT($0.value) }?.value ?? "")
    } else {
      for profile in profiles where profile.kind.daemon != nil {
        profileID = profile.id
        kind = profile.kind
        await refreshDaemon()
        if state != .off { break }
        profileID = nil
        kind = nil
      }
    }
  }

  private func take(_ profile: Profile?, address: String) {
    guard let profile else { return }
    profileID = profile.id
    kind = profile.kind
    state = .on(address: address)
    since = nil
    logger.info("Adopted a running \(profile.kindTitle, privacy: .public) tunnel")
  }

  // MARK: Disconnect

  func disconnect() async {
    guard state != .off, let kind else {
      state = .off
      return
    }
    state = .disconnecting

    switch kind {
    case .forti, .openConnect:
      if let process {
        // sudo relays SIGINT to the helper, which passes it to the tunnel so it can tear down routes.
        process.interrupt()
        for _ in 0..<80 where self.process != nil {
          try? await Task.sleep(for: .milliseconds(100))
        }
      }
      if process != nil || state.address != nil {
        _ = await runHelper(.stop)
        for _ in 0..<80 where InterfaceSnapshot.current().fortiAddress != nil || process != nil {
          try? await Task.sleep(for: .milliseconds(100))
        }
      }
    case .wireGuard(let settings):
      let result = await runHelper(.wireGuardDown(interfaceName: settings.interfaceName))
      appendLog(result.output)
    case .netBird, .tailscale:
      if let daemon = kind.daemon { _ = try? await Command.run(daemon.executable, "down") }
    }
    finish()
  }

  /// Ends the tunnel without waiting, for when the app quits.
  func hangUp() {
    process?.interrupt()
  }

  private func finish() {
    state = .off
    since = nil
    process = nil
  }

  // MARK: Monitoring

  /// Called on every interface change. Tunnels without a supervising process
  /// (WireGuard, NetBird, Tailscale) are only noticed going away this way.
  func interfacesChanged() async {
    guard let kind, state.address != nil || state == .connecting else { return }
    switch kind {
    case .netBird, .tailscale:
      await refreshDaemon()
    case .wireGuard:
      if newAddress() == nil, state.address != nil {
        state = .failed(TunnelFailure(message: "The WireGuard interface went away."))
      }
    case .forti, .openConnect:
      if case .on(let address) = state, address.isEmpty, let found = newAddress() {
        state = .on(address: found)
      }
    }
  }

  private func refreshDaemon() async {
    guard let status = await kind?.daemon?.status() else { return }
    if status.isConnected, state != .disconnecting {
      if state.address == nil { since = .now }
      state = .on(address: status.address ?? "")
    } else if state.address != nil {
      finish()
    }
  }

  // MARK: Helper process

  private func launchHelper(_ request: HelperRequest) {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/sudo")
    process.arguments = ["-n", Helper.installedPath, "run"]
    let input = Pipe()
    let output = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = output

    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else {
        handle.readabilityHandler = nil
        return
      }
      let text = String(decoding: data, as: UTF8.self)
      Task { @MainActor in self?.consume(text) }
    }
    process.terminationHandler = { [weak self] finished in
      let status = finished.terminationStatus
      Task { @MainActor in self?.processEnded(status: status) }
    }

    do {
      try process.run()
      self.process = process
      input.fileHandleForWriting.write((try? JSONEncoder().encode(request)) ?? Data())
      try? input.fileHandleForWriting.close()
    } catch {
      logger.error("Couldn't launch the helper: \(error.localizedDescription, privacy: .public)")
      state = .failed(TunnelFailure(message: "Couldn't start Peony's helper.", fix: .installHelper))
    }
  }

  private func runHelper(_ request: HelperRequest) async -> (status: Int32, output: String) {
    let payload = (try? JSONEncoder().encode(request)) ?? Data()
    do {
      let result = try await Command.run("/usr/bin/sudo", arguments: ["-n", Helper.installedPath, "run"], input: payload)
      return (result.status, result.text)
    } catch {
      return (-1, error.localizedDescription)
    }
  }

  private func consume(_ text: String) {
    pendingText += text
    var lines = pendingText.components(separatedBy: "\n")
    pendingText = lines.removeLast()
    for line in lines where !line.isEmpty {
      appendLine(line)
      if let event = parse(line) { handle(event) }
    }
  }

  private func parse(_ line: String) -> TunnelEvent? {
    switch kind {
    case .forti: fortiParser.consume(line)
    case .openConnect: OpenConnectLogParser().consume(line)
    default: nil
    }
  }

  private func handle(_ event: TunnelEvent) {
    switch event {
    case .tunnelUp:
      markUp()
    case .authenticationFailed:
      failure = TunnelFailure(message: "The server rejected the username or password.", fix: .editProfile)
    case .certificateRejected(let pin):
      failure = TunnelFailure(
        message: "The server's certificate isn't trusted. If your admin confirms it, Peony can trust it for this VPN.",
        fix: pin.map { .trustCertificate(pin: $0) } ?? .editProfile)
    case .sudoNeedsPassword:
      failure = TunnelFailure(message: "Peony's helper isn't set up for this account.", fix: .installHelper)
    case .error(let message):
      if failure == nil { failure = TunnelFailure(message: message) }
    }
  }

  private func markUp() {
    since = .now
    state = .on(address: newAddress() ?? "")
  }

  private func processEnded(status: Int32) {
    process = nil
    if !pendingText.isEmpty { consume("\n") }
    logger.info("Tunnel process exited with status \(status)")
    switch state {
    case .disconnecting, .off:
      break
    case .on:
      state = .failed(failure ?? TunnelFailure(message: "The connection dropped."))
      since = nil
    case .connecting, .failed:
      state = .failed(failure ?? TunnelFailure(message: "The tunnel stopped before it came up (exit \(status))."))
    }
  }

  // MARK: Helpers

  /// The address of whichever interface appeared since connecting began.
  private func newAddress() -> String? {
    let now = InterfaceSnapshot.current().ipv4
    return now.first { name, address in
      before.ipv4[name] != address && (name.hasPrefix("utun") || name.hasPrefix("ppp") || name.hasPrefix("tun"))
    }?.value
  }

  private func appendLog(_ text: String) {
    for line in text.components(separatedBy: "\n") where !line.isEmpty {
      appendLine(line)
      if let event = parse(line) { handle(event) }
    }
  }

  private func appendLine(_ line: String) {
    log.append(line)
    if log.count > 500 { log.removeFirst(log.count - 500) }
  }

  private func lastErrorLine(_ output: String) -> String? {
    output.components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .last { !$0.isEmpty }
      .map { $0.hasPrefix("ERROR:") ? $0.dropFirst(6).trimmingCharacters(in: .whitespaces) : $0 }
  }
}
