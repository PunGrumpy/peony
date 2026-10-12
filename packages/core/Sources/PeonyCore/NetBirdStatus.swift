import Foundation

/// The parts of `netbird status --json` that Peony cares about.
public struct NetBirdStatus: Equatable, Sendable {
  public var isConnected: Bool
  /// The peer address without its prefix length, e.g. `100.64.8.171`.
  public var address: String?

  public init(isConnected: Bool, address: String?) {
    self.isConnected = isConnected
    self.address = address
  }

  public init(json: Data) throws {
    let raw = try JSONDecoder().decode(Raw.self, from: json)
    isConnected = raw.management.connected
    let ip = raw.netbirdIp?.split(separator: "/").first.map(String.init)
    address = ip?.isEmpty == false ? ip : nil
  }

  private struct Raw: Decodable {
    struct Management: Decodable { var connected: Bool }
    var management: Management
    var netbirdIp: String?
  }
}
