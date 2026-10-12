import SwiftUI

/// The Peony mark: a double peony from above. Five broad outer petals, each with the
/// soft notch a peony petal has at its edge, around five small inner petals set between
/// them. Every petal is the same shape, none touch, and nothing is outlined or cut;
/// the gaps do the drawing.
///
/// The rings strengthen from the centre out, which is how the menu bar shows a tunnel
/// coming up: the inner ring first, the outer ring once it's on.
public struct PeonyMark: View {
  /// Inner ring, outer ring.
  public static let shapeCount = 2

  /// How many rings are at full strength, inner first; the rest are faint.
  public var filled: Int
  public var color: Color
  /// The inner ring's colour, when it should differ.
  public var innerColor: Color?

  public init(filled: Int = PeonyMark.shapeCount, color: Color = .primary, innerColor: Color? = nil) {
    self.filled = filled
    self.color = color
    self.innerColor = innerColor
  }

  public var body: some View {
    Canvas { context, size in
      let side = min(size.width, size.height)
      let transform = CGAffineTransform(translationX: (size.width - side) / 2, y: (size.height - side) / 2)
        .scaledBy(x: side, y: side)
      for (index, ring) in [Self.inner, Self.outer].enumerated() {
        let tint = index == 0 ? (innerColor ?? color) : color
        // Faint rather than outlined: at 16pt an outline fills the petal and reads as solid.
        context.fill(ring.applying(transform), with: .color(index < filled ? tint : tint.opacity(0.35)))
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }

  static let outer = ring(count: 5, rotation: 0, from: 0.175, to: 0.5, width: 0.39, notch: 0)
  static let inner = ring(count: 5, rotation: 36, from: 0.035, to: 0.16, width: 0.115, notch: 0)

  static func ring(count: Int, rotation: Double, from: CGFloat, to: CGFloat, width: CGFloat, notch: CGFloat) -> Path {
    let shape = petal(from: from, to: to, width: width, notch: notch)
    var path = Path()
    for index in 0..<count {
      let angle = (rotation + Double(index) * 360 / Double(count)) * .pi / 180
      path.addPath(shape, transform: CGAffineTransform(translationX: 0.5, y: 0.5).rotated(by: angle))
    }
    return path
  }

  /// One petal pointing up from the centre: a small rounded tip near the middle,
  /// widening into a broad crown with an optional shallow notch at its edge.
  static func petal(from inner: CGFloat, to outer: CGFloat, width: CGFloat, notch: CGFloat) -> Path {
    let length = outer - inner
    let half = width / 2
    let tip = width * 0.05
    // Broad petals widen like a fan and finish in a flatter crown; small ones stay teardrops.
    let fan = width / length > 1
    let shoulder = inner + length * (fan ? 0.64 : 0.6)
    var path = Path()
    path.move(to: CGPoint(x: -tip, y: -inner))
    path.addQuadCurve(to: CGPoint(x: tip, y: -inner), control: CGPoint(x: 0, y: -inner + tip * 0.9))
    path.addCurve(to: CGPoint(x: half, y: -shoulder),
                  control1: CGPoint(x: half * 0.42, y: -inner - length * 0.12),
                  control2: CGPoint(x: half, y: -inner - length * (fan ? 0.34 : 0.3)))
    if notch > 0 {
      // Two lobes meeting in a soft dip: the edge of a peony petal.
      path.addCurve(to: CGPoint(x: 0, y: -outer + notch),
                    control1: CGPoint(x: half * 1.02, y: -outer - length * 0.06),
                    control2: CGPoint(x: half * 0.22, y: -outer - length * 0.01))
      path.addCurve(to: CGPoint(x: -half, y: -shoulder),
                    control1: CGPoint(x: -half * 0.22, y: -outer - length * 0.01),
                    control2: CGPoint(x: -half * 1.02, y: -outer - length * 0.06))
    } else {
      let overshoot = length * (fan ? 0.13 : 0.12)
      path.addCurve(to: CGPoint(x: -half, y: -shoulder),
                    control1: CGPoint(x: half * 0.98, y: -outer - overshoot),
                    control2: CGPoint(x: -half * 0.98, y: -outer - overshoot))
    }
    path.addCurve(to: CGPoint(x: -tip, y: -inner),
                  control1: CGPoint(x: -half, y: -inner - length * (fan ? 0.34 : 0.3)),
                  control2: CGPoint(x: -half * 0.42, y: -inner - length * 0.12))
    path.closeSubpath()
    return path
  }
}
