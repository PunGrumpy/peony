import Foundation
import Testing
@testable import PeonyCore

struct SwitchTimingTests {
  let start = ContinuousClock.Instant.now

  private func at(_ milliseconds: Int) -> ContinuousClock.Instant {
    start.advanced(by: .milliseconds(milliseconds))
  }

  @Test func `with nothing up there is no teardown to count`() throws {
    var clock = SwitchClock(start: start)
    clock.tornDown(at: at(0))
    clock.up(at: at(1900))
    let result = clock.checked(at: at(2100))
    let timing = try #require(result)
    #expect(timing == SwitchTiming(teardownMs: 0, tunnelMs: 1900, checksMs: 200))
    #expect(timing.readyMs == 2100)
  }

  @Test func `taking the old tunnel down comes first`() throws {
    var clock = SwitchClock(start: start)
    clock.tornDown(at: at(300))
    clock.up(at: at(2200))
    let result = clock.checked(at: at(2400))
    let timing = try #require(result)
    #expect(timing == SwitchTiming(teardownMs: 300, tunnelMs: 1900, checksMs: 200))
    #expect(timing.readyMs == 2400)
  }

  @Test func `a person signing in is reported but never counted as ready time`() throws {
    var clock = SwitchClock(start: start)
    clock.tornDown(at: at(0))
    clock.signInBegan(at: at(500))
    clock.signInEnded(at: at(20_500))
    clock.up(at: at(21_900))
    let result = clock.checked(at: at(22_100))
    let timing = try #require(result)
    #expect(timing.signInMs == 20_000)
    #expect(timing.tunnelMs == 1900)
    #expect(timing.readyMs == 2100)
  }

  @Test func `a switch that never needed a sign-in has none`() throws {
    var clock = SwitchClock(start: start)
    clock.tornDown(at: at(0))
    clock.up(at: at(800))
    let result = clock.checked(at: at(800))
    let timing = try #require(result)
    #expect(timing.signInMs == nil)
  }

  @Test func `hosts checked before the tunnel is up says nothing yet`() {
    var clock = SwitchClock(start: start)
    clock.tornDown(at: at(100))
    let timing = clock.checked(at: at(200))
    #expect(timing == nil)
  }

  @Test func `a later check can't move the number`() throws {
    var clock = SwitchClock(start: start)
    clock.tornDown(at: at(0))
    clock.up(at: at(1000))
    let result = clock.checked(at: at(1200))
    let first = try #require(result)
    clock.up(at: at(9000))
    let again = clock.checked(at: at(30_000))
    #expect(again == first)
    #expect(first.checksMs == 200)
  }

  @Test func `no hosts means the tunnel being up is the end`() throws {
    var clock = SwitchClock(start: start)
    clock.tornDown(at: at(0))
    clock.up(at: at(1500))
    let result = clock.checked(at: at(1500))
    let timing = try #require(result)
    #expect(timing.checksMs == 0)
  }

  @Test(arguments: [
    (0, "Ready in 0.0 s"), (49, "Ready in 0.0 s"), (50, "Ready in 0.1 s"), (2249, "Ready in 2.2 s"),
    (2250, "Ready in 2.3 s"), (2400, "Ready in 2.4 s"), (9960, "Ready in 10.0 s"), (65_000, "Ready in 65.0 s"),
  ])
  func `ready text rounds to one decimal`(milliseconds: Int, text: String) {
    #expect(SwitchTiming(teardownMs: 0, tunnelMs: milliseconds, checksMs: 0).readyText == text)
  }

  @Test func `the log line breaks the total into its parts`() {
    let timing = SwitchTiming(teardownMs: 300, tunnelMs: 1900, checksMs: 200)
    #expect(timing.summary == "Ready in 2.4 s: teardown 0.3 s, tunnel 1.9 s, hosts 0.2 s.")
  }

  @Test func `json carries the total so a reader doesn't add the parts`() throws {
    let timing = SwitchTiming(teardownMs: 300, signInMs: 20_000, tunnelMs: 1900, checksMs: 200)
    let json = String(decoding: try Control.line(timing), as: UTF8.self)
    #expect(json == #"{"checksMs":200,"readyMs":2400,"signInMs":20000,"teardownMs":300,"tunnelMs":1900}"# + "\n")
    #expect(try JSONDecoder().decode(SwitchTiming.self, from: Data(json.utf8)) == timing)

    let bare = SwitchTiming(teardownMs: 0, tunnelMs: 800, checksMs: 0)
    #expect(String(decoding: try Control.line(bare), as: UTF8.self) == #"{"checksMs":0,"readyMs":800,"teardownMs":0,"tunnelMs":800}"# + "\n")
  }
}
