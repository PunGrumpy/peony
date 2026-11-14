import Testing

@testable import PeonyCore

struct FortiLogParserTests {
  static let certFailure =
    "ERROR:  Gateway certificate validation failed, and the certificate digest is not in the local whitelist. If you trust it, rerun with:"
  static let digest = "e46d4aff08ba6914e64daa85bc6112a422fa7ce16631bff0b592a28556f993db"
  static let digestLine = "ERROR:      --trusted-cert \(digest)"

  @Test func `tunnel up with its INFO prefix`() {
    var parser = FortiLogParser()
    #expect(parser.consume("INFO:   Tunnel is up and running.") == .tunnelUp)
  }

  @Test func `wrong password is an authentication failure, not a generic error`() {
    var parser = FortiLogParser()
    let line = "ERROR:  Could not authenticate to gateway. Please check the password, client certificate, etc."
    #expect(parser.consume(line) == .authenticationFailed)
  }

  @Test func `certificate failure waits for the fingerprint line`() {
    var parser = FortiLogParser()
    #expect(parser.consume(Self.certFailure) == nil)
    #expect(parser.consume(Self.digestLine) == .certificateRejected(digest: Self.digest))
  }

  @Test func `upper-case fingerprint comes back lower-case`() {
    var parser = FortiLogParser()
    _ = parser.consume(Self.certFailure)
    let event = parser.consume("ERROR:      --trusted-cert \(Self.digest.uppercased())")
    #expect(event == .certificateRejected(digest: Self.digest))
  }

  @Test func `certificate failure followed by another error offers no fingerprint`() {
    var parser = FortiLogParser()
    _ = parser.consume(Self.certFailure)
    #expect(parser.consume("ERROR:  Could not log out.") == .certificateRejected(digest: nil))
  }

  @Test func `errors after a delivered fingerprint are ordinary errors`() {
    var parser = FortiLogParser()
    _ = parser.consume(Self.certFailure)
    #expect(parser.consume(Self.digestLine) == .certificateRejected(digest: Self.digest))
    #expect(parser.consume("ERROR:  Could not log out.") == .error("Could not log out."))
  }

  @Test func `errors after a missing fingerprint are ordinary errors`() {
    var parser = FortiLogParser()
    _ = parser.consume(Self.certFailure)
    #expect(parser.consume("ERROR:  Could not log out.") == .certificateRejected(digest: nil))
    #expect(parser.consume("ERROR:  Could not log out.") == .error("Could not log out."))
  }

  @Test func `sudo without a password rule`() {
    var parser = FortiLogParser()
    #expect(parser.consume("sudo: a password is required") == .sudoNeedsPassword)
  }

  @Test func `ordinary error drops the prefix and padding`() {
    var parser = FortiLogParser()
    #expect(parser.consume("ERROR:  Could not log out.") == .error("Could not log out."))
  }

  @Test(arguments: ["", "   ", "\t", "INFO:   Connected to gateway.", "INFO:   Authenticated."])
  func `lines that mean nothing give no event`(line: String) {
    var parser = FortiLogParser()
    #expect(parser.consume(line) == nil)
  }

  @Test(arguments: [
    String(FortiLogParserTests.digest.dropLast()),
    String(FortiLogParserTests.digest.prefix(8)),
  ])
  func `a fingerprint shorter than 64 characters is not offered`(short: String) {
    var parser = FortiLogParser()
    _ = parser.consume(Self.certFailure)
    #expect(parser.consume("ERROR:      --trusted-cert \(short)") == .certificateRejected(digest: nil))
  }
}
