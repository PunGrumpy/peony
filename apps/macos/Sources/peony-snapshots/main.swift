// Renders every panel state, in light and dark, so design changes can be reviewed
// without launching the app or connecting anything.
//
//   peony-snapshots panels <dir>   every panel state, light and dark
//   peony-snapshots icon <dir>     AppIcon.iconset and a 1024px preview
import AppKit
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

// Settings pane headers. The window itself needs the app's model, so only its own pieces render here.
let headers = HStack(alignment: .top, spacing: 0) {
  SettingsHeader(symbol: "gearshape.fill", tint: Brand.muted, title: "General",
                 subtitle: "Peony keeps one VPN on at a time, so routes and DNS never fight.")
  SettingsHeader(symbol: "lock.shield.fill", tint: Brand.rose, title: "Work", subtitle: "FortiGate")
  SettingsHeader(symbol: "plus", tint: Brand.ink, glyph: Brand.paper, title: "Add VPN",
                 subtitle: "Pick the kind of VPN, then fill in what your admin gave you.")
}
.frame(width: 960)
.padding(20)
.background(Brand.paper)

for dark in [false, true] {
  render(headers, dark: dark, to: output.appending(path: "settings-headers-\(dark ? "dark" : "light").png"))
}

// The sidebar beside a pane, to check the two halves of the window read as one.
enum Pane: Hashable { case general, work, lab, new }
let settings = HStack(spacing: 0) {
  SettingsSidebar(
    top: [SidebarEntry(id: Pane.general, title: "General", symbol: "gearshape.fill", tint: Brand.muted)],
    sectionTitle: "VPNs",
    items: [
      SidebarEntry(id: .work, title: "Work", symbol: work.symbol, tint: Brand.rose, isLive: true),
      SidebarEntry(id: .lab, title: "Lab", symbol: lab.symbol, tint: Brand.rose),
    ],
    bottom: [SidebarEntry(id: .new, title: "Add VPN", symbol: "plus", tint: Brand.hairline, glyph: Brand.ink)],
    selection: .constant(.work))
  .frame(width: 200, height: 300, alignment: .top)
  .background(Brand.chip)
  Rectangle().fill(Brand.hairline).frame(width: 1)
  SettingsHeader(symbol: work.symbol, tint: Brand.rose, title: "Work", subtitle: "FortiGate")
    .frame(width: 420, height: 300, alignment: .top)
    .padding(.top, 20)
}
.background(Brand.paper)

for dark in [false, true] {
  render(settings, dark: dark, to: output.appending(path: "settings-\(dark ? "dark" : "light").png"))
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
print("Wrote \(states.count * 2 + 6) snapshots to \(output.path)")
