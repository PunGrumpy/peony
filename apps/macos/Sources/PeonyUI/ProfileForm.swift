import PeonyCore
import SwiftUI
import UniformTypeIdentifiers

/// The add and edit VPN form, bound to a `ProfileDraft`. It shows what `ProfileDraft.problems`
/// finds under each field; saving is the caller's, so the same form serves the sheet and the pane.
public struct ProfileForm: View {
  public typealias Field = ProfileDraft.Field

  /// Deleting a saved VPN, named as saved rather than as currently typed.
  public struct Deletion {
    let name: String
    let isConnected: Bool
    let perform: () -> Void

    public init(name: String, isConnected: Bool, perform: @escaping () -> Void) {
      self.name = name
      self.isConnected = isConnected
      self.perform = perform
    }
  }

  @Binding var draft: ProfileDraft
  let isNew: Bool
  /// Show every problem at once. Off while adding, where a field's problem waits until you leave it.
  let revealsAllProblems: Bool
  let missingTool: (name: String, install: String)?
  let saveError: String?
  let installTool: () -> Void
  let deletion: Deletion?

  @FocusState private var focus: Field?
  @State private var touched: Set<Field> = []
  @State private var showsAdvanced: Bool
  @State private var importing = false
  @State private var importError: String?
  @State private var confirmingDelete = false

  public init(
    draft: Binding<ProfileDraft>, isNew: Bool, revealsAllProblems: Bool,
    missingTool: (name: String, install: String)?, saveError: String? = nil, installTool: @escaping () -> Void = {},
    deletion: Deletion? = nil
  ) {
    _draft = draft
    self.isNew = isNew
    self.revealsAllProblems = revealsAllProblems
    self.missingTool = missingTool
    self.saveError = saveError
    self.installTool = installTool
    self.deletion = deletion
    _showsAdvanced = State(initialValue: draft.wrappedValue.hasAdvancedValues)
  }

  public var body: some View {
    let problems = draft.problems.filter { revealsAllProblems || touched.contains($0.key) }
    Form {
      if let saveError {
        Section { ProblemCaption(saveError, font: .body) }
      }

      Section {
        if isNew {
          Picker("VPN type", selection: $draft.type) {
            ForEach(VPNType.allCases) { type in
              Label(type.title, systemImage: type.symbol).tag(type)
            }
          }
        }
        row("Name", .name, problems) {
          TextField("Name", text: $draft.name, prompt: Text("Work VPN"))
        }
      } footer: {
        if isNew { FormFooter("Pick the kind of VPN, then fill in what your admin gave you.") }
      }

      Section {
        if let missingTool {
          LabeledContent {
            Button("Install with Homebrew…", action: installTool)
          } label: {
            Label("\(missingTool.name) isn't installed", systemImage: "exclamationmark.triangle")
          }
        }
        connectionFields(problems)
      } header: {
        Text("Connection")
      } footer: {
        connectionFooter(problems)
      }

      if draft.type == .openVPN || draft.type == .wireGuard {
        configSection(problems)
      }

      Section {
        row("Check these hosts", .hosts, problems) {
          TextField("Check these hosts", text: $draft.hosts, prompt: Text("gitlab.example.com, 10.0.0.5:22"))
        }
      } header: {
        Text("Reachable")
      } footer: {
        FormFooter("Once connected, Peony checks these hosts so you know your services are actually reachable. Port 443 unless you add one.")
      }

      if deletion != nil {
        Section {
          Button("Delete VPN…", role: .destructive) { confirmingDelete = true }
        }
      }
    }
    .formStyle(.grouped)
    .confirmationDialog("Delete “\(deletion?.name ?? "")”?", isPresented: $confirmingDelete) {
      Button("Delete", role: .destructive) { deletion?.perform() }
    } message: {
      Text(deletion?.isConnected == true
        ? "It's connected now, so Peony turns it off first. Peony also removes its saved password from the Keychain."
        : "Peony also removes its saved password from the Keychain.")
    }
    .onChange(of: focus) { left, _ in
      if let left { touched.insert(left) }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: configTypes) { result in
      switch result {
      case .success(let url): load(url)
      case .failure(let error): importError = error.localizedDescription
      }
    }
  }

  // MARK: Fields

