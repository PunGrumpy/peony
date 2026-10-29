import AppKit
import PeonyCore
import PeonyUI
import ServiceManagement
import SwiftUI

/// The settings window: binds the panes in PeonyUI to the app. Stock controls and the person's
/// own accent colour throughout, per the macOS guidelines; Peony's brand stays in the panel.
struct SettingsView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationSplitView {
      List(selection: $model.settingsSelection) {
        Label("General", systemImage: "gearshape")
          .tag(SettingsSelection.general)
        // A terminal: agents reach Peony through the `peony` command, whichever agent runs it.
        Label("Agents", systemImage: "terminal")
          .tag(SettingsSelection.agents)
        Section("VPNs") {
          ForEach(model.store.profiles) { profile in
            VPNRow(
              profile: profile,
              isEdited: model.drafts[profile.id] != nil,
              isConnected: model.connection.profileID == profile.id && model.connection.state.address != nil)
              .tag(SettingsSelection.profile(profile.id))
          }
          .onMove { model.store.move(from: $0, to: $1) }
          // A button beside the list it adds to, not a row to select: it opens a sheet.
          Button {
            model.isAddingVPN = true
          } label: {
            Label("Add VPN…", systemImage: "plus")
          }
          .buttonStyle(.borderless)
          .keyboardShortcut("n")
          .help("Add a VPN")
        }
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
    } detail: {
      switch model.settingsSelection {
      case .general, nil:
        GeneralSettings(model: model)
      case .agents:
        AgentsSettings()
      case .profile(let id):
        if let profile = model.store.profile(id) {
          ProfileEditor(model: model, profile: profile)
            .id(id)
        } else {
          GeneralSettings(model: model)
        }
      }
    }
    .frame(minWidth: 680, minHeight: 540)
    .sheet(isPresented: $model.isAddingVPN) {
      AddVPN(model: model)
    }
    .background(SettingsWindowButtons())
  }
}

private struct VPNRow: View {
  let profile: Profile
  let isEdited: Bool
  let isConnected: Bool

  var body: some View {
    Label {
      HStack {
        Text(profile.name)
        Spacer()
        if isEdited {
          Text("Edited")
            .font(.caption)
            .foregroundStyle(.secondary)
            .help("Has changes you haven't saved")
        }
        // Only the live VPN has a dot, so it reads without its colour too.
        if isConnected {
          Circle().fill(Brand.rose).frame(width: 6, height: 6)
            .help("Connected")
            .accessibilityLabel("Connected")
        }
      }
    } icon: {
      Image(systemName: VPNType(profile.kind).symbol)
    }
  }
}

// MARK: - General

private struct GeneralSettings: View {
  let model: AppModel

  var body: some View {
    GeneralPane(
      helper: helper,
      helperNotice: model.helperNotice,
      opensAtLogin: model.opensAtLogin,
      loginNotice: model.loginNotice,
      installHelper: model.installHelper,
      uninstallHelper: model.uninstallHelper,
      setOpensAtLogin: model.setOpensAtLogin,
      openLoginItems: SMAppService.openSystemSettingsLoginItems)
      .navigationTitle("General")
      .navigationSubtitle("One VPN on at a time, so routes and DNS never fight")
      .onAppear { model.refreshHelperStatus() }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
        model.refreshHelperStatus()
      }
  }

  private var helper: GeneralPane.Helper {
    switch model.helperStatus {
    case .installed: .installed
    case .outdated: .outdated
    case .missing: .missing
    }
  }
}

// MARK: - Agents

private struct AgentsSettings: View {
  @AppStorage(ControlServer.enabledKey) private var isEnabled = true
  @State private var installed: [AgentSetup.Agent: Bool] = [:]

  var body: some View {
    AgentsPane(
      isEnabled: $isEnabled,
      rows: AgentSetup.Agent.allCases.map { agent in
        AgentsPane.Row(agent: agent, isInstalled: installed[agent], install: AgentSetup.install(agent, cli: AgentLocator.cli))
      },
      add: { row in
        switch row.install {
        case .command(let command): Terminal.run(command)
        case .link(let url, _): NSWorkspace.shared.open(url)
        }
      },
      copy: { row in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(row.install.copyText, forType: .string)
      })
      .navigationTitle("Agents")
      .task { await locate() }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
        Task { await locate() }
      }
  }

  private func locate() async {
    for agent in AgentSetup.Agent.allCases {
      installed[agent] = await AgentLocator.isInstalled(agent)
    }
  }
}

