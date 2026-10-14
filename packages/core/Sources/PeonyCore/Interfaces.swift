import Darwin

/// A snapshot of every interface's IPv4 address, keyed by interface name.
///
/// Reading it is a single `getifaddrs` call with no process spawn, which is why
/// Peony can afford to check it every couple of seconds to notice tunnels
/// coming and going.
public struct InterfaceSnapshot: Equatable, Sendable {
  public var ipv4: [String: String]

  public init(ipv4: [String: String]) {
    self.ipv4 = ipv4
  }

  public static func current() -> InterfaceSnapshot {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return InterfaceSnapshot(ipv4: [:]) }
    defer { freeifaddrs(head) }

    var result: [String: String] = [:]
    for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
      guard let addr = entry.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let status = getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
      guard status == 0 else { continue }
      let name = String(cString: entry.pointee.ifa_name)
      result[name] = String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    return InterfaceSnapshot(ipv4: result)
  }

  /// The address of the PPP link openfortivpn brings up.
  public var fortiAddress: String? { ipv4["ppp0"] }

  public static func isCGNAT(_ address: String) -> Bool {
    let octets = address.split(separator: ".").compactMap { Int($0) }
    guard octets.count == 4 else { return false }
    return octets[0] == 100 && (64...127).contains(octets[1])
  }
}
