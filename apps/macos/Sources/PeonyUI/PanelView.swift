import SwiftUI

/// The menu bar panel: what's happening (the hero), where to go (routes),
/// and whether it worked (destinations).
public struct PanelView: View {
  let state: PanelState
  let actions: PanelActions
  /// The active route's raised background, shared so it slides from one row to the next.
  @Namespace private var lift

  public init(state: PanelState, actions: PanelActions) {
    self.state = state
    self.actions = actions
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Wordmark(connection: state.connection)
        Spacer()
        IconButton(symbol: "gearshape", help: "Settings", action: actions.openSettings)
          .keyboardShortcut(",")
      }
      .padding(.bottom, 12)

      if state.routes.isEmpty {
        Welcome(addVPN: actions.addVPN)
      } else {
        Hero(state: state, actions: actions)
          .padding(.bottom, 14)

        SectionLabel(text: "Routes")
          .padding(.bottom, 6)
        Well {
          ForEach(Array(state.routes.enumerated()), id: \.element.id) { index, route in
            RouteRow(route: route, state: state.state(of: route), shortcut: index < 9 ? index + 1 : nil,
                     locked: state.isBusy, lift: lift, connect: { actions.connect(route.id) })
          }
          WellDivider()
          AddRow(action: actions.addVPN)
        }

        if state.isLive, !state.destinations.isEmpty {
          // The panel grows to fit at once, so only a fade is left to animate.
          VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Reachable")
            DestinationList(destinations: state.destinations)
          }
          .padding(.top, 14)
          .transition(.opacity.animation(.easeOut(duration: 0.2)))
        }
      }

      Footer(opensAtLogin: state.opensAtLogin, actions: actions)
        .padding(.top, 12)
    }
    .padding(14)
    .frame(width: 320, alignment: .leading)
    // A floating layer gets the system material; paper tints it toward Peony's ink-on-paper.
    .background(Brand.paper.opacity(0.72))
    .background(.regularMaterial)
    .foregroundStyle(Brand.ink)
  }
}

// MARK: - Wordmark

/// Symbol plus serif name. The mark follows the menu bar's: the inner ring blooms first,
/// and the outer ring breathes until the tunnel is up.
private struct Wordmark: View {
  let connection: TunnelState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 7) {
      mark
        .frame(width: 17, height: 17)
      Text("Peony")
        .font(Typeface.display(17))
        .tracking(Typeface.displayTracking(17))
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var mark: some View {
    switch connection {
    case .on:
      PeonyMark(color: Brand.rose)
    case .connecting where !reduceMotion:
      // About once a second: fast enough to read as work, too slow to nag.
      PhaseAnimator([0.35, 0.8]) { faint in
        PeonyMark(filled: 1, color: Brand.ink, innerColor: Brand.rose, faint: faint)
      } animation: { _ in .easeInOut(duration: 0.8) }
    case .connecting:
      PeonyMark(filled: 1, color: Brand.ink, innerColor: Brand.rose)
    case .off, .disconnecting, .failed:
      PeonyMark(color: Brand.ink)
    }
  }
}


// MARK: - Welcome

/// First run: one clear thing to do.
private struct Welcome: View {
  let addVPN: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Add your first VPN")
        .font(Typeface.display(21))
        .tracking(Typeface.displayTracking(21))
      Text("FortiGate, AnyConnect, GlobalProtect, OpenVPN, WireGuard, NetBird or Tailscale. Peony keeps one on at a time and tells you when your servers are reachable.")
        .font(Typeface.body)
        .foregroundStyle(Brand.muted)
        .fixedSize(horizontal: false, vertical: true)
      PillButton(title: "Add VPN", style: .primary, action: addVPN)
        .keyboardShortcut(.defaultAction)
        .padding(.top, 4)
    }
  }
}

// MARK: - Hero

