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
            Label(profile.name, systemImage: Self.symbol(for: profile.kind))
              .tag(SettingsSelection.profile(profile.id))
          }
          .onMove { model.store.move(from: $0, to: $1) }
          Label("Add VPN", systemImage: "plus")
            .foregroundStyle(Brand.muted)
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
    case .wireGuard: "bolt.horizontal.fill"
    case .netBird: "point.3.filled.connected.trianglepath.dotted"
    }
  }
}

// MARK: - General

private struct GeneralSettings: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        PageTitle(title: "General", subtitle: "Peony keeps one VPN on at a time, so routes and DNS never fight.")
      }

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
        ToolRow(name: "openfortivpn", purpose: "FortiGate", formula: "openfortivpn")
        ToolRow(name: "openconnect", purpose: "AnyConnect, GlobalProtect, Pulse, F5", formula: "openconnect")
        ToolRow(name: "wg-quick", purpose: "WireGuard", formula: "wireguard-tools")
        ToolRow(name: "netbird", purpose: "NetBird", formula: "netbirdio/tap/netbird")
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
  let formula: String

  var body: some View {
    LabeledContent {
      if Tools.find(name) != nil {
        Label("Installed", systemImage: "checkmark.circle.fill")
          .labelStyle(.titleAndIcon)
          .foregroundStyle(Brand.muted)
      } else {
        Button("Install with Homebrew") { Terminal.run("brew install \(formula)") }
      }
    } label: {
      Text(name).font(.system(.body, design: .monospaced))
      Text(purpose)
    }
  }
}

private struct PageTitle: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(Typeface.display(26))
        .tracking(Typeface.displayTracking(26))
      Text(subtitle)
        .foregroundStyle(Brand.muted)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Profile editor

private enum KindChoice: String, CaseIterable, Identifiable {
  case forti, openConnect, wireGuard, netBird
  var id: Self { self }

  var title: String {
    switch self {
    case .forti: "FortiGate"
    case .openConnect: "AnyConnect & more"
    case .wireGuard: "WireGuard"
    case .netBird: "NetBird"
    }
  }

  var symbol: String {
    switch self {
    case .forti: "lock.shield.fill"
    case .openConnect: "network.badge.shield.half.filled"
    case .wireGuard: "bolt.horizontal.fill"
    case .netBird: "point.3.filled.connected.trianglepath.dotted"
    }
  }

  init(_ kind: Profile.Kind) {
    switch kind {
    case .forti: self = .forti
    case .openConnect: self = .openConnect
    case .wireGuard: self = .wireGuard
    case .netBird: self = .netBird
    }
  }
}

private struct ProfileEditor: View {
  let model: AppModel
  let original: Profile?
  let hasSavedSecret: Bool

  @State private var name: String
  @State private var choice: KindChoice
  @State private var forti: Profile.Forti
  @State private var openConnect: Profile.OpenConnect
  @State private var wireGuard: Profile.WireGuard
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
    if case .netBird(let settings) = kind { _netBird = State(initialValue: settings) } else { _netBird = State(initialValue: .init()) }
    // The saved secret stays in the Keychain: reading it here would make macOS ask permission
    // just to show a form. An empty field means "keep what's saved".
    _secret = State(initialValue: "")
    hasSavedSecret = profile.map { Keychain.hasSecret(for: $0.id) } ?? false
    _destinations = State(initialValue: profile?.destinations.joined(separator: ", ") ?? "")
  }

  var body: some View {
    Form {
      Section {
        PageTitle(title: original == nil ? "Add VPN" : name.isEmpty ? "VPN" : name,
                  subtitle: original == nil ? "Pick the kind of VPN, then fill in what your admin gave you." : choice.title)
      }

      if original == nil {
        Section("Kind") {
          KindPicker(choice: $choice)
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
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        if original != nil {
          Button("Delete", role: .destructive) { confirmingDelete = true }
        }
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

    case .wireGuard:
      TextField("Interface", text: $wireGuard.interfaceName, prompt: Text("peony0"))
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Configuration")
          Spacer()
          Button("Import .conf…", action: importWireGuard)
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
        Text("Stored in your Keychain. PostUp and PreDown lines aren't allowed, since they'd run as root.")
          .font(.caption)
          .foregroundStyle(Brand.muted)
      }

    case .netBird:
      TextField("Management URL", text: $netBird.managementURL, prompt: Text("Leave empty for NetBird Cloud"))
      Text("The first time, NetBird opens your browser to sign in.")
        .foregroundStyle(Brand.muted)
    }
  }

  private var passwordPrompt: String {
    hasSavedSecret ? "Saved in Keychain. Type to replace." : "Required"
  }

  private func importWireGuard() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [UTType(filenameExtension: "conf") ?? .plainText, .plainText]
    guard panel.runModal() == .OK, let url = panel.url, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
    secret = text
    if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
  }

  private func save() {
    do {
      let profile = try buildProfile()
      model.store.save(profile, secret: secret.isEmpty ? nil : secret)
      model.settingsSelection = .profile(profile.id)
      error = nil
    } catch let failure as Validation.Failure {
      error = failure.description
    } catch let problem as WireGuardConfig.Problem {
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
    case .wireGuard:
      var settings = wireGuard
      settings.interfaceName = try Validation.interfaceName(settings.interfaceName)
      if !secret.isEmpty || !hasSavedSecret { secret = try WireGuardConfig.validate(secret) }
      kind = .wireGuard(settings)
    case .netBird:
      var settings = netBird
      if !settings.managementURL.isEmpty { settings.managementURL = try Validation.server(settings.managementURL, field: "Management URL") }
      kind = .netBird(settings)
    }
    let hosts = destinations.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" }).map(String.init)
    for host in hosts where Probe.Target(host) == nil {
      throw Validation.Failure.invalid(field: "Reachable", reason: "\(host) isn't host or host:port")
    }
    return Profile(id: original?.id ?? UUID(), name: trimmedName, kind: kind, destinations: hosts)
  }
}

private struct KindPicker: View {
  @Binding var choice: KindChoice

  var body: some View {
    HStack(spacing: 8) {
      ForEach(KindChoice.allCases) { kind in
        Button { choice = kind } label: {
          VStack(spacing: 6) {
            Image(systemName: kind.symbol)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(choice == kind ? Color.white : Brand.ink.opacity(0.7))
              .frame(width: 34, height: 34)
              .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(choice == kind ? AnyShapeStyle(Brand.rose) : AnyShapeStyle(Brand.hairline)))
            Text(kind.title)
              .font(.callout)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(choice == kind ? Brand.surface : Brand.chip))
          .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(choice == kind ? Brand.rose.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
      }
    }
  }
}
