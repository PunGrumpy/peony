import PeonyCore
import SwiftUI

// The Settings window's panes, driven by plain values like the panel, so snapshots render them
// without the app. They use stock controls and system colours: Peony's brand stays in the panel.

public struct GeneralPane: View {
  public enum Helper: Sendable {
    case installed, outdated, missing
  }

  let helper: Helper
  let helperNotice: String?
  let opensAtLogin: Bool
  let loginNotice: String?
  let installHelper: () -> Void
  let uninstallHelper: () -> Void
  let setOpensAtLogin: (Bool) -> Void
  let openLoginItems: () -> Void

  public init(
    helper: Helper, helperNotice: String? = nil, opensAtLogin: Bool, loginNotice: String? = nil,
    installHelper: @escaping () -> Void = {}, uninstallHelper: @escaping () -> Void = {},
    setOpensAtLogin: @escaping (Bool) -> Void = { _ in }, openLoginItems: @escaping () -> Void = {}
  ) {
    self.helper = helper
    self.helperNotice = helperNotice
    self.opensAtLogin = opensAtLogin
    self.loginNotice = loginNotice
    self.installHelper = installHelper
    self.uninstallHelper = uninstallHelper
    self.setOpensAtLogin = setOpensAtLogin
    self.openLoginItems = openLoginItems
  }

  public var body: some View {
    Form {
      Section {
        LabeledContent("Helper") {
          HStack {
            Text(helperTitle).foregroundStyle(.secondary)
            switch helper {
            case .installed: Button("Uninstall…", action: uninstallHelper)
            case .outdated: Button("Update", action: installHelper).buttonStyle(.borderedProminent)
            case .missing: Button("Install", action: installHelper).buttonStyle(.borderedProminent)
            }
          }
        }
      } footer: {
        FormFooter {
          if let helperNotice { ProblemCaption(helperNotice) }
          Text("Starts tunnels and sets routes. It only accepts validated settings from your VPN list and only runs tools from Homebrew.")
        }
      }

      Section {
        Toggle("Open Peony at login", isOn: Binding(get: { opensAtLogin }, set: { setOpensAtLogin($0) }))
      } footer: {
        if let loginNotice {
          FormFooter {
            ProblemCaption(loginNotice)
            Button("Open Login Items Settings…", action: openLoginItems)
          }
        }
      }
    }
    .formStyle(.grouped)
  }

  private var helperTitle: String {
    switch helper {
    case .installed: "Installed"
    case .outdated: "Needs an update"
    case .missing: "Not installed"
    }
  }
}

public struct AgentsPane: View {
  /// One agent Peony can add itself to.
  public struct Row: Identifiable, Sendable {
    public var agent: AgentSetup.Agent
    /// Nil while Peony is still looking.
    public var isInstalled: Bool?
    public var install: AgentSetup.Install

    public var id: AgentSetup.Agent { agent }

    public init(agent: AgentSetup.Agent, isInstalled: Bool?, install: AgentSetup.Install) {
      self.agent = agent
      self.isInstalled = isInstalled
      self.install = install
    }
  }

  @Binding var isEnabled: Bool
  let rows: [Row]
  let add: (Row) -> Void
  let copy: (Row) -> Void

  @State private var copied: AgentSetup.Agent?

  public init(isEnabled: Binding<Bool>, rows: [Row], add: @escaping (Row) -> Void = { _ in }, copy: @escaping (Row) -> Void = { _ in }) {
    _isEnabled = isEnabled
    self.rows = rows
    self.add = add
    self.copy = copy
  }

  public var body: some View {
    Form {
      Section {
        Toggle("Let agents control Peony", isOn: $isEnabled)
      } footer: {
        FormFooter("Agents only see your VPN names and status, and can connect and disconnect. Trusting a server, editing VPNs and passwords stay in Peony.")
      }

      Section {
        ForEach(rows) { row in
          LabeledContent {
            HStack {
              Button(copied == row.agent ? "Copied" : "Copy", systemImage: copied == row.agent ? "checkmark" : "doc.on.doc") {
                copy(row)
                copied = row.agent
                Task {
                  try? await Task.sleep(for: .seconds(1.5))
                  if copied == row.agent { copied = nil }
                }
              }
              .labelStyle(.iconOnly)
              .help(copyHelp(row))
              // An ellipsis: it opens Terminal or Cursor.
              Button("Add…") { add(row) }
                .disabled(row.isInstalled != true)
            }
          } label: {
            Text(row.agent.title)
            Text(status(row))
          }
        }
      } header: {
        Text("Add Peony to your agent")
      } footer: {
        FormFooter("Claude Code and Codex add Peony from Terminal. Cursor asks you to confirm.")
      }
    }
    .formStyle(.grouped)
  }

  private func status(_ row: Row) -> String {
    switch row.isInstalled {
    case nil: "Checking…"
    case true?: "Installed"
    case false?: "Not installed"
    }
  }

  private func copyHelp(_ row: Row) -> String {
    switch row.install {
    case .command: "Copy the command"
    case .link: "Copy the mcp.json entry"
    }
  }
}

/// Adding a VPN: modal to the Settings window, so nothing typed is lost by clicking elsewhere in it.
public struct AddVPNSheet: View {
  @Binding var draft: ProfileDraft
  let revealsAllProblems: Bool
  let missingTool: (name: String, install: String)?
  let saveError: String?
  let installTool: () -> Void
  let cancel: () -> Void
  let add: () -> Void

  public init(
    draft: Binding<ProfileDraft>, revealsAllProblems: Bool = false, missingTool: (name: String, install: String)?,
    saveError: String? = nil, installTool: @escaping () -> Void = {}, cancel: @escaping () -> Void = {}, add: @escaping () -> Void = {}
  ) {
    _draft = draft
    self.revealsAllProblems = revealsAllProblems
    self.missingTool = missingTool
    self.saveError = saveError
    self.installTool = installTool
    self.cancel = cancel
    self.add = add
  }

  public var body: some View {
    VStack(spacing: 0) {
      ProfileForm(
        draft: $draft, isNew: true, revealsAllProblems: revealsAllProblems, missingTool: missingTool,
        saveError: saveError, installTool: installTool)
      Divider()
      HStack {
        Spacer()
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
        Button("Add", action: add)
          .keyboardShortcut(.defaultAction)
          .disabled(!draft.problems.isEmpty)
      }
      .padding(16)
    }
    .frame(width: 500, height: 520)
  }
}
