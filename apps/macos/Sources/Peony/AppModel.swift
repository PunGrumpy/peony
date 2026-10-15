import AppKit
import Observation
import OSLog
import PeonyCore
import PeonyUI
import ServiceManagement

@Observable
final class AppModel {
  let store = ProfileStore()
  let connection = Connection()

  private(set) var destinations: [DestinationStatus] = []
  /// Advances while connecting, so the menu bar flower blooms.
  private(set) var bloomStep = 0
  private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
  /// Which profile the settings window should show, set when the panel sends the user there.
  var settingsSelection: SettingsSelection? = .general
  /// Bumped to ask the settings window to come forward.
  private(set) var settingsRequest = 0
  private(set) var helperStatus = HelperInstaller.Status.missing
  private(set) var notice: String?

  @ObservationIgnored private var lastSnapshot: InterfaceSnapshot?
  @ObservationIgnored private var probeTask: Task<Void, Never>?
  @ObservationIgnored private var interfaceCheck: Task<Void, Never>?
  @ObservationIgnored private var interfaceWatcher: InterfaceWatcher?
  @ObservationIgnored private let logger = Logger(subsystem: "app.peony", category: "app")

  init() {
    Task { [weak self] in
      guard let self else { return }
      await connection.adopt(from: store.profiles)
      if let id = connection.profileID, connection.state.address != nil, let profile = store.profile(id) {
        startProbing(profile)
      }
    }
    refreshHelperStatus()
    interfaceWatcher = InterfaceWatcher { [weak self] in self?.interfacesMayHaveChanged() }
  }

  // MARK: Panel

  var panelState: PanelState {
    PanelState(
      routes: store.profiles.map { profile in
        Route(id: profile.id, name: profile.name, kind: routeKind(profile.kind), endpoint: profile.endpoint)
      },
      activeRouteID: connection.profileID,
      connection: connection.state,
      connectedSince: connection.since,
      destinations: destinations,
      opensAtLogin: opensAtLogin
    )
  }

  /// What the menu bar shows: petals filled, and the active VPN's name.
  var menuBar: (petals: Int, title: String?) {
    let name = connection.profileID.flatMap { store.profile($0)?.name }
    switch connection.state {
    case .on: return (PeonyMark.shapeCount, name)
    case .connecting: return (bloomStep, name.map { "\($0)…" })
    case .disconnecting: return (bloomStep, nil)
    case .off, .failed: return (0, nil)
    }
  }

  func actions(openSettings: @escaping () -> Void, openLog: @escaping () -> Void) -> PanelActions {
    PanelActions(
      connect: { [weak self] id in self?.connect(id) },
      disconnect: { [weak self] in self?.disconnect() },
      retry: { [weak self] in
        guard let self, let id = connection.profileID else { return }
        connect(id)
      },
      fix: { [weak self] fix in self?.apply(fix, openSettings: openSettings) },
      addVPN: { [weak self] in
        self?.settingsSelection = .new
        openSettings()
      },
      openSettings: { [weak self] in
        self?.settingsSelection = self?.connection.profileID.map(SettingsSelection.profile) ?? .general
        openSettings()
      },
      showLog: openLog,
      setOpensAtLogin: { [weak self] in self?.setOpensAtLogin($0) },
      quit: { NSApp.terminate(nil) }
    )
  }

  // MARK: Connecting

  func connect(_ id: UUID) {
    guard let profile = store.profile(id) else { return }
    destinations = []
    startBlooming()
    Task {
      await connection.connect(profile)
      if connection.state.address != nil { startProbing(profile) }
    }
  }

  func disconnect() {
    probeTask?.cancel()
    destinations = []
    startBlooming()
    Task { await connection.disconnect() }
  }

  func quit() {
    connection.hangUp()
  }

  private func apply(_ fix: TunnelFailure.Fix, openSettings: () -> Void) {
    switch fix {
    case .installHelper:
      do {
        try HelperInstaller.install()
        refreshHelperStatus()
        if let id = connection.profileID { connect(id) }
      } catch {
        logger.error("Helper install failed: \(error.localizedDescription, privacy: .public)")
      }
    case .installTool(_, let command):
      Terminal.run(command)
    case .trustCertificate(let pin):
      guard let id = connection.profileID, var profile = store.profile(id), confirmTrust(pin, for: profile) else { return }
      switch profile.kind {
      case .forti(var settings):
        settings.trustedCert = pin
        profile.kind = .forti(settings)
      case .openConnect(var settings):
        settings.serverCert = pin
        profile.kind = .openConnect(settings)
      default:
        return
      }
      store.save(profile, secret: nil)
      connect(id)
    case .editProfile:
      settingsSelection = connection.profileID.map(SettingsSelection.profile) ?? .general
      openSettings()
    }
  }

