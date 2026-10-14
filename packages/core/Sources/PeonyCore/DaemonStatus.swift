import Foundation

/// The parts of a VPN daemon's `status --json` that Peony cares about.
public struct DaemonStatus: Equatable, Sendable {
  public var isConnected: Bool
  /// The peer address without its prefix length, e.g. `100.64.8.171`.
  public var address: String?
  /// Nobody is signed in, or an admin hasn't approved this device yet, so bringing it up would hang.
  public var needsLogin: Bool

  public init(isConnected: Bool, address: String?, needsLogin: Bool = false) {
    self.isConnected = isConnected
    self.address = address
    self.needsLogin = needsLogin
  }

  /// `netbird status --json`.
  public init(netBird json: Data) throws {
    let raw = try JSONDecoder().decode(NetBirdRaw.self, from: json)
    isConnected = raw.management.connected
    let ip = raw.netbirdIp?.split(separator: "/").first.map(String.init)
    address = ip?.isEmpty == false ? ip : nil
    needsLogin = false
  }

  /// `tailscale status --json`. Tailscale keeps its addresses while stopped, so only a running one has an address.
  public init(tailscale json: Data) throws {
    let raw = try JSONDecoder().decode(TailscaleRaw.self, from: json)
    isConnected = raw.backendState == "Running"
    address = isConnected ? raw.selfNode?.tailscaleIPs?.first { !$0.contains(":") } : nil
    needsLogin = ["NeedsLogin", "NeedsMachineAuth"].contains(raw.backendState)
  }

  private struct NetBirdRaw: Decodable {
    struct Management: Decodable { var connected: Bool }
    var management: Management
    var netbirdIp: String?
  }

  private struct TailscaleRaw: Decodable {
    struct Node: Decodable {
      var tailscaleIPs: [String]?

      enum CodingKeys: String, CodingKey { case tailscaleIPs = "TailscaleIPs" }
    }

    var backendState: String
    var selfNode: Node?

    enum CodingKeys: String, CodingKey {
      case backendState = "BackendState"
      case selfNode = "Self"
    }
  }
}
