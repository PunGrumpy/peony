import Foundation
import Testing
@testable import PeonyCore

struct NetBirdStatusTests {
  @Test func `connected status strips the prefix length`() throws {
    let json = Data(#"{"management":{"url":"x","connected":true},"netbirdIp":"100.64.8.171/22"}"#.utf8)
    #expect(try NetBirdStatus(json: json) == NetBirdStatus(isConnected: true, address: "100.64.8.171"))
  }

  @Test func `disconnected daemon reports no address`() throws {
    let json = Data(#"{"management":{"connected":false},"netbirdIp":""}"#.utf8)
    #expect(try NetBirdStatus(json: json) == NetBirdStatus(isConnected: false, address: nil))
  }
}

struct InterfaceSnapshotTests {
  @Test func `forti address comes from ppp0`() {
    let snapshot = InterfaceSnapshot(ipv4: ["en0": "192.168.1.39", "ppp0": "10.122.0.8"])
    #expect(snapshot.fortiAddress == "10.122.0.8")
    #expect(snapshot.netBirdAddress == nil)
  }

  @Test func `netbird address is a utun in CGNAT space`() {
    let snapshot = InterfaceSnapshot(ipv4: ["en0": "192.168.1.39", "utun100": "100.64.8.171"])
    #expect(snapshot.netBirdAddress == "100.64.8.171")
  }

  @Test(arguments: [("100.64.0.1", true), ("100.127.255.254", true), ("100.128.0.1", false), ("10.0.0.1", false), ("garbage", false)])
  func `CGNAT range`(address: String, expected: Bool) {
    #expect(InterfaceSnapshot.isCGNAT(address) == expected)
  }

  @Test func `live snapshot includes loopback`() {
    #expect(InterfaceSnapshot.current().ipv4["lo0"] == "127.0.0.1")
  }
}
