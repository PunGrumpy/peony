import SwiftUI

/// Rows that belong together share one rounded well, after System Settings and Control Center.
/// Corners are concentric: a row's radius is the well's minus the inset between them.
public struct Well<Content: View>: View {
  @ViewBuilder let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: 0) { content }
      .padding(WellRow.inset)
      .background(RoundedRectangle(cornerRadius: WellRow.wellRadius, style: .continuous).fill(Brand.chip))
  }
}

/// The shape of a row inside a well.
enum WellRow {
  static let wellRadius: CGFloat = 12
  static let inset: CGFloat = 4
  static let shape = RoundedRectangle(cornerRadius: wellRadius - inset, style: .continuous)
}

/// A hairline between rows of a well, inset to line up with their text.
struct WellDivider: View {
  var body: some View {
    Rectangle()
      .fill(Brand.hairline)
      .frame(height: 1)
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
  }
}

/// A glyph on a rounded square, the way System Settings marks each pane.
public struct IconTile: View {
  let symbol: String
  let size: CGFloat
  let fill: Color
  let glyph: Color

  public init(symbol: String, size: CGFloat, fill: Color, glyph: Color = .white) {
    self.symbol = symbol
    self.size = size
    self.fill = fill
    self.glyph = glyph
  }

  public var body: some View {
    Image(systemName: symbol)
      .font(.system(size: size * 0.44, weight: .semibold))
      .foregroundStyle(glyph)
      .frame(width: size, height: size)
      // Apple's icon corner, about 22% of the side.
      .background(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous).fill(fill))
      .accessibilityHidden(true)
  }
}
