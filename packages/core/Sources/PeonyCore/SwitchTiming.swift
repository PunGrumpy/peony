/// How long one switch took, from the click to every host checked once.
public struct SwitchTiming: Equatable, Sendable {
  /// Taking the old tunnel down. 0 when nothing was up.
  public var teardownMs: Int
  /// Browser sign-in only: time a person spent, so it is never counted in `readyMs`.
  public var signInMs: Int?
  /// From the old tunnel being gone (or the click) to the new one being up, minus sign-in.
  public var tunnelMs: Int
  /// From the tunnel being up to every host checked once. 0 with no hosts.
  public var checksMs: Int

  public var readyMs: Int { teardownMs + tunnelMs + checksMs }

  public init(teardownMs: Int, signInMs: Int? = nil, tunnelMs: Int, checksMs: Int) {
    self.teardownMs = teardownMs
    self.signInMs = signInMs
    self.tunnelMs = tunnelMs
    self.checksMs = checksMs
  }

  /// `Ready in 2.4 s`, for the panel.
  public var readyText: String { "Ready in \(Self.seconds(readyMs))" }

  /// `Ready in 2.4 s: teardown 0.3 s, tunnel 1.9 s, hosts 0.2 s.`, for the log.
  public var summary: String {
    "\(readyText): teardown \(Self.seconds(teardownMs)), tunnel \(Self.seconds(tunnelMs)), hosts \(Self.seconds(checksMs))."
  }

  /// Seconds to one decimal, rounding halves up. Integer math, so 2.25 can't land on either side by float luck.
  static func seconds(_ milliseconds: Int) -> String {
    let tenths = (max(milliseconds, 0) + 50) / 100
    return "\(tenths / 10).\(tenths % 10) s"
  }
}

extension SwitchTiming: Codable {
  private enum CodingKeys: String, CodingKey { case teardownMs, signInMs, tunnelMs, checksMs, readyMs }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      teardownMs: try container.decode(Int.self, forKey: .teardownMs),
      signInMs: try container.decodeIfPresent(Int.self, forKey: .signInMs),
      tunnelMs: try container.decode(Int.self, forKey: .tunnelMs),
      checksMs: try container.decode(Int.self, forKey: .checksMs))
  }

  /// `readyMs` is written too, so a JSON reader doesn't have to add the parts up.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(teardownMs, forKey: .teardownMs)
    try container.encodeIfPresent(signInMs, forKey: .signInMs)
    try container.encode(tunnelMs, forKey: .tunnelMs)
    try container.encode(checksMs, forKey: .checksMs)
    try container.encode(readyMs, forKey: .readyMs)
  }
}

/// Records the moments of one switch. A value, so tests drive it with made-up instants.
public struct SwitchClock: Sendable {
  public typealias Instant = ContinuousClock.Instant

  private let start: Instant
  private var tornDownAt: Instant?
  private var signInBeganAt: Instant?
  private var signInEndedAt: Instant?
  private var upAt: Instant?
  private var timing: SwitchTiming?

  public init(start: Instant = .now) {
    self.start = start
  }

  public mutating func tornDown(at instant: Instant = .now) {
    tornDownAt = tornDownAt ?? instant
  }

  public mutating func signInBegan(at instant: Instant = .now) {
    signInBeganAt = signInBeganAt ?? instant
  }

  public mutating func signInEnded(at instant: Instant = .now) {
    signInEndedAt = signInEndedAt ?? instant
  }

  public mutating func up(at instant: Instant = .now) {
    upAt = upAt ?? instant
  }

  /// Nil until `up`. Repeated marks keep the first one, so a later recheck can't move the number.
  public mutating func checked(at instant: Instant = .now) -> SwitchTiming? {
    if let timing { return timing }
    guard let upAt else { return nil }
    let tornDownAt = tornDownAt ?? start
    let signIn = signInBeganAt.flatMap { began in signInEndedAt.map { $0 - began } }
    let result = SwitchTiming(
      teardownMs: Self.milliseconds(tornDownAt - start),
      signInMs: signIn.map(Self.milliseconds),
      tunnelMs: Self.milliseconds((upAt - tornDownAt) - (signIn ?? .zero)),
      checksMs: Self.milliseconds(instant - upAt))
    timing = result
    return result
  }

  private static func milliseconds(_ duration: Duration) -> Int {
    max(Int((duration / .milliseconds(1)).rounded()), 0)
  }
}
