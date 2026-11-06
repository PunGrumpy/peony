import Foundation
import Testing
@testable import PeonyCore

struct GlobalShortcutTests {
  typealias Tunnel = ControlSnapshot.Tunnel

  private let office = ControlTests.officeID
  private let home = ControlTests.homeID
  private let officeRef = ControlTests.officeRef
  private let homeRef = ControlTests.homeRef

  private func on(_ ref: ControlSnapshot.VPNRef, checking: Bool = false) -> Tunnel {
    .on(ref, address: "10.0.0.2", since: nil, hosts: [.init(host: "git.example", status: checking ? .checking : .reachable(milliseconds: 20))])
  }

  // MARK: Identity

  @Test func `every chord's id maps back to it`() {
    for shortcut in GlobalShortcut.all {
      #expect(GlobalShortcut(id: shortcut.id) == shortcut)
    }
  }

  @Test func `ids that are no chord are nil`() {
    #expect(GlobalShortcut(id: 10) == nil)
    #expect(GlobalShortcut(id: .max) == nil)
  }

  @Test func `the chords are one to nine, then disconnect`() {
    #expect(GlobalShortcut.all.count == 10)
    #expect(GlobalShortcut.all.first == .route(1))
    #expect(GlobalShortcut.all.last == .disconnect)
    #expect(Set(GlobalShortcut.all.map(\.id)).count == 10)
  }

  @Test func `titles name the modifiers and the number`() {
    #expect(GlobalShortcut.route(3).title == "⌃⌥⌘3")
    #expect(GlobalShortcut.route(9).title == "⌃⌥⌘9")
    #expect(GlobalShortcut.disconnect.title == "⌃⌥⌘0")
  }

  // MARK: Actions

  @Test func `a route connects when nothing is on`() {
    #expect(GlobalShortcut.route(2).action(among: [office, home], tunnel: .off) == .up(home))
  }

  @Test func `a route switches away from another VPN that is on`() {
    #expect(GlobalShortcut.route(2).action(among: [office, home], tunnel: on(officeRef)) == .up(home))
  }

  @Test func `a route does nothing for the VPN that is already on`() {
    #expect(GlobalShortcut.route(1).action(among: [office, home], tunnel: on(officeRef)) == nil)
  }

  @Test func `a route does nothing while its VPN still checks hosts`() {
    #expect(GlobalShortcut.route(1).action(among: [office, home], tunnel: on(officeRef, checking: true)) == nil)
  }

  @Test func `a route does nothing for the VPN that is connecting`() {
    #expect(GlobalShortcut.route(1).action(among: [office, home], tunnel: .connecting(officeRef, signingIn: true)) == nil)
  }

  @Test func `a route does nothing while a tunnel is going down`() {
    #expect(GlobalShortcut.route(2).action(among: [office, home], tunnel: .disconnecting(officeRef)) == nil)
  }

  @Test func `a route tries again after its VPN failed`() {
    let failed = Tunnel.failed(officeRef, .init(message: "No answer", fix: nil))
    #expect(GlobalShortcut.route(1).action(among: [office, home], tunnel: failed) == .up(office))
  }

  @Test func `a number with no route does nothing`() {
    #expect(GlobalShortcut.route(3).action(among: [office, home], tunnel: .off) == nil)
    #expect(GlobalShortcut.route(1).action(among: [], tunnel: .off) == nil)
  }

  @Test func `disconnect turns off a tunnel that is on or coming up`() {
    #expect(GlobalShortcut.disconnect.action(among: [office], tunnel: on(officeRef)) == .down)
    #expect(GlobalShortcut.disconnect.action(among: [office], tunnel: .connecting(officeRef, signingIn: false)) == .down)
  }

  @Test func `disconnect clears a failed tunnel`() {
    let failed = Tunnel.failed(officeRef, .init(message: "No answer", fix: nil))
    #expect(GlobalShortcut.disconnect.action(among: [office], tunnel: failed) == .down)
  }

  @Test func `disconnect does nothing when nothing is up or it is already going down`() {
    #expect(GlobalShortcut.disconnect.action(among: [office], tunnel: .off) == nil)
    #expect(GlobalShortcut.disconnect.action(among: [office], tunnel: .disconnecting(officeRef)) == nil)
  }

  // MARK: Notice

  @Test func `no notice when every chord registered`() {
    #expect(GlobalShortcut.notice(taken: []) == nil)
  }

  @Test func `the notice names the taken chords and says the rest work`() {
    #expect(GlobalShortcut.notice(taken: [.route(2)]) == "⌃⌥⌘2 is already used by another app. The rest still work.")
    #expect(GlobalShortcut.notice(taken: [.route(2), .disconnect]) == "⌃⌥⌘2 and ⌃⌥⌘0 are already used by another app. The rest still work.")
  }

  @Test func `the notice does not promise the rest when none registered`() {
    #expect(GlobalShortcut.notice(taken: GlobalShortcut.all) == "Another app already uses every one of these shortcuts.")
  }
}
