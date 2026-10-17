import AppKit
import PeonyCore
import PeonyUI
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationSplitView {
      List(selection: $model.settingsSelection) {
        Label("General", systemImage: "gearshape")
          .tag(SettingsSelection.general)
        Section("VPNs") {
          ForEach(model.store.profiles) { profile in
            Label {
              HStack {
                Text(profile.name)
                Spacer()
                // Only the live VPN has a dot, so it reads without its colour too.
                if model.connection.profileID == profile.id, model.connection.state.address != nil {
                  Circle().fill(Brand.rose).frame(width: 6, height: 6)
                    .help("Connected")
                    .accessibilityLabel("Connected")
                }
              }
            } icon: {
              Image(systemName: Self.symbol(for: profile.kind))
            }
              .tag(SettingsSelection.profile(profile.id))
          }
          .onMove { model.store.move(from: $0, to: $1) }
          Label("Add VPN", systemImage: "plus")
            .tag(SettingsSelection.new)
        }
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
      switch model.settingsSelection {
      case .general, nil:
        GeneralSettings(model: model)
      case .new:
        ProfileEditor(model: model, profile: nil)
          .id("new")
      case .profile(let id):
        if let profile = model.store.profile(id) {
          ProfileEditor(model: model, profile: profile)
            .id(id)
        } else {
          GeneralSettings(model: model)
        }
      }
    }
    .frame(minWidth: 680, minHeight: 480)
    .tint(Brand.rose)
  }

  static func symbol(for kind: Profile.Kind) -> String {
    switch kind {
    case .forti: "lock.shield.fill"
    case .openConnect: "network.badge.shield.half.filled"
    case .openVPN: "key.horizontal.fill"
    case .wireGuard: "bolt.horizontal.fill"
    case .netBird: "point.3.filled.connected.trianglepath.dotted"
    case .tailscale: "circle.grid.3x3.fill"
    }
  }
}

// MARK: - General

private struct GeneralSettings: View {
  let model: AppModel

