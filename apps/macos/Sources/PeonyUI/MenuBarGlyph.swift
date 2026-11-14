import AppKit
import SwiftUI

/// The menu bar item: the flower, plus the tunnel's name whenever one is on,
/// so "is the VPN up?" is answered without opening anything.
public struct MenuBarLabel: View {
  let filledPetals: Int
  let title: String?
  let alert: Bool

  /// - Parameters:
  ///   - filledPetals: 0 (all faint) when off, `PeonyMark.shapeCount` when on, 1 while connecting.
  ///   - title: The tunnel's name while one is up or coming up.
  ///   - alert: The VPN failed to connect or dropped, so the flower carries an exclamation mark.
  public init(filledPetals: Int, title: String?, alert: Bool = false) {
    self.filledPetals = filledPetals
    self.title = title
    self.alert = alert
  }

  public var body: some View {
    // MenuBarExtra renders an Image + Text label as icon and title, like the system's own items.
    Image(nsImage: MenuBarGlyph.image(filledPetals: filledPetals, alert: alert))
    if let title {
      Text(title)
    }
  }
}

public enum MenuBarGlyph {
  /// Template images, rendered once: one per number of filled shapes, without and with the alert.
  private static let images: [[NSImage]] = [false, true].map { alert in
    (0...PeonyMark.shapeCount).map { filled in
      let renderer = ImageRenderer(content: glyph(filled: filled, alert: alert).frame(width: 16, height: 16))
      renderer.scale = 2
      let image = renderer.nsImage ?? NSImage()
      image.size = NSSize(width: 16, height: 16)
      image.isTemplate = true
      return image
    }
  }

  public static func image(filledPetals: Int, alert: Bool = false) -> NSImage {
    images[alert ? 1 : 0][min(max(filledPetals, 0), PeonyMark.shapeCount)]
  }

  /// The flower, or the flower with an exclamation mark at its right edge, the mark the
  /// Wi-Fi item uses for "no internet". The mark is cut clear of the petals, and it sits
  /// on whole points so it stays sharp on a 1x display.
  @ViewBuilder private static func glyph(filled: Int, alert: Bool) -> some View {
    let mark = PeonyMark(filled: filled, color: .black)
    if alert {
      Canvas { context, size in
        let point = size.width / 16
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
          CGRect(x: x * point, y: y * point, width: width * point, height: height * point)
        }
        if let mark = context.resolveSymbol(id: 0) {
          context.draw(mark, in: CGRect(origin: .zero, size: size))
        }
        let ink = GraphicsContext.Shading.color(.black)
        context.blendMode = .destinationOut
        context.fill(Path(roundedRect: rect(12, 6, 6, 12), cornerRadius: 2 * point), with: ink)
        context.blendMode = .normal
        context.fill(Path(roundedRect: rect(14, 7, 2, 6), cornerRadius: point), with: ink)
        context.fill(Path(roundedRect: rect(14, 14, 2, 2), cornerRadius: point / 2), with: ink)
      } symbols: {
        mark.tag(0)
      }
    } else {
      mark
    }
  }
}
