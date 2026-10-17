import Foundation
import Testing
@testable import PeonyCore

/// Peony's VPN list is saved as this JSON. A release that can't read an older file loses the user's VPNs, so these decode what earlier versions wrote.
struct ProfileCodingTests {
  static let saved = """
    [
      {"destinations": ["gitlab.example.com", "10.0.0.5:22"], "id": "00000000-0000-0000-0000-000000000001",
       "kind": {"forti": {"_0": {"host": "vpn.example.com", "port": 8443, "realm": "staff",
         "trustedCert": "abababababababababababababababababababababababababababababababab", "username": "alex"}}},
       "name": "Office"},
      {"destinations": [], "id": "00000000-0000-0000-0000-000000000002",
       "kind": {"openConnect": {"_0": {"server": "https:\\/\\/vpn.example.edu\\/group", "serverProtocol": "gp", "username": "sam"}}},
       "name": "Campus"},
      {"destinations": [], "id": "00000000-0000-0000-0000-000000000003",
       "kind": {"wireGuard": {"_0": {"interfaceName": "wg-home"}}}, "name": "Home"},
      {"destinations": [], "id": "00000000-0000-0000-0000-000000000004",
       "kind": {"openVPN": {"_0": {"server": "ovpn.example.com", "username": ""}}}, "name": "Lab"},
      {"destinations": [], "id": "00000000-0000-0000-0000-000000000005",
       "kind": {"netBird": {"_0": {"managementURL": ""}}}, "name": "Mesh"},
      {"destinations": [], "id": "00000000-0000-0000-0000-000000000006",
       "kind": {"tailscale": {}}, "name": "Tail"}
    ]
    """

  @Test func `decodes every kind saved by earlier versions`() throws {
    let profiles = try JSONDecoder().decode([Profile].self, from: Data(Self.saved.utf8))
    #expect(profiles.count == 6)
    #expect(profiles[0].destinations == ["gitlab.example.com", "10.0.0.5:22"])

    guard case .forti(let forti) = profiles[0].kind else { throw Failure.wrongKind }
    #expect(forti.port == 8443)
    #expect(forti.realm == "staff")

    guard case .openConnect(let openConnect) = profiles[1].kind else { throw Failure.wrongKind }
    #expect(openConnect.serverProtocol == .gp)
    #expect(openConnect.serverCert == nil)

    guard case .wireGuard(let wireGuard) = profiles[2].kind else { throw Failure.wrongKind }
    #expect(wireGuard.interfaceName == "wg-home")

    guard case .openVPN = profiles[3].kind else { throw Failure.wrongKind }
    guard case .netBird = profiles[4].kind else { throw Failure.wrongKind }
    #expect(profiles[5].kind == .tailscale)
  }

  @Test func `round-trips through the encoder Peony saves with`() throws {
    let profiles = try JSONDecoder().decode([Profile].self, from: Data(Self.saved.utf8))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let again = try JSONDecoder().decode([Profile].self, from: encoder.encode(profiles))
    #expect(again == profiles)
  }

  @Test func `a missing optional field still decodes`() throws {
    let old = """
      [{"destinations":[],"id":"00000000-0000-0000-0000-000000000007","kind":{"forti":{"_0":{"host":"h.example.com","port":443,"username":"u"}}},"name":"Old"}]
      """
    let profiles = try JSONDecoder().decode([Profile].self, from: Data(old.utf8))
    let profile = try #require(profiles.first)
    guard case .forti(let forti) = profile.kind else { throw Failure.wrongKind }
    #expect(forti.trustedCert == nil)
    #expect(forti.realm == nil)
  }

  private enum Failure: Error { case wrongKind }
}