  var body: some View {
    Form {
      Section("Helper") {
        LabeledContent {
          switch model.helperStatus {
          case .installed:
            Button("Uninstall…") { model.uninstallHelper() }
          case .outdated:
            Button("Update") { model.installHelper() }.buttonStyle(.borderedProminent)
          case .missing:
            Button("Install") { model.installHelper() }.buttonStyle(.borderedProminent)
          }
        } label: {
          Text(helperTitle)
          Text("A small root tool that starts tunnels and sets routes. It only accepts validated settings from your VPN list and only runs tools from Homebrew.")
        }
      }

      Section("Tools") {
        ToolRow(name: "openfortivpn", purpose: "FortiGate", install: "brew install openfortivpn")
        ToolRow(name: "openconnect", purpose: "AnyConnect, GlobalProtect, Pulse, F5", install: "brew install openconnect")
        ToolRow(name: "openvpn", purpose: "OpenVPN", install: "brew install openvpn")
        ToolRow(name: "wg-quick", purpose: "WireGuard", install: "brew install wireguard-tools")
        ToolRow(name: "netbird", purpose: "NetBird", install: "brew install netbirdio/tap/netbird")
        ToolRow(name: "tailscale", purpose: "Tailscale", install: "brew install --cask tailscale-app")
      }

      Section {
        Toggle("Open Peony at login", isOn: Binding(
          get: { model.opensAtLogin },
          set: { model.setOpensAtLogin($0) }))
      }

      if let notice = model.notice {
        Section { Text(notice).foregroundStyle(Brand.warning) }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("General")
    .navigationSubtitle("One VPN on at a time, so routes and DNS never fight")
    .onAppear { model.refreshHelperStatus() }
  }

  private var helperTitle: String {
    switch model.helperStatus {
    case .installed: "Installed"
    case .outdated: "Needs an update"
    case .missing: "Not installed"
    }
  }
}

private struct ToolRow: View {
  let name: String
  let purpose: String
  let install: String

  var body: some View {
    LabeledContent {
      if AppTools.find(name) != nil {
        Label("Installed", systemImage: "checkmark.circle.fill")
          .labelStyle(.titleAndIcon)
          .foregroundStyle(Brand.muted)
      } else {
        Button("Install with Homebrew") { Terminal.run(install) }
      }
    } label: {
      Text(name).font(.system(.body, design: .monospaced))
      Text(purpose)
    }
  }
}

// MARK: - Profile editor

private enum KindChoice: String, CaseIterable, Identifiable {
  case forti, openConnect, openVPN, wireGuard, netBird, tailscale
  var id: Self { self }

  var title: String {
    switch self {
    case .forti: "FortiGate"
    case .openConnect: "AnyConnect & more"
    case .openVPN: "OpenVPN"
    case .wireGuard: "WireGuard"
    case .netBird: "NetBird"
    case .tailscale: "Tailscale"
    }
  }

  var symbol: String {
    switch self {
    case .forti: "lock.shield.fill"
    case .openConnect: "network.badge.shield.half.filled"
    case .openVPN: "key.horizontal.fill"
    case .wireGuard: "bolt.horizontal.fill"
    case .netBird: "point.3.filled.connected.trianglepath.dotted"
    case .tailscale: "circle.grid.3x3.fill"
    }
  }

  init(_ kind: Profile.Kind) {
    switch kind {
    case .forti: self = .forti
    case .openConnect: self = .openConnect
    case .openVPN: self = .openVPN
    case .wireGuard: self = .wireGuard
    case .netBird: self = .netBird
    case .tailscale: self = .tailscale
    }
  }
}

private struct ProfileEditor: View {
  let model: AppModel
  let original: Profile?
  let hasSavedSecret: Bool
  let hasSavedOpenVPNPassword: Bool

  @State private var name: String
  @State private var choice: KindChoice
  @State private var forti: Profile.Forti
  @State private var openConnect: Profile.OpenConnect
  @State private var wireGuard: Profile.WireGuard
  @State private var openVPN: Profile.OpenVPN
  @State private var openVPNPassword: String
  @State private var netBird: Profile.NetBird
  @State private var secret: String
  @State private var destinations: String
  @State private var error: String?
  @State private var confirmingDelete = false

  init(model: AppModel, profile: Profile?) {
    self.model = model
    original = profile
    let kind = profile?.kind ?? .forti(.init())
    _name = State(initialValue: profile?.name ?? "")
    _choice = State(initialValue: KindChoice(kind))
    if case .forti(let settings) = kind { _forti = State(initialValue: settings) } else { _forti = State(initialValue: .init()) }
    if case .openConnect(let settings) = kind { _openConnect = State(initialValue: settings) } else { _openConnect = State(initialValue: .init()) }
    if case .wireGuard(let settings) = kind { _wireGuard = State(initialValue: settings) } else { _wireGuard = State(initialValue: .init()) }
    if case .openVPN(let settings) = kind { _openVPN = State(initialValue: settings) } else { _openVPN = State(initialValue: .init()) }
    if case .netBird(let settings) = kind { _netBird = State(initialValue: settings) } else { _netBird = State(initialValue: .init()) }
    // The saved secret stays in the Keychain: reading it here would make macOS ask permission
    // just to show a form. An empty field means "keep what's saved".
    _secret = State(initialValue: "")
    _openVPNPassword = State(initialValue: "")
    hasSavedSecret = profile.map { Keychain.hasSecret(for: $0.id) } ?? false
    hasSavedOpenVPNPassword = profile.map { Keychain.hasSecret(for: $0.id, .openVPNPassword) } ?? false
    _destinations = State(initialValue: profile?.destinations.joined(separator: ", ") ?? "")
  }

  var body: some View {
    Form {
      if original == nil {
        Section {
          Picker("Kind", selection: $choice) {
            ForEach(KindChoice.allCases) { kind in
              Label(kind.title, systemImage: kind.symbol).tag(kind)
            }
          }
        } footer: {
          Text("Pick the kind of VPN, then fill in what your admin gave you.")
        }
      }

      Section("Name") {
        TextField("Name", text: $name, prompt: Text("Work VPN"))
      }

      Section("Connection") {
        fields
      }

      Section {
        TextField("Check these hosts", text: $destinations, prompt: Text("gitlab.example.com, 10.0.0.5:22"))
      } header: {
        Text("Reachable")
      } footer: {
        Text("Once connected, Peony checks these hosts so you know your services are actually reachable. Port 443 unless you add one.")
      }

      if let error {
        Section { Text(error).foregroundStyle(Brand.warning) }
      }
    }
    .formStyle(.grouped)
    .navigationTitle(original == nil ? "Add VPN" : name.isEmpty ? "VPN" : name)
    .navigationSubtitle(original == nil ? "" : choice.title)
    .toolbar {
      // Delete is a quiet icon in its own group, away from Save, so the two can't be mistaken.
      if original != nil {
        ToolbarItem(placement: .primaryAction) {
          Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
            .help("Delete this VPN")
        }
        if #available(macOS 26, *) {
          ToolbarSpacer(.fixed, placement: .primaryAction)
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Save", action: save)
          .keyboardShortcut("s")
          .buttonStyle(.borderedProminent)
      }
    }
    .confirmationDialog("Delete \(name)?", isPresented: $confirmingDelete) {
      Button("Delete", role: .destructive) {
        guard let original else { return }
        if model.connection.profileID == original.id { model.disconnect() }
        model.store.delete(original.id)
        model.settingsSelection = .general
      }
    } message: {
      Text("Peony also removes its saved password from the Keychain.")
    }
  }

  @ViewBuilder private var fields: some View {
    switch choice {
    case .forti:
      TextField("Server", text: $forti.host, prompt: Text("vpn.example.com"))
      TextField("Port", value: $forti.port, format: .number.grouping(.never))
      TextField("Username", text: $forti.username)
      SecureField("Password", text: $secret, prompt: Text(passwordPrompt))
      TextField("Trusted certificate", text: Binding(
        get: { forti.trustedCert ?? "" }, set: { forti.trustedCert = $0.isEmpty ? nil : $0 }),
        prompt: Text("Optional SHA-256, for self-signed gateways"))
      TextField("Realm", text: Binding(
        get: { forti.realm ?? "" }, set: { forti.realm = $0.isEmpty ? nil : $0 }),
        prompt: Text("Optional"))

    case .openConnect:
      Picker("Protocol", selection: $openConnect.serverProtocol) {
        ForEach(Profile.OpenConnect.ServerProtocol.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      TextField("Server", text: $openConnect.server, prompt: Text("vpn.example.com or https://vpn.example.com/group"))
      TextField("Username", text: $openConnect.username)
      SecureField("Password", text: $secret, prompt: Text(passwordPrompt))
      TextField("Server certificate", text: Binding(
        get: { openConnect.serverCert ?? "" }, set: { openConnect.serverCert = $0.isEmpty ? nil : $0 }),
        prompt: Text("Optional pin-sha256:…"))

    case .openVPN:
      configEditor(fileExtensions: ["ovpn", "conf"], footnote: "Stored in your Keychain. OpenVPN runs as root, so scripts, plugins and paths to other files aren't allowed. Keep certificates and keys inline.")
      TextField("Username", text: $openVPN.username, prompt: Text("Leave empty if you only sign in with a certificate"))
      SecureField("Password", text: $openVPNPassword, prompt: Text(openVPN.username.isEmpty ? "Not needed without a username" : passwordPrompt))
        .disabled(openVPN.username.isEmpty)

    case .wireGuard:
      TextField("Interface", text: $wireGuard.interfaceName, prompt: Text("peony0"))
      configEditor(fileExtensions: ["conf"], footnote: "Stored in your Keychain. PostUp and PreDown lines aren't allowed, since they'd run as root.")

    case .netBird:
      TextField("Management URL", text: $netBird.managementURL, prompt: Text("Leave empty for NetBird Cloud"))
      Text("The first time, NetBird opens your browser to sign in.")
        .foregroundStyle(Brand.muted)

    case .tailscale:
      Text("Sign in from the Tailscale app first. Peony turns it on and off; accounts and exit nodes stay in Tailscale.")
        .foregroundStyle(Brand.muted)
    }
  }

  private var passwordPrompt: String {
    (choice == .openVPN ? hasSavedOpenVPNPassword : hasSavedSecret) ? "Saved in Keychain. Type to replace." : "Required"
  }

  /// A pasted or imported config, which is saved to the Keychain whole.
  private func configEditor(fileExtensions: [String], footnote: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Configuration")
        Spacer()
        Button("Import .\(fileExtensions[0])…") { importConfig(fileExtensions) }
      }
      if hasSavedSecret && secret.isEmpty {
        Text("A configuration is saved in your Keychain. Paste or import a new one to replace it.")
          .font(.caption)
          .foregroundStyle(Brand.muted)
      }
      TextEditor(text: $secret)
        .font(.system(.callout, design: .monospaced))
        .frame(minHeight: 140)
        .scrollContentBackground(.hidden)
        .background(Brand.chip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      Text(footnote)
        .font(.caption)
        .foregroundStyle(Brand.muted)
    }
  }

  private func importConfig(_ fileExtensions: [String]) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = fileExtensions.compactMap { UTType(filenameExtension: $0) } + [.plainText]
    guard panel.runModal() == .OK, let url = panel.url, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
    secret = text
    if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
  }

  private func save() {
    do {
      let profile = try buildProfile()
      try model.store.save(profile, secret: secret.isEmpty ? nil : secret, openVPNPassword: openVPNPassword.isEmpty ? nil : openVPNPassword)
      model.settingsSelection = .profile(profile.id)
      error = nil
    } catch let failure as Validation.Failure {
      error = failure.description
    } catch let problem as WireGuardConfig.Problem {
      error = problem.description
    } catch let problem as OpenVPNConfig.Problem {
      error = problem.description
    } catch {
      self.error = error.localizedDescription
    }
  }

  private func buildProfile() throws -> Profile {
    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    guard !trimmedName.isEmpty else { throw Validation.Failure.invalid(field: "Name", reason: "is empty") }
    let kind: Profile.Kind
    switch choice {
    case .forti:
      var settings = forti
      settings.host = try Validation.host(settings.host)
      settings.port = try Validation.port(settings.port)
      settings.username = try Validation.secretLine(settings.username, field: "Username")
      if let cert = settings.trustedCert { settings.trustedCert = try Validation.sha256Digest(cert) }
      kind = .forti(settings)
    case .openConnect:
      var settings = openConnect
      settings.server = try Validation.server(settings.server)
      settings.username = try Validation.secretLine(settings.username, field: "Username")
      if let cert = settings.serverCert { settings.serverCert = try Validation.serverCertPin(cert) }
      kind = .openConnect(settings)
    case .openVPN:
      var settings = openVPN
      settings.username = try Validation.secretLine(settings.username, field: "Username", allowEmpty: true)
      if !secret.isEmpty || !hasSavedSecret {
        let config = try OpenVPNConfig(validating: secret)
        secret = config.text
        settings.server = config.server
      }
      kind = .openVPN(settings)
    case .wireGuard:
      var settings = wireGuard
      settings.interfaceName = try Validation.interfaceName(settings.interfaceName)
      if !secret.isEmpty || !hasSavedSecret { secret = try WireGuardConfig.validate(secret) }
      kind = .wireGuard(settings)
    case .netBird:
      var settings = netBird
      if !settings.managementURL.isEmpty { settings.managementURL = try Validation.server(settings.managementURL, field: "Management URL") }
      kind = .netBird(settings)
    case .tailscale:
      kind = .tailscale
    }
    let hosts = destinations.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" }).map(String.init)
    for host in hosts where Probe.Target(host) == nil {
      throw Validation.Failure.invalid(field: "Reachable", reason: "\(host) isn't host or host:port")
    }
    return Profile(id: original?.id ?? UUID(), name: trimmedName, kind: kind, destinations: hosts)
  }
}