private struct Hero: View {
  let state: PanelState
  let actions: PanelActions
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    // Old and new share one spot, so a state change reads as the same hero changing its mind.
    ZStack(alignment: .topLeading) {
      VStack(alignment: .leading, spacing: 5) {
        Text(headline)
          .font(Typeface.display(21))
          .tracking(Typeface.displayTracking(21))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        detail
      }
      .id(headline)
      .transition(Motion.replace(reduceMotion: reduceMotion))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var name: String { state.activeRoute?.name ?? "VPN" }

  private var headline: String {
    switch state.connection {
    case .connecting: "Connecting to \(name)"
    case .disconnecting: "Disconnecting"
    case .on: "Connected to \(name)"
    case .failed: "Couldn't connect to \(name)"
    case .off: "Not connected"
    }
  }

  @ViewBuilder private var detail: some View {
    switch state.connection {
    case .on(let address):
      HStack(spacing: 10) {
        HStack(spacing: 6) {
          LiveDot()
          Text(address.isEmpty ? "up" : address)
            .textSelection(.enabled)
          if let since = state.connectedSince {
            Text("·").foregroundStyle(Brand.muted)
            Text(timerInterval: since...Date.distantFuture, countsDown: false)
              .foregroundStyle(Brand.muted)
          }
        }
        .font(Typeface.mono)
        .monospacedDigit()
        Spacer()
        PillButton(title: "Disconnect", style: .quiet, action: actions.disconnect)
          .keyboardShortcut("0")
      }
    case .failed(let failure):
      VStack(alignment: .leading, spacing: 10) {
        Text(failure.message)
          .font(Typeface.body)
          .foregroundStyle(Brand.muted)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) {
          if let fix = failure.fix {
            PillButton(title: fix.title, style: .primary) { actions.fix(fix) }
              .keyboardShortcut(.defaultAction)
            PillButton(title: "Try again", style: .quiet, action: actions.retry)
          } else {
            PillButton(title: "Try again", style: .primary, action: actions.retry)
              .keyboardShortcut(.defaultAction)
          }
        }
      }
    case .connecting:
      HStack(spacing: 10) {
        Text("Signing in and setting up routes.")
          .font(Typeface.body)
          .foregroundStyle(Brand.muted)
        Spacer()
        PillButton(title: "Cancel", style: .quiet, action: actions.disconnect)
          .keyboardShortcut(.cancelAction)
      }
    case .disconnecting:
      Text("Removing routes and DNS.")
        .font(Typeface.body)
        .foregroundStyle(Brand.muted)
    case .off:
      Text("Pick a route. Only one runs at a time.")
        .font(Typeface.body)
        .foregroundStyle(Brand.muted)
    }
  }
}

private struct LiveDot: View {
  var body: some View {
    Circle()
      .fill(Brand.rose)
      .frame(width: 7, height: 7)
      .accessibilityHidden(true)
  }
}

// MARK: - Routes

private struct RouteRow: View {
  let route: Route
  let state: TunnelState
  let shortcut: Int?
  let locked: Bool
  let lift: Namespace.ID
  let connect: () -> Void

  @State private var hovering = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button(action: connect) {
      HStack(spacing: 10) {
        IconTile(symbol: route.symbol, size: 26,
                 fill: isActive ? Brand.rose : Brand.hairline,
                 glyph: isActive ? .white : Brand.ink.opacity(0.7))

        VStack(alignment: .leading, spacing: 1) {
          Text(route.name)
            .font(Typeface.bodyEmphasis)
            .lineLimit(1)
          Text(route.endpoint)
            .font(Typeface.mono)
            .foregroundStyle(Brand.muted)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Spacer(minLength: 8)
        trailing
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background {
        if isActive {
          WellRow.shape
            .fill(Brand.surface)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .overlay(WellRow.shape.strokeBorder(Brand.hairline, lineWidth: 1))
            .matchedGeometryEffect(id: "lift", in: lift)
        } else {
          // Hover is seen dozens of times a day, so it's the faintest change that still reads.
          WellRow.shape
            .fill(Brand.ink.opacity(hovering ? 0.04 : 0))
            .animation(Motion.hover, value: hovering)
        }
      }
      .animation(reduceMotion ? nil : Motion.standard, value: isActive)
    }
    .buttonStyle(PressableStyle())
    .disabled(locked || state.address != nil)
    .onHover { hovering = $0 }
    .modifier(ShortcutModifier(number: shortcut))
    .accessibilityLabel("\(route.name), \(accessibilityStatus)")
    .accessibilityHint(state.address == nil ? "Connects to \(route.name)" : "")
  }

  private var isActive: Bool { state.wantsOn }

  private var trailing: some View {
    ZStack(alignment: .trailing) {
      tag.id(tagKey).transition(Motion.replace(reduceMotion: reduceMotion))
    }
  }

  private var tagKey: String {
    switch state {
    case .on: "on"
    case .connecting: "connecting"
    case .disconnecting: "disconnecting"
    case .failed: "failed"
    case .off: "off"
    }
  }

  @ViewBuilder private var tag: some View {
    switch state {
    case .on: Tag(text: "Live", color: Brand.rose)
    case .connecting: Tag(text: "Joining", color: Brand.muted)
    case .disconnecting: Tag(text: "Leaving", color: Brand.muted)
    case .failed: Tag(text: "Failed", color: Brand.warning)
    case .off:
      if let shortcut {
        Text("⌘\(shortcut)").font(Typeface.mono).foregroundStyle(Brand.muted.opacity(0.7))
      }
    }
  }

  private var accessibilityStatus: String {
    switch state {
    case .on(let address): "connected, \(address)"
    case .connecting: "connecting"
    case .disconnecting: "disconnecting"
    case .failed: "failed"
    case .off: "off"
    }
  }
}

private struct ShortcutModifier: ViewModifier {
  let number: Int?