/// Finds the agents Peony can add itself to.
enum AgentLocator {
  /// `peony` inside this app, which agents start as `peony mcp`.
  static var cli: String {
    Bundle.main.bundleURL.appending(path: "Contents/Helpers/peony").path(percentEncoded: false)
  }

  static func isInstalled(_ agent: AgentSetup.Agent) async -> Bool {
    switch agent {
    case .claudeCode: await findCommand("claude")
    case .codex: await findCommand("codex")
    case .cursor: NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.todesktop.230313mzl4w4u92") != nil
    }
  }

  /// The usual install folders first, then the login shell, which knows the PATH Terminal will use.
  private static func findCommand(_ name: String) async -> Bool {
    let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
    for folder in ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
    where FileManager.default.isExecutableFile(atPath: "\(folder)/\(name)") {
      return true
    }
    guard let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell.map({ String(cString: $0) }) else { return false }
    let result = try? await Command.run(shell, arguments: ["-l", "-c", "command -v \(name)"])
    return result?.succeeded == true && !result!.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

// MARK: - Editing a VPN

/// Edits stay in `AppModel.drafts` until saved, so switching panes keeps them.
private struct ProfileEditor: View {
  let model: AppModel
  let profile: Profile

  @State private var saveError: String?
  @State private var toolsChecked = 0

  var body: some View {
    let draft = model.draft(profile)
    let isEdited = model.drafts[profile.id] != nil
    let canSave = isEdited && draft.problems.isEmpty
    ProfileForm(
      draft: Binding(get: { model.draft(profile) }, set: { model.setDraft($0, for: profile) }),
      isNew: false,
      revealsAllProblems: true,
      missingTool: missingTool(draft.type),
      saveError: saveError,
      installTool: { Terminal.run(draft.type.tool.install) },
      deletion: ProfileForm.Deletion(
        name: profile.name, isConnected: model.connection.profileID == profile.id,
        perform: { model.delete(profile.id) }))
      .navigationTitle(profile.name)
      .navigationSubtitle(profile.kindTitle)
      .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
          Button("Revert") {
            model.revert(profile.id)
            saveError = nil
          }
          .help("Go back to what's saved")
          .disabled(!isEdited)
          Button("Save") { save(draft) }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
      }
      // Command-S saves too. A button holds one shortcut, and Return already belongs to Save.
      .background {
        Button("Save") { if canSave { save(draft) } }
          .keyboardShortcut("s")
          .opacity(0)
          .accessibilityHidden(true)
      }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
        toolsChecked += 1
      }
  }

  /// Read on each render, and `toolsChecked` re-renders when you come back from Terminal.
  private func missingTool(_ type: VPNType) -> (name: String, install: String)? {
    _ = toolsChecked
    return AppTools.find(type.tool.name) == nil ? type.tool : nil
  }

  private func save(_ draft: ProfileDraft) {
    guard let saved = draft.saved(id: profile.id) else { return }
    do {
      try model.save(saved)
      saveError = nil
    } catch {
      saveError = "Couldn't save to the Keychain: \(error.localizedDescription)"
    }
  }
}

private struct AddVPN: View {
  let model: AppModel

  @State private var draft = ProfileDraft()
  @State private var saveError: String?

  var body: some View {
    AddVPNSheet(
      draft: $draft,
      missingTool: AppTools.find(draft.type.tool.name) == nil ? draft.type.tool : nil,
      saveError: saveError,
      installTool: { Terminal.run(draft.type.tool.install) },
      cancel: { model.isAddingVPN = false },
      add: add)
  }

  private func add() {
    guard let saved = draft.saved(id: UUID()) else { return }
    do {
      try model.save(saved)
      model.settingsSelection = .profile(saved.profile.id)
      model.isAddingVPN = false
    } catch {
      saveError = "Couldn't save to the Keychain: \(error.localizedDescription)"
    }
  }
}

/// Dims the window's minimize and zoom buttons, as macOS settings windows do.
private struct SettingsWindowButtons: NSViewRepresentable {
  func makeNSView(context: Context) -> ButtonsView { ButtonsView() }
  func updateNSView(_ nsView: ButtonsView, context: Context) { nsView.dim() }

  final class ButtonsView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      dim()
    }

    func dim() {
      window?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
      window?.standardWindowButton(.zoomButton)?.isEnabled = false
    }
  }
}
