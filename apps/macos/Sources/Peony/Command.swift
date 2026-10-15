import Foundation

/// Runs a short-lived command to completion off the main actor.
nonisolated enum Command {
  struct Result: Sendable {
    var status: Int32
    var output: Data
    var succeeded: Bool { status == 0 }
    var text: String { String(decoding: output, as: UTF8.self) }
  }

  static func run(_ executable: String, _ arguments: String...) async throws -> Result {
    try await run(executable, arguments: arguments)
  }

  /// Waits on the process and its output asynchronously, so a slow command never holds
  /// a thread of the concurrency pool, and a chatty one can't fill the pipe and deadlock.
  @concurrent
  static func run(_ executable: String, arguments: [String], input: Data? = nil) async throws -> Result {
    let process = Process()
    process.executableURL = URL(filePath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    let stdin = Pipe()
    if input != nil { process.standardInput = stdin }
    let exit = AsyncStream<Int32> { continuation in
      process.terminationHandler = { finished in
        continuation.yield(finished.terminationStatus)
        continuation.finish()
      }
    }

    try process.run()
    if let input {
      stdin.fileHandleForWriting.write(input)
      try? stdin.fileHandleForWriting.close()
    }
    var output = Data()
    for try await byte in pipe.fileHandleForReading.bytes { output.append(byte) }
    var status: Int32 = -1
    for await code in exit { status = code }
    return Result(status: status, output: output)
  }
}
