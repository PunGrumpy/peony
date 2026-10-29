import Darwin
import Foundation

/// The transport under `Control`: one request line and one reply line per connection, over a Unix
/// socket only this user can reach. Framing, size limits, the peer check and the version check live
/// here, so the app and the CLI each make one call.
public enum ControlSocket {
  public enum Problem: Error, Equatable {
    /// Another live Peony already answers on this path. Its socket is left alone.
    case inUse
    case pathTooLong
    /// Something that isn't a socket sits at the path, so it isn't Peony's to remove.
    case notASocket
    case system(errno: Int32)
  }

  /// Requests are a few dozen bytes; the cap only stops a runaway client.
  static let requestLimit = 4096
  /// Replies list every VPN, so they get more room.
  static let replyLimit = 1 << 20
  /// How long a client has to finish its request line once connected.
  static let requestDeadline: Duration = .seconds(2)

  /// Serves `path` until the listener is closed. A live server already on the path means another
  /// Peony is running (`.inUse`); a socket left behind by one that crashed is replaced. The file is
  /// made 0600 before `listen`, and every accepted peer must run as this user. A request line that's
  /// too long, unreadable or not finished within 2 seconds is dropped without calling `handle`, which
  /// runs once per connection, concurrently with others.
  public static func serve(
    at path: String,
    handle: @escaping @Sendable (ControlRequest) async -> ControlReply
  ) throws(Problem) -> ControlListener {
    guard fits(path) else { throw .pathTooLong }
    try removeStale(path)
    try? FileManager.default.createDirectory(
      atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw .system(errno: errno) }
    var info = stat()
    let ready = withAddress(path) { bind(fd, $0, $1) } == 0
      && chmod(path, 0o600) == 0
      && stat(path, &info) == 0
      && listen(fd, 16) == 0
      && fcntl(fd, F_SETFL, O_NONBLOCK) == 0
      && fcntl(fd, F_SETFD, FD_CLOEXEC) == 0
    guard ready else {
      let error = errno
      close(fd)
      throw .system(errno: error)
    }

    let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue(label: "app.peony.control"))
    source.setEventHandler { acceptWaiting(on: fd, handle: handle) }
    source.setCancelHandler { close(fd) }
    source.resume()
    return ControlListener(path: path, inode: info.st_ino, source: source)
  }

  /// Sends one request and waits up to `timeout` for the reply. No answer, or the app quitting
  /// before it replied, is `.notRunning`; a permission error is `.blocked`, which is what an agent
  /// sandbox that forbids Unix sockets looks like.
  public static func send(_ request: ControlRequest, to path: String, timeout: Duration) async -> ControlReply {
    // Blocking reads stay off Swift's cooperative threads, which the app's own handlers need.
    await withCheckedContinuation { done in
      DispatchQueue.global().async { done.resume(returning: sendNow(request, to: path, timeout: timeout)) }
    }
  }

  private static func sendNow(_ request: ControlRequest, to path: String, timeout: Duration) -> ControlReply {
    guard fits(path) else { return .refused(.pathTooLong) }
    let fd: Int32
    switch connect(to: path) {
    case .success(let connected): fd = connected
    case .failure(let error) where error.code == .EPERM || error.code == .EACCES: return .refused(.blocked(path: path))
    case .failure: return .refused(.notRunning)
    }
    defer { close(fd) }
    guard let data = try? Control.line(request), write(data, to: fd),
          let line = readLine(from: fd, limit: replyLimit, within: timeout)
    else { return .refused(.notRunning) }
    guard let reply = try? JSONDecoder().decode(ControlReply.self, from: line) else {
      return .refused(.outdated(app: Control.version(of: line) ?? 0))
    }
    return reply
  }

  // MARK: Serving

  /// Only a socket nobody answers on is removed: a live one belongs to another Peony.
  private static func removeStale(_ path: String) throws(Problem) {
    switch connect(to: path) {
    case .success(let fd):
      close(fd)
      throw .inUse
    case .failure(let error) where error.code == .ENOENT:
      return
    case .failure(let error):
      var info = stat()
      guard lstat(path, &info) == 0 else { throw .system(errno: errno) }
      guard info.st_mode & S_IFMT == S_IFSOCK else { throw .notASocket }
      guard error.code == .ECONNREFUSED else { throw .system(errno: error.code.rawValue) }
      guard unlink(path) == 0 else { throw .system(errno: errno) }
    }
  }

  private static func acceptWaiting(on listener: Int32, handle: @escaping @Sendable (ControlRequest) async -> ControlReply) {
    while true {
      let client = accept(listener, nil, nil)
      guard client >= 0 else { return }
      var peer = uid_t()
      var group = gid_t()
      // Accepted sockets inherit the listener's O_NONBLOCK on Darwin; replies are written blocking.
      guard getpeereid(client, &peer, &group) == 0, peer == getuid(),
            fcntl(client, F_SETFL, 0) == 0, configure(client)
      else {
        close(client)
        continue
      }
      DispatchQueue.global().async { respond(on: client, handle: handle) }
    }
  }

  private static func respond(on client: Int32, handle: @escaping @Sendable (ControlRequest) async -> ControlReply) {
    guard let line = readLine(from: client, limit: requestLimit, within: requestDeadline) else {
      close(client)
      return
    }
    guard let request = try? JSONDecoder().decode(ControlRequest.self, from: line) else {
      if let version = Control.version(of: line), version != Control.version, let reply = try? Control.line(ControlReply.refused(.outdated(app: Control.version))) {
        _ = write(reply, to: client)
      }
      close(client)
      return
    }
    Task {
      // If the client already gave up, this write fails quietly. The tunnel is the app's either way.
      if let reply = try? Control.line(await handle(request)) { _ = write(reply, to: client) }
      close(client)
    }
  }

  // MARK: Both sides

  static func connect(to path: String) -> Result<Int32, POSIXError> {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return .failure(POSIXError.current) }
    guard withAddress(path, { Darwin.connect(fd, $0, $1) }) == 0, configure(fd) else {
      let error = POSIXError.current
      close(fd)
      return .failure(error)
    }
    return .success(fd)
  }

  /// No SIGPIPE when the other side hung up, no descriptor leaked into the tunnel tools Peony runs,
  /// and no write blocks forever on a client that stopped reading.
  private static func configure(_ fd: Int32) -> Bool {
    var on: Int32 = 1
    var sendTimeout = timeval(tv_sec: 5, tv_usec: 0)
    return setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size)) == 0
      && setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, socklen_t(MemoryLayout<timeval>.size)) == 0
      && fcntl(fd, F_SETFD, FD_CLOEXEC) == 0
  }

  static func fits(_ path: String) -> Bool {
    path.utf8.count < MemoryLayout.size(ofValue: sockaddr_un().sun_path)
  }

  private static func withAddress(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) -> Int32) -> Int32 {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    return withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
  }

  static func write(_ data: Data, to fd: Int32) -> Bool {
    data.withUnsafeBytes { buffer in
      var offset = 0
      while offset < buffer.count {
        let count = Darwin.write(fd, buffer.baseAddress! + offset, buffer.count - offset)
        if count < 0, errno == EINTR { continue }
        guard count > 0 else { return false }
        offset += count
      }
      return true
    }
  }

  /// One line, or nil on EOF, an error, an overlong line, or the deadline.
  static func readLine(from fd: Int32, limit: Int, within timeout: Duration) -> Data? {
    let deadline = ContinuousClock.now + timeout
    var line = LineBuffer(limit: limit)
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
      let left = ContinuousClock.now.duration(to: deadline)
      guard left > .zero else { return nil }
      var poller = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
      let ready = poll(&poller, 1, Int32(clamping: max(1, left.components.seconds * 1000 + left.components.attoseconds / 1_000_000_000_000_000)))
      if ready < 0, errno == EINTR { continue }
      guard ready > 0 else { return nil }
      let count = read(fd, &chunk, chunk.count)
      if count < 0, errno == EINTR { continue }
      guard count > 0 else { return nil }
      switch line.append(chunk[..<count]) {
      case .line(let data): return data
      case .tooLong: return nil
      case .incomplete: continue
      }
    }
  }
}

