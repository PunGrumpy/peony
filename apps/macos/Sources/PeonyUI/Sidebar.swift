import SwiftUI

/// One entry in the settings sidebar.
public struct SidebarEntry<ID: Hashable>: Identifiable {
  public let id: ID
  public let title: String
  public let symbol: String
  public let tint: Color
  public let glyph: Color
  /// A live VPN gets a rose dot, so it's easy to find.
  public let isLive: Bool

  public init(id: ID, title: String, symbol: String, tint: Color, glyph: Color = .white, isLive: Bool = false) {
    self.id = id
    self.title = title
    self.symbol = symbol
    self.tint = tint
    self.glyph = glyph
    self.isLive = isLive
  }
}

/// The settings sidebar, drawn in Peony's own style rather than as a system list.
/// A system list highlights in the Mac's accent colour, which clashes with the rose everywhere
/// else; the app can't set its own accent without an asset catalog. Here the selection is the
/// same raised row the panel uses for the live route, and it slides between rows.
public struct SettingsSidebar<ID: Hashable>: View {
  let top: [SidebarEntry<ID>]
  let sectionTitle: String
  let items: [SidebarEntry<ID>]
  let bottom: [SidebarEntry<ID>]
  @Binding var selection: ID?
  /// Reorders `items`, with the same arguments as `Array.move(fromOffsets:toOffset:)`.
  /// Without it, rows can't be dragged.
  let move: ((IndexSet, Int) -> Void)?

  @Namespace private var lift
  @FocusState private var focused: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(top: [SidebarEntry<ID>], sectionTitle: String, items: [SidebarEntry<ID>], bottom: [SidebarEntry<ID>],
              selection: Binding<ID?>, move: ((IndexSet, Int) -> Void)? = nil) {
    self.top = top
    self.sectionTitle = sectionTitle
    self.items = items
    self.bottom = bottom
    _selection = selection
    self.move = move
  }

  public var body: some View {
    // The caller scrolls it; snapshots can't render a ScrollView.
    VStack(alignment: .leading, spacing: 2) {
      ForEach(top) { row($0) }

      SectionLabel(text: sectionTitle)
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 4)

      ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
        if let move {
          row(entry)
            .draggable(String(index))
            .dropDestination(for: String.self) { dropped, _ in
              guard let from = dropped.first.flatMap(Int.init), from != index else { return false }
              move(IndexSet(integer: from), index > from ? index + 1 : index)
              return true
            }
        } else {
          row(entry)
        }
      }
      ForEach(bottom) { row($0) }
    }
    .padding(10)
    .focusable()
    .focused($focused)
    .focusEffectDisabled()
    .onKeyPress(.upArrow) { step(-1) }
    .onKeyPress(.downArrow) { step(1) }
    .animation(reduceMotion ? nil : Motion.standard, value: selection)
  }

  private func row(_ entry: SidebarEntry<ID>) -> some View {
    SidebarRow(entry: entry, selected: selection == entry.id, lift: lift) {
      selection = entry.id
      focused = true
    }
  }

  /// Arrow keys move the selection, as they do in a system sidebar.
  private func step(_ offset: Int) -> KeyPress.Result {
    let order = (top + items + bottom).map(\.id)
    guard let current = selection.flatMap(order.firstIndex(of:)) else {
      selection = order.first
      return .handled
    }
    selection = order[min(max(current + offset, 0), order.count - 1)]
    return .handled
  }
}

private struct SidebarRow<ID: Hashable>: View {
  let entry: SidebarEntry<ID>
  let selected: Bool
  let lift: Namespace.ID
  let select: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: select) {
      HStack(spacing: 8) {
        IconTile(symbol: entry.symbol, size: 20, fill: entry.tint, glyph: entry.glyph)
        Text(entry.title)
          .font(Typeface.body)
          .foregroundStyle(Brand.ink)
          .lineLimit(1)
        Spacer(minLength: 4)
        if entry.isLive {
          Circle().fill(Brand.rose).frame(width: 6, height: 6)
            .accessibilityLabel("Connected")
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background {
        if selected {
          WellRow.shape
            .fill(Brand.surface)
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            .overlay(WellRow.shape.strokeBorder(Brand.hairline, lineWidth: 1))
            .matchedGeometryEffect(id: "lift", in: lift)
        } else {
          WellRow.shape
            .fill(Brand.ink.opacity(hovering ? 0.04 : 0))
            .animation(Motion.hover, value: hovering)
        }
      }
    }
    .buttonStyle(PressableStyle())
    .onHover { hovering = $0 }
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
