import AppKit
import SwiftUI

/// Peony's palette: ink on paper with one accent, after Orchid and Keiki.
/// Every colour adapts to dark mode, where paper becomes a warm near-black.
public enum Brand {
  /// A plum-black, the colour of a peony's darkest petals.
  public static let ink = adaptive(light: 0x1C0D12, dark: 0xF2EFF0)
  public static let paper = adaptive(light: 0xFCFBFB, dark: 0x171415)
  /// Raised surfaces: the active route card.
  public static let surface = adaptive(light: 0xFFFFFF, dark: 0x221E20)
  /// Resting cards and chips (Orchid's chip grey, warmed).
  public static let chip = adaptive(light: 0xF0EDEE, dark: 0x1F1B1D)
  public static let muted = adaptive(light: 0x8E8689, dark: 0x8A8285)
  public static let hairline = adaptive(light: 0x1C0D12, dark: 0xFFFFFF, alpha: 0.08)
  /// A muted peony rose, used only for "this is live".
  public static let rose = adaptive(light: 0xC85C7C, dark: 0xE07C98)
  public static let warning = adaptive(light: 0xB4532A, dark: 0xE88B5E)

  static func adaptive(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return NSColor(hex: isDark ? dark : light, alpha: alpha)
    })
  }
}

extension NSColor {
  convenience init(hex: UInt32, alpha: CGFloat = 1) {
    self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
              green: CGFloat((hex >> 8) & 0xFF) / 255,
              blue: CGFloat(hex & 0xFF) / 255,
              alpha: alpha)
  }
}

/// Three voices, like Orchid's Louize / Lausanne / JetBrains Mono, using the system's own.
public enum Typeface {
  /// New York for headlines. Tracking tightens as size grows.
  public static func display(_ size: CGFloat) -> Font {
    .system(size: size, weight: .medium, design: .serif)
  }

  public static func displayTracking(_ size: CGFloat) -> CGFloat { -0.035 * size }

  public static let body = Font.system(size: 13)
  public static let bodyEmphasis = Font.system(size: 13, weight: .medium)
  public static let caption = Font.system(size: 11.5)
  /// SF Mono for addresses, durations and small labels.
  public static let mono = Font.system(size: 11.5, design: .monospaced)
  public static let label = Font.system(size: 10, weight: .medium, design: .monospaced)
}

/// Feedback on press, not release. Scale alone: fading too would flicker the text.
public struct PressableStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .contentShape(Rectangle())
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

/// A small uppercase mono label, Orchid's way of naming a section.
struct SectionLabel: View {
  let text: String

  var body: some View {
    Text(text.uppercased())
      .font(Typeface.label)
      .tracking(0.8)
      .foregroundStyle(Brand.muted)
  }
}