/// Bytes off a stream until the first newline, refusing a line longer than `limit`.
struct LineBuffer {
  enum Result: Equatable {
    case incomplete
    /// Without the newline. Anything after it is ignored: one line per connection.
    case line(Data)
    case tooLong
  }

  let limit: Int
  private var bytes = Data()

  init(limit: Int) {
    self.limit = limit
  }

  mutating func append(_ more: some Sequence<UInt8>) -> Result {
    bytes.append(contentsOf: more)
    if let end = bytes.firstIndex(of: UInt8(ascii: "\n")) {
      return end - bytes.startIndex > limit ? .tooLong : .line(bytes[bytes.startIndex..<end])
    }
    return bytes.count > limit ? .tooLong : .incomplete
  }
}

/// A listening control socket. Closing it stops accepting and removes the socket file, unless
/// another server has replaced it since.
public final class ControlListener: Sendable {
  private let path: String
  private let inode: ino_t
  private let source: any DispatchSourceRead

  fileprivate init(path: String, inode: ino_t, source: any DispatchSourceRead) {
    self.path = path
    self.inode = inode
    self.source = source
  }

  public func close() {
    source.cancel()
    var info = stat()
    if lstat(path, &info) == 0, info.st_ino == inode { unlink(path) }
  }
}

private extension POSIXError {
  static var current: POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}