  @ViewBuilder private func connectionFields(_ problems: [Field: String]) -> some View {
    switch draft.type {
    case .forti:
      row("Server", .server, problems) {
        TextField("Server", text: $draft.forti.host, prompt: Text("vpn.example.com"))
      }
      row("Port", .port, problems) {
        TextField("Port", value: $draft.forti.port, format: .number.grouping(.never), prompt: Text("443"))
      }
      Picker("Sign in", selection: $draft.fortiLogin) {
        ForEach(ProfileDraft.FortiLogin.allCases) { Text($0.title).tag($0) }
      }
      if draft.fortiLogin == .password {
        row("Username", .username, problems) {
          TextField("Username", text: $draft.fortiUsername)
        }
        row("Password", .password, problems) {
          SecureField("Password", text: $draft.secret, prompt: Text(passwordPrompt(saved: draft.hasSavedSecret)))
        }
      }
      advanced(problems, [.trustedCert]) {
        row("Trusted certificate", .trustedCert, problems) {
          TextField("Trusted certificate", text: optional(\.forti.trustedCert), prompt: Text("Optional"))
        }
        row("Realm", nil, problems) {
          TextField("Realm", text: optional(\.forti.realm), prompt: Text("Optional"))
        }
      }

    case .openConnect:
      Picker("Protocol", selection: $draft.openConnect.serverProtocol) {
        ForEach(Profile.OpenConnect.ServerProtocol.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      row("Server", .server, problems) {
        TextField("Server", text: $draft.openConnect.server, prompt: Text("vpn.example.com"))
      }
      row("Username", .username, problems) {
        TextField("Username", text: $draft.openConnect.username)
      }
      row("Password", .password, problems) {
        SecureField("Password", text: $draft.secret, prompt: Text(passwordPrompt(saved: draft.hasSavedSecret)))
      }
      advanced(problems, [.serverCert]) {
        row("Server certificate", .serverCert, problems) {
          TextField("Server certificate", text: optional(\.openConnect.serverCert), prompt: Text("Optional"))
        }
      }

    case .openVPN:
      row("Username", .username, problems) {
        TextField("Username", text: $draft.openVPN.username, prompt: Text("Optional"))
      }
      row("Password", .password, problems) {
        SecureField("Password", text: $draft.openVPNPassword, prompt: Text(
          draft.openVPN.username.isEmpty ? "Not needed without a username" : passwordPrompt(saved: draft.hasSavedOpenVPNPassword)))
      }
      .disabled(draft.openVPN.username.isEmpty)

    case .wireGuard:
      row("Interface", .interface, problems) {
        TextField("Interface", text: $draft.wireGuard.interfaceName, prompt: Text("peony0"))
      }

    case .netBird:
      row("Management URL", .managementURL, problems) {
        TextField("Management URL", text: $draft.netBird.managementURL, prompt: Text("Optional"))
      }

    case .tailscale:
      LabeledContent("Account", value: "From the Tailscale app")
    }
  }

  /// Hints that used to crowd the placeholders. The advanced ones show while Advanced is open.
  @ViewBuilder private func connectionFooter(_ problems: [Field: String]) -> some View {
    let hints: [String] = switch draft.type {
    case .forti: [
      draft.fortiLogin == .browser ? "Peony opens the sign-in page when you connect." : nil,
      isAdvancedOpen(problems, [.trustedCert]) ? "A trusted certificate is the SHA-256 fingerprint of a self-signed gateway." : nil,
    ].compactMap { $0 }
    case .openConnect: [
      "The server can include a group, like https://vpn.example.com/group.",
      isAdvancedOpen(problems, [.serverCert]) ? "A server certificate is a pin-sha256:… value or a hex fingerprint." : nil,
    ].compactMap { $0 }
    case .openVPN: ["Leave the username empty if you only sign in with a certificate."]
    case .wireGuard: []
    case .netBird: ["Leave the management URL empty for NetBird Cloud. The first time, NetBird opens your browser to sign in."]
    case .tailscale: ["Sign in from the Tailscale app first. Peony turns it on and off; accounts and exit nodes stay in Tailscale."]
    }
    if !hints.isEmpty { FormFooter(hints.joined(separator: " ")) }
  }

  /// A pasted, dropped or imported config, saved to the Keychain whole.
  private func configSection(_ problems: [Field: String]) -> some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        TextEditor(text: $draft.secret)
          .font(.system(.callout, design: .monospaced))
          .frame(minHeight: 140)
          .scrollContentBackground(.hidden)
          .padding(4)
          .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.separator))
          .focused($focus, equals: .config)
          .accessibilityLabel("Configuration")
          .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            load(url)
            return true
          }
        if let problem = importError ?? problems[.config] {
          ProblemCaption(problem)
            .accessibilityLabel("Configuration: \(problem)")
        }
      }
      .onChange(of: draft.secret) { importError = nil }
    } header: {
      HStack {
        Text("Configuration")
        Spacer()
        Button("Import…") { importing = true }
          .help("Choose a .\(draft.type == .openVPN ? "ovpn" : "conf") file")
      }
    } footer: {
      FormFooter {
        if draft.hasSavedSecret && draft.secret.isEmpty {
          Text("A configuration is saved in your Keychain. Paste, drop or import a new one to replace it.")
        }
        Text(draft.type == .openVPN
          ? "Stored in your Keychain. OpenVPN runs as root, so scripts, plugins and paths to other files aren't allowed. Keep certificates and keys inline."
          : "Stored in your Keychain. PostUp and PreDown lines aren't allowed, since they'd run as root.")
      }
    }
  }

  /// Optional fields behind a disclosure, open when they hold something or have a problem.
  private func advanced(_ problems: [Field: String], _ fields: Set<Field>, @ViewBuilder content: () -> some View) -> some View {
    let isOpen = isAdvancedOpen(problems, fields)
    let content = content()
    return DisclosureGroup("Advanced", isExpanded: Binding(get: { isOpen }, set: { showsAdvanced = $0 })) {
      content
    }
  }

  /// A problem in a hidden field would disable Save with no reason in sight, so it opens Advanced.
  private func isAdvancedOpen(_ problems: [Field: String], _ fields: Set<Field>) -> Bool {
    showsAdvanced || !fields.isDisjoint(with: problems.keys)
  }

  /// A field with its problem under it, as an icon and text, never colour alone.
  private func row(_ title: String, _ field: Field?, _ problems: [Field: String], @ViewBuilder control: () -> some View) -> some View {
    let problem = field.flatMap { problems[$0] }
    return LabeledContent {
      VStack(alignment: .trailing, spacing: 4) {
        control()
          .labelsHidden()
          .focused($focus, equals: field)
          .accessibilityHint(problem ?? "")
        if let problem {
          ProblemCaption(problem)
            .accessibilityLabel("\(title): \(problem)")
        }
      }
    } label: {
      Text(title)
    }
  }

  // MARK: Helpers

  private func passwordPrompt(saved: Bool) -> String {
    saved ? "Saved in Keychain. Type to replace." : "Required"
  }

  private func optional(_ keyPath: WritableKeyPath<ProfileDraft, String?>) -> Binding<String> {
    Binding(get: { draft[keyPath: keyPath] ?? "" }, set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
  }

  private var configTypes: [UTType] {
    let extensions = draft.type == .openVPN ? ["ovpn", "conf"] : ["conf"]
    return extensions.compactMap { UTType(filenameExtension: $0) } + [.plainText]
  }

  private func load(_ url: URL) {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
      importError = "Couldn't read “\(url.lastPathComponent)” as text."
      return
    }
    draft.secret = text
    touched.insert(.config)
    if draft.name.isEmpty { draft.name = url.deletingPathExtension().lastPathComponent }
    importError = nil
  }
}

/// A problem shown next to what caused it: an icon and text, so it reads without its colour.
public struct ProblemCaption: View {
  let text: String
  let font: Font

  public init(_ text: String, font: Font = .caption) {
    self.text = text
    self.font = font
  }

  public var body: some View {
    Label(text, systemImage: "exclamationmark.circle.fill")
      .font(font)
      .foregroundStyle(.red)
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
      .textSelection(.enabled)
  }
}

/// A section's explanation, in the small secondary text System Settings uses under its groups.
public struct FormFooter<Content: View>: View {
  let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) { content }
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.leading)
      // Lines up with the section headers, which the form insets from the group's edge.
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension FormFooter where Content == Text {
  public init(_ text: String) {
    content = Text(text)
  }
}

extension VPNType {
  /// Outline symbols, after Mail's and Finder's sidebars.
  public var symbol: String {
    switch self {
    case .forti: "lock.shield"
    case .openConnect: "network.badge.shield.half.filled"
    case .openVPN: "key.horizontal"
    case .wireGuard: "bolt.horizontal"
    case .netBird: "point.3.connected.trianglepath.dotted"
    case .tailscale: "circle.grid.3x3"
    }
  }
}
