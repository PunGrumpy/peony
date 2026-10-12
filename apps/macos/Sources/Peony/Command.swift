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

  /// Output is drained while the process runs, so a chatty command can't fill
  /// the pipe buffer and deadlock waiting for a reader.
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

    try process.run()
    if let input {
      stdin.fileHandleForWriting.write(input)
      try? stdin.fileHandleForWriting.close()
    }
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return Result(status: process.terminationStatus, output: output)
  }
}
