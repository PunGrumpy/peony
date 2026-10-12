import AppKit
import SwiftUI

/// The menu bar item: the flower, plus the tunnel's name whenever one is on,
/// so "is the VPN up?" is answered without opening anything.
public struct MenuBarLabel: View {
  let filledPetals: Int
  let title: String?

  /// - Parameters:
  ///   - filledPetals: 0 (all faint) when off, `PeonyMark.shapeCount` when on, 1 while connecting.
  ///   - title: The tunnel's name while one is up or coming up.
  public init(filledPetals: Int, title: String?) {
    self.filledPetals = filledPetals
    self.title = title
  }

  public var body: some View {
    // MenuBarExtra renders an Image + Text label as icon and title, like the system's own items.
    Image(nsImage: MenuBarGlyph.image(filledPetals: filledPetals))
    if let title {
      Text(title)
    }
  }
}

public enum MenuBarGlyph {
  /// Template images, rendered once: one per number of filled shapes.
  private static let images: [NSImage] = (0...PeonyMark.shapeCount).map { filled in
    let renderer = ImageRenderer(content:
      PeonyMark(filled: filled, color: .black).frame(width: 16, height: 16))
    renderer.scale = 2
    let image = renderer.nsImage ?? NSImage()
    image.size = NSSize(width: 16, height: 16)
    image.isTemplate = true
    return image
  }

  public static func image(filledPetals: Int) -> NSImage {
    images[min(max(filledPetals, 0), PeonyMark.shapeCount)]
  }
}
