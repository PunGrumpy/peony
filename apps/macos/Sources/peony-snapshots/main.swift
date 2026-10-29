// Renders every panel state and Settings pane, in light and dark, so design changes can be
// reviewed without launching the app or connecting anything.
//
//   peony-snapshots panels <dir>   every panel state and Settings pane, light and dark
//   peony-snapshots icon <dir>     AppIcon.iconset and a 1024px preview
import AppKit
import PeonyCore
import PeonyUI
import SwiftUI

let arguments = Array(CommandLine.arguments.dropFirst())
let mode = arguments.first ?? "panels"
let output = URL(filePath: arguments.dropFirst().first ?? "Design/snapshots")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// The app icon: glossy petals on plum-black, with a rose inner ring.
struct AppIconView: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 185, style: .continuous)
        .fill(RadialGradient(
          colors: [Color(red: 0.25, green: 0.11, blue: 0.16), Brand.ink],
          center: UnitPoint(x: 0.5, y: 0.15), startRadius: 0, endRadius: 900))
        .overlay(
          RoundedRectangle(cornerRadius: 185, style: .continuous)
            .strokeBorder(.white.opacity(0.08), lineWidth: 3))
        .frame(width: 824, height: 824)
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

      ZStack {
        LinearGradient(colors: [.white, Color(red: 0.86, green: 0.80, blue: 0.82)], startPoint: .top, endPoint: .bottom)
          .mask(PeonyMark(color: .white))
      }
      .frame(width: 560, height: 560)
      .shadow(color: .black.opacity(0.55), radius: 18, y: 14)
    }
    .frame(width: 1024, height: 1024)
  }
}



let work = Route(name: "Work", kind: .forti, endpoint: "vpn.acme.co")
let lab = Route(name: "Lab", kind: .netBird, endpoint: "netbird.acme.co")
let client = Route(name: "Client", kind: .openConnect, endpoint: "connect.client.com")
let home = Route(name: "Home", kind: .wireGuard, endpoint: "peony0")
let routes = [work, lab, client, home]
let since = Date.now.addingTimeInterval(-754)

let states: [(String, PanelState)] = [
  ("welcome", PanelState()),
  ("off", PanelState(routes: routes)),
  ("connecting", PanelState(routes: routes, activeRouteID: work.id, connection: .connecting)),
  ("live", PanelState(
    routes: routes, activeRouteID: work.id, connection: .on(address: "10.122.0.8"), connectedSince: since,
    destinations: [
      DestinationStatus(host: "gitlab.acme.co", reachability: .reachable(milliseconds: 23)),
      DestinationStatus(host: "10.11.219.9", reachability: .reachable(milliseconds: 31)),
      DestinationStatus(host: "grafana.acme.co", reachability: .unreachable),
    ], opensAtLogin: true)),
  ("failed-certificate", PanelState(
    routes: routes, activeRouteID: work.id,
    connection: .failed(TunnelFailure(
      message: "The server's certificate isn't trusted. If your admin confirms it, Peony can trust it for this VPN.",
      fix: .trustCertificate(pin: "a1b2c3d4…"))))),
  ("failed-helper", PanelState(
    routes: routes, activeRouteID: client.id,
    connection: .failed(TunnelFailure(
      message: "Peony needs a one-time admin approval to set up routes and DNS for VPNs.", fix: .installHelper)))),
]

@MainActor func render(_ view: some View, dark: Bool, to url: URL) {
  let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
  appearance.performAsCurrentDrawingAppearance {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, dark ? .dark : .light))
    renderer.scale = 2
    guard let image = renderer.cgImage else { fatalError("Couldn't render \(url.lastPathComponent)") }
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! data.write(to: url)
  }
}

func writePNG(_ view: some View, scale: CGFloat, to url: URL) {
  let renderer = ImageRenderer(content: view)
  renderer.scale = scale
  guard let image = renderer.cgImage else { fatalError("Couldn't render \(url.lastPathComponent)") }
  try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}

if mode == "icon" {
  let iconset = output.appending(path: "AppIcon.iconset")
  try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
  for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
      let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
      writePNG(AppIconView(), scale: CGFloat(size * scale) / 1024, to: iconset.appending(path: name))
    }
  }
  writePNG(AppIconView(), scale: 1, to: output.appending(path: "AppIcon-1024.png"))
  // The mark at the sizes it lives at, and its menu bar states.
  let sheet = HStack(alignment: .center, spacing: 28) {
    PeonyMark(color: Brand.ink).frame(width: 96, height: 96)
    PeonyMark(color: Brand.ink).frame(width: 32, height: 32)
    PeonyMark(color: Brand.ink).frame(width: 16, height: 16)
    ForEach(0...PeonyMark.shapeCount, id: \.self) { PeonyMark(filled: $0, color: .black).frame(width: 16, height: 16) }
    HStack(spacing: 7) {
      PeonyMark(color: Brand.ink).frame(width: 22, height: 22)
      Text("Peony").font(Typeface.display(22)).tracking(Typeface.displayTracking(22)).foregroundStyle(Brand.ink)
    }
  }
  .padding(24)
  .background(Color(white: 0.97))
  writePNG(sheet, scale: 3, to: output.appending(path: "mark-sheet.png"))
  print("Wrote \(iconset.path)")
  exit(0)
}

