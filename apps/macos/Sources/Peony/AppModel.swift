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
  /// The settings window's pane. It outlives the window, so reopening Settings shows the last one.
  var settingsSelection: SettingsSelection? = .general
  /// Whether the settings window shows the Add VPN sheet.
  var isAddingVPN = false
  /// Unsaved edits, by VPN. Kept here rather than in the editor, so moving to another pane, or
  /// closing the window, never loses what was typed. A VPN has an entry only while it differs.
  private(set) var drafts: [UUID: ProfileDraft] = [:]
  private(set) var helperStatus = HelperInstaller.Status.missing
  private(set) var helperNotice: String?
  private(set) var loginNotice: String?
  /// Counts every connect and disconnect anyone asked for, from the menu or `peony`, so a request
  /// waiting on the tunnel can tell when another one replaced it.
  @ObservationIgnored private(set) var intent = 0

  @ObservationIgnored private var lastSnapshot: InterfaceSnapshot?
  @ObservationIgnored private var probeTask: Task<Void, Never>?
  @ObservationIgnored private var interfaceCheck: Task<Void, Never>?
  @ObservationIgnored private var interfaceWatcher: InterfaceWatcher?
  @ObservationIgnored private var control: ControlServer?
  @ObservationIgnored private let logger = Logger(subsystem: "app.peony", category: "app")

  init() {
    connection.onUp = { [weak self] id in
      guard let self, let profile = store.profile(id) else { return }
      startProbing(profile)
    }
    Task { [weak self] in
      guard let self else { return }
      await connection.adopt(from: store.profiles)
      // Opened only now, so a request from `peony` never races adoption.
      let control = ControlServer(model: self)
      control.start()
      self.control = control
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
        self?.isAddingVPN = true
        openSettings()
      },
      openSettings: openSettings,
      showLog: openLog,
      setOpensAtLogin: { [weak self] in self?.setOpensAtLogin($0) },
      quit: { NSApp.terminate(nil) }
    )
  }

  // MARK: Connecting

  /// Returns the work it started, so a waiting `peony` request knows when the tunnel shows this attempt.
  @discardableResult
  func connect(_ id: UUID) -> Task<Void, Never>? {
    guard let profile = store.profile(id) else { return nil }
    intent += 1
    destinations = []
    startBlooming()
    return Task {
      await connection.connect(profile)
    }
  }

  @discardableResult
  func disconnect() -> Task<Void, Never> {
    intent += 1
    probeTask?.cancel()
    destinations = []
    startBlooming()
    return Task { await connection.disconnect() }
  }

  func quit() {
    control?.stop()
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
      try? store.save(profile, secret: nil) // No secret, so nothing to fail.
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
      helperNotice = nil
    } catch {
      helperNotice = error.localizedDescription
    }
    refreshHelperStatus()
  }

  func uninstallHelper() {
    do {
      try HelperInstaller.uninstall()
      helperNotice = nil
    } catch {
      helperNotice = error.localizedDescription
    }
    refreshHelperStatus()
  }

  func setOpensAtLogin(_ enabled: Bool) {
    do {
      if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      loginNotice = nil
    } catch {
      loginNotice = "macOS didn't allow opening at login. Move Peony to Applications and try again."
    }
    opensAtLogin = SMAppService.mainApp.status == .enabled
  }

  // MARK: Editing VPNs

  /// The form as saved, with whether the Keychain holds its secrets.
  func savedDraft(_ profile: Profile) -> ProfileDraft {
    ProfileDraft(
      profile,
      hasSavedSecret: Keychain.hasSecret(for: profile.id),
      hasSavedOpenVPNPassword: Keychain.hasSecret(for: profile.id, .openVPNPassword))
  }

  func draft(_ profile: Profile) -> ProfileDraft {
    drafts[profile.id] ?? savedDraft(profile)
  }

  /// Keeps an edit, or forgets it once it matches what's saved again.
  func setDraft(_ draft: ProfileDraft, for profile: Profile) {
    drafts[profile.id] = draft == savedDraft(profile) ? nil : draft
  }

  func revert(_ id: UUID) {
    drafts[id] = nil
  }

  /// Writes the Keychain first, then the list. Throws what the Keychain refused.
  func save(_ saved: ProfileDraft.Saved) throws {
    try store.save(saved.profile, secret: saved.secret, openVPNPassword: saved.openVPNPassword)
    drafts[saved.profile.id] = nil
  }

  /// Turns the VPN off first if it's connected, then selects its neighbour in the list.
  func delete(_ id: UUID) {
    if connection.profileID == id { disconnect() }
    let ids = store.profiles.map(\.id)
    let index = ids.firstIndex(of: id)
    store.delete(id)
    drafts[id] = nil
    let remaining = store.profiles.map(\.id)
    settingsSelection = index.flatMap { remaining.indices.contains($0) ? remaining[$0] : remaining.last }
      .map(SettingsSelection.profile) ?? .general
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
  case agents
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
