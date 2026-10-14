import Foundation

/// Everything the panel shows, as a plain value. The app builds it from live
/// state; snapshots build it by hand.
public struct PanelState: Equatable, Sendable {
  public var routes: [Route]
  /// The route that's up, coming up, going down, or just failed.
  public var activeRouteID: UUID?
  public var connection: TunnelState
  /// When the active route came up, for the running timer.
  public var connectedSince: Date?
  public var destinations: [DestinationStatus]
  public var opensAtLogin: Bool

  public init(
    routes: [Route] = [],
    activeRouteID: UUID? = nil,
    connection: TunnelState = .off,
    connectedSince: Date? = nil,
    destinations: [DestinationStatus] = [],
    opensAtLogin: Bool = false
  ) {
    self.routes = routes
    self.activeRouteID = activeRouteID
    self.connection = connection
    self.connectedSince = connectedSince
    self.destinations = destinations
    self.opensAtLogin = opensAtLogin
  }

  public var activeRoute: Route? {
    routes.first { $0.id == activeRouteID }
  }

  public func state(of route: Route) -> TunnelState {
    route.id == activeRouteID ? connection : .off
  }

  public var isLive: Bool { connection.address != nil }
  public var isBusy: Bool { connection.isBusy }
}

/// One VPN, as the panel shows it.
public struct Route: Equatable, Identifiable, Sendable {
  public enum Kind: Equatable, Sendable { case forti, openConnect, wireGuard, openVPN, netBird, tailscale }

  public var id: UUID
  public var name: String
  public var kind: Kind
  /// Where it goes: a host, a URL's host, or an interface.
  public var endpoint: String

  public init(id: UUID = UUID(), name: String, kind: Kind, endpoint: String) {
    self.id = id
    self.name = name
    self.kind = kind
    self.endpoint = endpoint
  }

  public var symbol: String {
    switch kind {
    case .forti: "lock.shield.fill"
    case .openConnect: "network.badge.shield.half.filled"
    case .wireGuard: "bolt.horizontal.fill"
    case .openVPN: "key.horizontal.fill"
    case .netBird: "point.3.filled.connected.trianglepath.dotted"
    case .tailscale: "circle.grid.3x3.fill"
    }
  }
}

/// A host Peony checks once a route is up, so "connected" means "I can reach my stuff".
public struct DestinationStatus: Equatable, Sendable, Identifiable {
  public enum Reachability: Equatable, Sendable {
    case checking
    case reachable(milliseconds: Int)
    case unreachable
  }

  public var host: String
  public var reachability: Reachability
  public var id: String { host }

  public init(host: String, reachability: Reachability) {
    self.host = host
    self.reachability = reachability
  }
}

/// What the panel can ask the app to do.
public struct PanelActions {
  public var connect: (UUID) -> Void
  public var disconnect: () -> Void
  public var retry: () -> Void
  public var fix: (TunnelFailure.Fix) -> Void
  public var addVPN: () -> Void
  public var openSettings: () -> Void
  public var showLog: () -> Void
  public var setOpensAtLogin: (Bool) -> Void
  public var quit: () -> Void

  public init(
    connect: @escaping (UUID) -> Void = { _ in },
    disconnect: @escaping () -> Void = {},
    retry: @escaping () -> Void = {},
    fix: @escaping (TunnelFailure.Fix) -> Void = { _ in },
    addVPN: @escaping () -> Void = {},
    openSettings: @escaping () -> Void = {},
    showLog: @escaping () -> Void = {},
    setOpensAtLogin: @escaping (Bool) -> Void = { _ in },
    quit: @escaping () -> Void = {}
  ) {
    self.connect = connect
    self.disconnect = disconnect
    self.retry = retry
    self.fix = fix
    self.addVPN = addVPN
    self.openSettings = openSettings
    self.showLog = showLog
    self.setOpensAtLogin = setOpensAtLogin
    self.quit = quit
  }
}