for (name, state) in states {
  for dark in [false, true] {
    let file = output.appending(path: "panel-\(name)-\(dark ? "dark" : "light").png")
    render(PanelView(state: state, actions: PanelActions()), dark: dark, to: file)
  }
}

// The menu bar item in each state, on a light and a dark bar.
let bar = HStack(spacing: 18) {
  MenuBarLabel(filledPetals: 0, title: nil)
  HStack(spacing: 4) { MenuBarLabel(filledPetals: 1, title: "Work…") }
  HStack(spacing: 4) { MenuBarLabel(filledPetals: PeonyMark.shapeCount, title: "Work") }
}
.font(.system(size: 13))
.padding(.horizontal, 14)
.padding(.vertical, 5)

for dark in [false, true] {
  render(bar.foregroundStyle(dark ? .white : .black).background(dark ? Color(white: 0.16) : Color(white: 0.93)),
         dark: dark, to: output.appending(path: "menubar-\(dark ? "dark" : "light").png"))
}
// Settings panes. Forms are AppKit controls, which ImageRenderer can't draw, so these go
// through a window that never comes on screen.
@MainActor func renderInWindow(_ view: some View, size: CGSize, dark: Bool, to url: URL) {
  let host = NSHostingView(rootView: view)
  let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
  window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  window.contentView = host
  // A turn of the run loop lets the form lay out and its fields load their values.
  RunLoop.main.run(until: .now + 0.3)
  host.layoutSubtreeIfNeeded()
  guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("Couldn't render \(url.lastPathComponent)") }
  host.cacheDisplay(in: host.bounds, to: bitmap)
  try! bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

_ = NSApplication.shared
let cli = "/Applications/Peony.app/Contents/Helpers/peony"
let office = Profile(
  name: "Office",
  kind: .forti(.init(host: "vpn.acme.co", login: .password(username: "alex"))),
  destinations: ["gitlab.acme.co", "10.11.219.9:22"])
var broken = ProfileDraft(office, hasSavedSecret: true)
broken.forti.host = "vpn acme co"
broken.forti.port = 0
broken.fortiUsername = ""
broken.forti.trustedCert = "a1b2c3"
broken.hosts = "gitlab.acme.co, :22"
var newForti = ProfileDraft()
newForti.name = "Office"
newForti.forti.host = "https://vpn.acme.co"
var newWireGuard = ProfileDraft()
newWireGuard.type = .wireGuard
newWireGuard.name = "Home"
newWireGuard.secret = "[Interface]\nPrivateKey = …\nPostUp = ./route.sh\n\n[Peer]\nPublicKey = …\n"
let deletion = ProfileForm.Deletion(name: "Office", isConnected: false, perform: {})

let panes: [(String, CGSize, AnyView)] = [
  ("general", CGSize(width: 540, height: 300), AnyView(GeneralPane(helper: .installed, opensAtLogin: true))),
  ("general-notices", CGSize(width: 540, height: 340), AnyView(GeneralPane(
    helper: .missing, helperNotice: "The administrator didn't approve the helper.", opensAtLogin: false,
    loginNotice: "macOS didn't allow opening at login. Move Peony to Applications and try again."))),
  ("agents", CGSize(width: 540, height: 380), AnyView(AgentsPane(
    isEnabled: .constant(true),
    rows: [
      .init(agent: .claudeCode, isInstalled: true, install: AgentSetup.install(.claudeCode, cli: cli)),
      .init(agent: .codex, isInstalled: false, install: AgentSetup.install(.codex, cli: cli)),
      .init(agent: .cursor, isInstalled: true, install: AgentSetup.install(.cursor, cli: cli)),
    ]))),
  ("edit", CGSize(width: 540, height: 640), AnyView(ProfileForm(
    draft: .constant(ProfileDraft(office, hasSavedSecret: true)), isNew: false, revealsAllProblems: true,
    missingTool: nil, deletion: deletion))),
  ("edit-errors", CGSize(width: 540, height: 820), AnyView(ProfileForm(
    draft: .constant(broken), isNew: false, revealsAllProblems: true, missingTool: nil, deletion: deletion))),
  ("add", CGSize(width: 500, height: 480), AnyView(AddVPNSheet(draft: .constant(ProfileDraft()), missingTool: nil))),
  ("add-errors", CGSize(width: 500, height: 480), AnyView(AddVPNSheet(
    draft: .constant(newForti), revealsAllProblems: true, missingTool: VPNType.forti.tool))),
  // The sheet's form on its own, tall enough to show the configuration editor.
  ("add-config-errors", CGSize(width: 500, height: 760), AnyView(ProfileForm(
    draft: .constant(newWireGuard), isNew: true, revealsAllProblems: true, missingTool: VPNType.wireGuard.tool))),
]
for (name, size, view) in panes {
  for dark in [false, true] {
    renderInWindow(view, size: size, dark: dark, to: output.appending(path: "settings-\(name)-\(dark ? "dark" : "light").png"))
  }
}
print("Wrote \((states.count + panes.count) * 2 + 2) snapshots to \(output.path)")
