import Foundation

/// A chord that works from any app: `⌃⌥⌘1`–`⌃⌥⌘9` connect the route in that place in the panel, and
/// `⌃⌥⌘0` turns the VPN off.
public enum GlobalShortcut: Equatable, Sendable {
  case route(Int)
  case disconnect

  /// Every chord Peony registers, in the order they appear in the footer.
  public static let all: [GlobalShortcut] = (1...9).map(route) + [.disconnect]

  /// The number the chord is registered under, so a press can be mapped back. Nil for an id that
  /// isn't one of `all`.
  public init?(id: UInt32) {
    switch id {
    case 0: self = .disconnect
    case 1...9: self = .route(Int(id))
    default: return nil
    }
  }

  /// The chord's number key: `0` for disconnect.
  public var id: UInt32 {
    switch self {
    case .route(let number): UInt32(number)
    case .disconnect: 0
    }
  }

  public var title: String { "⌃⌥⌘\(id)" }

  /// What a press does, or nil when it should do nothing. It decides exactly as `peony connect` and
  /// `peony disconnect` do, so pressing a chord for the VPN that's already up never restarts it.
  public func action(among routes: [UUID], tunnel: ControlSnapshot.Tunnel) -> ControlPolicy.Goal? {
    let goal: ControlPolicy.Goal
    switch self {
    case .route(let number):
      guard routes.indices.contains(number - 1) else { return nil }
      goal = .up(routes[number - 1])
    case .disconnect:
      goal = .down
    }
    // A tunnel that's going down is ignored rather than waited out: nobody is waiting to be told.
    return ControlPolicy.plan(goal, tunnel) == .start ? goal : nil
  }

  /// The notice for chords macOS or another app already holds, or nil when none are. The rest still work.
  public static func notice(taken: [GlobalShortcut]) -> String? {
    guard !taken.isEmpty else { return nil }
    if taken.count == all.count { return "Another app already uses every one of these shortcuts." }
    let names = taken.map(\.title).formatted(.list(type: .and, width: .standard))
    return "\(names) \(taken.count == 1 ? "is" : "are") already used by another app. The rest still work."
  }
}