  /// Trusting a certificate is the one choice here that weakens security, so it's never one click.
  private func confirmTrust(_ pin: String, for profile: Profile) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Trust this server for \(profile.name)?"
    alert.informativeText = """
      \(profile.endpoint) presented a certificate macOS doesn't trust. Only continue if your admin confirms this fingerprint:

      \(pin)
      """
    alert.addButton(withTitle: "Trust")
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning
    NSApp.activate()
    return alert.runModal() == .alertFirstButtonReturn
  }

  // MARK: Settings

  func refreshHelperStatus() {
    Task { helperStatus = await HelperInstaller.status() }
  }

  func installHelper() {
    do {
      try HelperInstaller.install()
      notice = nil
    } catch {
      notice = error.localizedDescription
    }
    refreshHelperStatus()
  }

  func uninstallHelper() {
    do {
      try HelperInstaller.uninstall()
      notice = nil
    } catch {
      notice = error.localizedDescription
    }
    refreshHelperStatus()
  }

  func setOpensAtLogin(_ enabled: Bool) {
    do {
      if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      notice = nil
    } catch {
      notice = "macOS didn't allow opening at login. Move Peony to Applications and try again."
    }
    opensAtLogin = SMAppService.mainApp.status == .enabled
  }

  // MARK: Background work

  /// A tunnel coming up changes several keys in a burst; this checks once when it settles,
  /// so a daemon's status command isn't run for each.
  private func interfacesMayHaveChanged() {
    interfaceCheck?.cancel()
    interfaceCheck = Task { [weak self] in
      guard (try? await Task.sleep(for: .milliseconds(500))) != nil else { return }
      await self?.checkInterfaces()
    }
  }

  private func checkInterfaces() async {
    let snapshot = InterfaceSnapshot.current()
    guard snapshot != lastSnapshot else { return }
    lastSnapshot = snapshot
    await connection.interfacesChanged()
  }

  /// Checks each destination now, then every 30 seconds while the tunnel stays up.
  private func startProbing(_ profile: Profile) {
    probeTask?.cancel()
    let targets = profile.destinations.compactMap(Probe.Target.init)
    guard !targets.isEmpty else { return }
    destinations = targets.map { DestinationStatus(host: $0.host, reachability: .checking) }
    probeTask = Task { [weak self] in
      while !Task.isCancelled {
        let results = await withTaskGroup(of: (Int, Int?).self) { group in
          for (index, target) in targets.enumerated() {
            group.addTask { (index, await Probe.connect(to: target)) }
          }
          var results: [Int: Int?] = [:]
          for await (index, ms) in group { results[index] = ms }
          return results
        }
        guard let self, connection.state.address != nil, !Task.isCancelled else { return }
        destinations = targets.enumerated().map { index, target in
          let ms = results[index] ?? nil
          return DestinationStatus(host: target.host, reachability: ms.map { .reachable(milliseconds: $0) } ?? .unreachable)
        }
        // Tolerance lets macOS fold this wakeup in with others, which matters on battery.
        try? await Task.sleep(for: .seconds(30), tolerance: .seconds(10))
      }
    }
  }

  /// While connecting, the bud fills and holds; the petals arrive with the connection.
  /// Nothing cycles, so the menu bar never flashes.
  private func startBlooming() {
    bloomStep = 1
  }

  private func routeKind(_ kind: Profile.Kind) -> Route.Kind {
    switch kind {
    case .forti: .forti
    case .openConnect: .openConnect
    case .wireGuard: .wireGuard
    case .openVPN: .openVPN
    case .netBird: .netBird
    case .tailscale: .tailscale
    }
  }
}

enum SettingsSelection: Hashable {
  case general
  case new
  case profile(UUID)
}

/// Opens Terminal running a command, for installs that need the user's own shell (Homebrew).
enum Terminal {
  static func run(_ command: String) {
    let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let script = """
    tell application "Terminal"
      activate
      do script "\(escaped)"
    end tell
    """
    var error: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&error)
  }
}
