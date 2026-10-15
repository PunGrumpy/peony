import Darwin
import Foundation
import Testing
@testable import PeonyCore

struct ProbeTests {
  @Test func `an open port answers`() async throws {
    let listener = try Listener()
    defer { close(listener.socket) }
    let ms = await Probe.connect(to: try #require(Probe.Target("127.0.0.1:\(listener.port)")))
    #expect(ms != nil)
  }

  @Test func `a closed port doesn't`() async throws {
    let listener = try Listener()
    close(listener.socket)
    let ms = await Probe.connect(to: try #require(Probe.Target("127.0.0.1:\(listener.port)")))
    #expect(ms == nil)
  }

  @Test func `a silent host times out`() async throws {
    // TEST-NET-1 never answers, so only the timeout can end the probe.
    let start = ContinuousClock.now
    let ms = await Probe.connect(to: try #require(Probe.Target("192.0.2.1:443")), timeout: .milliseconds(200))
    #expect(ms == nil)
    #expect(ContinuousClock.now - start < .seconds(2))
  }
}

/// A TCP socket listening on a free loopback port.
private struct Listener {
  let socket: Int32
  let port: UInt16

  init() throws {
    let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let bound = withUnsafeMutablePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, length) == 0 && listen(fd, 1) == 0 && getsockname(fd, $0, &length) == 0
      }
    }
    guard bound else {
      close(fd)
      throw POSIXError(.EADDRNOTAVAIL)
    }
    socket = fd
    port = UInt16(bigEndian: address.sin_port)
  }
}
