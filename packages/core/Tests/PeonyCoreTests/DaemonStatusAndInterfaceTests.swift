import Foundation
import Testing
@testable import PeonyCore

struct NetBirdStatusTests {
  @Test func `connected status strips the prefix length`() throws {
    let json = Data(#"{"management":{"url":"x","connected":true},"netbirdIp":"100.64.8.171/22"}"#.utf8)
    #expect(try DaemonStatus(netBird: json) == DaemonStatus(isConnected: true, address: "100.64.8.171"))
  }

  @Test func `disconnected daemon reports no address`() throws {
    let json = Data(#"{"management":{"connected":false},"netbirdIp":""}"#.utf8)
    #expect(try DaemonStatus(netBird: json) == DaemonStatus(isConnected: false, address: nil))
  }
}

struct TailscaleStatusTests {
  @Test func `running status picks the IPv4 address`() throws {
    let json = Data(#"{"Version":"1.104.1","BackendState":"Running","Self":{"HostName":"mac","TailscaleIPs":["fd7a:115c:a1e0::1","100.101.102.103"],"Online":true},"Peer":{}}"#.utf8)
    #expect(try DaemonStatus(tailscale: json) == DaemonStatus(isConnected: true, address: "100.101.102.103"))
  }

  @Test func `stopped status is off and drops the address`() throws {
    let json = Data(#"{"BackendState":"Stopped","Self":{"TailscaleIPs":["100.101.102.103","fd7a:115c:a1e0::1"],"Online":false}}"#.utf8)
    #expect(try DaemonStatus(tailscale: json) == DaemonStatus(isConnected: false, address: nil))
  }

  @Test func `signed out status needs login`() throws {
    let json = Data(#"{"BackendState":"NeedsLogin","AuthURL":"https://login.tailscale.com/a/abc","TailscaleIPs":null,"Self":null}"#.utf8)
    #expect(try DaemonStatus(tailscale: json) == DaemonStatus(isConnected: false, address: nil, needsLogin: true))
  }

  @Test func `device awaiting admin approval needs login`() throws {
    let json = Data(#"{"BackendState":"NeedsMachineAuth","Self":{"TailscaleIPs":["100.101.102.103"]}}"#.utf8)
    #expect(try DaemonStatus(tailscale: json) == DaemonStatus(isConnected: false, address: nil, needsLogin: true))
  }

  @Test func `daemon errors are not status`() {
    #expect(throws: DecodingError.self) { try DaemonStatus(tailscale: Data("failed to connect to local Tailscale service".utf8)) }
  }
}

struct InterfaceSnapshotTests {
  @Test func `forti address comes from ppp0`() {
    let snapshot = InterfaceSnapshot(ipv4: ["en0": "192.168.1.39", "ppp0": "10.122.0.8"])
    #expect(snapshot.fortiAddress == "10.122.0.8")
  }

  @Test(arguments: [("100.64.0.1", true), ("100.127.255.254", true), ("100.128.0.1", false), ("10.0.0.1", false), ("garbage", false)])
  func `CGNAT range`(address: String, expected: Bool) {
    #expect(InterfaceSnapshot.isCGNAT(address) == expected)
  }

  @Test func `live snapshot includes loopback`() {
    #expect(InterfaceSnapshot.current().ipv4["lo0"] == "127.0.0.1")
  }
}