  func body(content: Content) -> some View {
    if let number {
      content.keyboardShortcut(KeyEquivalent(Character(String(number))))
    } else {
      content
    }
  }
}

private struct Tag: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text.uppercased())
      .font(Typeface.label)
      .tracking(0.8)
      .foregroundStyle(color)
  }
}

private struct AddRow: View {
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "plus")
          .font(.system(size: 11, weight: .semibold))
          .frame(width: 26, height: 20)
        Text("Add VPN")
          .font(Typeface.body)
        Spacer()
        Text("⌘N").font(Typeface.mono).foregroundStyle(Brand.muted.opacity(0.7))
      }
      .foregroundStyle(hovering ? Brand.ink : Brand.muted)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(WellRow.shape.fill(Brand.ink.opacity(hovering ? 0.04 : 0)))
      .animation(Motion.hover, value: hovering)
    }
    .buttonStyle(PressableStyle())
    .onHover { hovering = $0 }
    .keyboardShortcut("n")
  }
}

// MARK: - Destinations

private struct DestinationList: View {
  let destinations: [DestinationStatus]

  var body: some View {
    Well {
      ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
        if index > 0 { WellDivider() }
        HStack {
          Text(destination.host)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
          reachability(destination.reachability)
            .monospacedDigit()
        }
        .font(Typeface.mono)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
      }
    }
  }

  @ViewBuilder private func reachability(_ value: DestinationStatus.Reachability) -> some View {
    switch value {
    case .checking:
      Text("checking…").foregroundStyle(Brand.muted)
    case .reachable(let ms):
      HStack(spacing: 6) {
        LiveDot()
        Text("\(ms) ms")
      }
    case .unreachable:
      Text("unreachable").foregroundStyle(Brand.warning)
    }
  }
}

// MARK: - Footer

private struct Footer: View {
  let opensAtLogin: Bool
  let actions: PanelActions

  var body: some View {
    HStack(spacing: 14) {
      Button { actions.setOpensAtLogin(!opensAtLogin) } label: {
        HStack(spacing: 7) {
          MiniSwitch(isOn: opensAtLogin)
          Text("Open at login")
        }
      }
      .accessibilityAddTraits(.isToggle)
      .accessibilityValue(opensAtLogin ? "On" : "Off")
      Spacer()
      Button("Log", action: actions.showLog)
        .keyboardShortcut("l")
      Button("Quit", action: actions.quit)
        .keyboardShortcut("q")
    }
    .buttonStyle(PressableStyle())
    .font(Typeface.caption)
    .foregroundStyle(Brand.muted)
    .padding(.top, 12)
    // The rule runs edge to edge, so the footer reads as the panel's floor, not another section.
    .overlay(alignment: .top) {
      Rectangle().fill(Brand.hairline).frame(height: 1).padding(.horizontal, -14)
    }
  }
}

/// A switch drawn in SwiftUI rather than AppKit, so it takes Peony's rose and renders in snapshots.
private struct MiniSwitch: View {
  let isOn: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Capsule()
      .fill(isOn ? AnyShapeStyle(Brand.rose) : AnyShapeStyle(Brand.ink.opacity(0.16)))
      .frame(width: 22, height: 13)
      .overlay(alignment: isOn ? .trailing : .leading) {
        Circle()
          .fill(.white)
          .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
          .padding(1.5)
      }
      .animation(reduceMotion ? nil : Motion.standard, value: isOn)
      .accessibilityHidden(true)
  }
}

// MARK: - Controls

struct PillButton: View {
  enum Style { case primary, quiet }

  let title: String
  let style: Style
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(Typeface.caption.weight(.medium))
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .foregroundStyle(style == .primary ? Brand.paper : Brand.ink)
        .background(
          Capsule().fill(style == .primary ? AnyShapeStyle(Brand.ink) : AnyShapeStyle(Brand.chip))
        )
    }
    .buttonStyle(PressableStyle())
  }
}

private struct IconButton: View {
  let symbol: String
  let help: String
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 13))
        .foregroundStyle(hovering ? Brand.ink : Brand.muted)
        .frame(width: 24, height: 24)
        .background(Circle().fill(Brand.ink.opacity(hovering ? 0.06 : 0)))
        .animation(Motion.hover, value: hovering)
    }
    .buttonStyle(PressableStyle())
    .onHover { hovering = $0 }
    .help(help)
    .accessibilityLabel(help)
  }
}
