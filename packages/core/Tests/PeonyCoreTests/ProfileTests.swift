import Foundation
import Testing
@testable import PeonyCore

struct ProfileTests {
  private func fortiLogin(of profile: Profile) -> Profile.Forti.Login? {
    if case .forti(let settings) = profile.kind { settings.login } else { nil }
  }

  @Test func `a profile saved before browser sign-in decodes as a password login`() throws {
    let legacy = """
      {"id":"7B0E7A58-2E8B-4B1F-9F4B-0D6C5D1C9A11","name":"Work","destinations":["git.example.com"],
       "kind":{"forti":{"_0":{"host":"vpn.example.com","port":8443,"username":"alex","trustedCert":"abc","realm":"corp"}}}}
      """
    let profile = try JSONDecoder().decode(Profile.self, from: Data(legacy.utf8))
    #expect(fortiLogin(of: profile) == .password(username: "alex"))
    guard case .forti(let settings) = profile.kind else {
      Issue.record("not a FortiGate profile")
      return
    }
    #expect(settings.host == "vpn.example.com")
    #expect(settings.port == 8443)
    #expect(settings.trustedCert == "abc")
    #expect(settings.realm == "corp")
    #expect(profile.needsPassword)

    let encoded = try JSONEncoder().encode(profile)
    #expect(try JSONDecoder().decode(Profile.self, from: encoded) == profile)
  }

  @Test func `encoding writes login and no top-level username`() throws {
    let profile = Profile(name: "Work", kind: .forti(.init(host: "vpn.example.com", login: .password(username: "alex"))))
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any]
    let forti = ((object?["kind"] as? [String: Any])?["forti"] as? [String: Any])?["_0"] as? [String: Any]
    #expect(forti?["login"] != nil)
    #expect(forti?["username"] == nil)
  }

  @Test func `a browser profile round-trips and needs no password`() throws {
    let profile = Profile(name: "SSO", kind: .forti(.init(host: "vpn.example.com", login: .browser, realm: "corp")))
    let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
    #expect(decoded == profile)
    #expect(fortiLogin(of: decoded) == .browser)
    #expect(!decoded.needsPassword)
  }

  @Test func `a login with neither login nor username is refused`() {
    let broken = #"{"host":"vpn.example.com","port":443}"#
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Profile.Forti.self, from: Data(broken.utf8)) }
  }

  /// Set PEONY_PROFILES_COPY to a copy of a real profiles.json to prove it still decodes.
  @Test(.enabled(if: ProcessInfo.processInfo.environment["PEONY_PROFILES_COPY"] != nil))
  func `a real profiles file still decodes`() throws {
    let path = try #require(ProcessInfo.processInfo.environment["PEONY_PROFILES_COPY"])
    let data = try Data(contentsOf: URL(filePath: path))
    let profiles = try JSONDecoder().decode([Profile].self, from: data)
    #expect(!profiles.isEmpty)
    let again = try JSONDecoder().decode([Profile].self, from: JSONEncoder().encode(profiles))
    #expect(again == profiles)
    for profile in profiles { print("decoded \(profile.kindTitle), login: \(String(describing: fortiLogin(of: profile)))") }
  }
}
