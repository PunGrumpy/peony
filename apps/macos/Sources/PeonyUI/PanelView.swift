import SwiftUI

/// The menu bar panel: what's happening (the hero), where to go (routes),
/// and whether it worked (destinations).
public struct PanelView: View {
  let state: PanelState
  let actions: PanelActions

  public init(state: PanelState, actions: PanelActions) {
    self.state = state
    self.actions = actions
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Wordmark(live: state.isLive)
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
        VStack(spacing: 4) {
          ForEach(Array(state.routes.enumerated()), id: \.element.id) { index, route in
            RouteCard(route: route, state: state.state(of: route), shortcut: index < 9 ? index + 1 : nil,
                      locked: state.isBusy, connect: { actions.connect(route.id) })
          }
          AddCard(action: actions.addVPN)
        }

        if state.isLive, !state.destinations.isEmpty {
          SectionLabel(text: "Reachable")
            .padding(.top, 14)
            .padding(.bottom, 2)
          DestinationList(destinations: state.destinations)
        }
      }

      Footer(opensAtLogin: state.opensAtLogin, actions: actions)
        .padding(.top, 14)
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

/// Symbol plus serif name, like Orchid's wordmark.
private struct Wordmark: View {
  let live: Bool

  var body: some View {
    HStack(spacing: 7) {
      PeonyMark(color: live ? Brand.rose : Brand.ink)
        .frame(width: 17, height: 17)
      Text("Peony")
        .font(Typeface.display(17))
        .tracking(Typeface.displayTracking(17))
    }
    .accessibilityElement(children: .combine)
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
      Text("FortiGate, AnyConnect, GlobalProtect, WireGuard or NetBird. Peony keeps one on at a time and tells you when your servers are reachable.")
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

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(headline)
        .font(Typeface.display(21))
        .tracking(Typeface.displayTracking(21))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      detail
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var name: String { state.activeRoute?.name ?? "VPN" }

  private var headline: String {
    switch state.connection {
    case .connecting: "Connecting to \(name)"
    case .disconnecting: "Disconnecting"
    case .on: "Connected to \(name)"
    case .failed: "Couldn't reach \(name)"
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
          PillButton(title: "Log", style: .quiet, action: actions.showLog)
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

private struct RouteCard: View {
  let route: Route
  let state: TunnelState
  let shortcut: Int?
  let locked: Bool
  let connect: () -> Void

  @State private var hovering = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button(action: connect) {
      HStack(spacing: 10) {
        Image(systemName: route.symbol)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(isActive ? Color.white : Brand.ink.opacity(0.7))
          .frame(width: 26, height: 26)
          .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(isActive ? AnyShapeStyle(Brand.rose) : AnyShapeStyle(Brand.hairline))
          )

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
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(isActive ? Brand.surface : Brand.chip)
          .shadow(color: .black.opacity(isActive ? 0.08 : 0), radius: 10, y: 3)
      )
      .overlay(
        // Hover is seen dozens of times a day, so it's the faintest change that still reads.
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Brand.ink.opacity(hovering && !isActive ? 0.04 : 0))
          .animation(.easeOut(duration: 0.12), value: hovering)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(isActive ? Brand.hairline : .clear, lineWidth: 1)
      )
      .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isActive)
    }
    .buttonStyle(PressableStyle())
    .disabled(locked || state.address != nil)
    .onHover { hovering = $0 }
    .modifier(ShortcutModifier(number: shortcut))
    .accessibilityLabel("\(route.name), \(accessibilityStatus)")
    .accessibilityHint(state.address == nil ? "Connects to \(route.name)" : "")
  }

  private var isActive: Bool { state.wantsOn }

  @ViewBuilder private var trailing: some View {
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

private struct AddCard: View {
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "plus")
          .font(.system(size: 11, weight: .semibold))
          .frame(width: 26, height: 22)
        Text("Add VPN")
          .font(Typeface.body)
        Spacer()
        Text("⌘N").font(Typeface.mono).foregroundStyle(Brand.muted.opacity(0.7))
      }
      .foregroundStyle(hovering ? Brand.ink : Brand.muted)
      .animation(.easeOut(duration: 0.12), value: hovering)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Brand.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
      )
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
    VStack(spacing: 0) {
      ForEach(destinations) { destination in
        HStack {
          Text(destination.host)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
          reachability(destination.reachability)
            .monospacedDigit()
        }
        .font(Typeface.mono)
        .padding(.vertical, 3)
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
        HStack(spacing: 6) {
          Image(systemName: opensAtLogin ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(opensAtLogin ? Brand.rose : Brand.muted)
          Text("Open at login")
        }
      }
      Spacer()
      Button("Log", action: actions.showLog)
        .keyboardShortcut("l")
      Button("Quit", action: actions.quit)
        .keyboardShortcut("q")
    }
    .buttonStyle(PressableStyle())
    .font(Typeface.caption)
    .foregroundStyle(Brand.muted)
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
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
    .buttonStyle(PressableStyle())
    .onHover { hovering = $0 }
    .help(help)
    .accessibilityLabel(help)
  }
}
