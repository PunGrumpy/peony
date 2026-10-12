// peony-helper: the only part of Peony that runs as root.
//
// Installed to /Library/PrivilegedHelperTools/app.peony.helper (root:wheel 0755) with a sudoers
// rule that lets the logged-in user run it without a password. Because any argument can reach it,
// it trusts nothing: every value is validated in PeonyCore before it touches a config file or argv,
// and it only executes tools from Homebrew's bin directories.
//
//   peony-helper version   prints Helper.version
//   peony-helper run       reads one JSON HelperRequest from stdin and carries it out
import Darwin
import Foundation
import PeonyCore

func fail(_ message: String, code: Int32 = 2) -> Never {
  FileHandle.standardError.write(Data("ERROR:  \(message)\n".utf8))
  exit(code)
}

func tool(_ name: String) -> String {
  guard let path = Tools.find(name) else {
    fail("\(name) isn't installed. Install it with: brew install \(name == "wg-quick" ? "wireguard-tools" : name)", code: 3)
  }
  return path
}

/// Writes a root-only file in Peony's run directory.
func writePrivate(_ contents: String, name: String) -> String {
  let directory = Helper.runDirectory
  mkdir(directory, 0o700)
  chmod(directory, 0o700)
  let path = "\(directory)/\(name)"
  let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0o600)
  guard fd >= 0 else { fail("Couldn't write \(path)") }
  defer { close(fd) }
  let bytes = Array(contents.utf8)
  guard write(fd, bytes, bytes.count) == bytes.count else { fail("Couldn't write \(path)") }
  return path
}

/// Runs a long-lived tunnel process, forwarding SIGINT/SIGTERM so the app can hang up cleanly,
/// and exits with its status. `afterLaunch` runs once the child is up (used to delete secrets).
func supervise(_ executable: String, _ arguments: [String], stdin: String? = nil, afterLaunch: @escaping @Sendable () -> Void = {}) -> Never {
  let process = Process()
  process.executableURL = URL(filePath: executable)
  process.arguments = arguments
  process.environment = ["PATH": (Tools.searchDirectories + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]).joined(separator: ":")]
  let input = Pipe()
  if stdin != nil { process.standardInput = input }

  for sig in [SIGINT, SIGTERM, SIGHUP] { signal(sig, SIG_IGN) }
  let sources = [SIGINT, SIGTERM, SIGHUP].map { sig in
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { if process.isRunning { kill(process.processIdentifier, SIGINT) } }
    source.resume()
    return source
  }

  do { try process.run() } catch { fail("Couldn't start \(executable): \(error.localizedDescription)") }
  if let stdin {
    input.fileHandleForWriting.write(Data((stdin + "\n").utf8))
    try? input.fileHandleForWriting.close()
  }
  DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: afterLaunch)
  process.terminationHandler = { finished in
    afterLaunch()
    _ = sources
    exit(finished.terminationStatus)
  }
  dispatchMain()
}

/// Runs a short command to completion, passing its output through.
func runToCompletion(_ executable: String, _ arguments: [String]) -> Int32 {
  let process = Process()
  process.executableURL = URL(filePath: executable)
  process.arguments = arguments
  // wg-quick needs Homebrew's bash 4 and wg ahead of the system ones.
  process.environment = ["PATH": (Tools.searchDirectories + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]).joined(separator: ":")]
  do { try process.run() } catch { fail("Couldn't start \(executable): \(error.localizedDescription)") }
  process.waitUntilExit()
  return process.terminationStatus
}

func handle(_ request: HelperRequest) -> Never {
  switch request {
  case .forti(let forti):
    let config: String
    do { config = try forti.configFile() } catch { fail(error.description) }
    let path = writePrivate(config, name: "forti.conf")
    // openfortivpn reads its config at startup, so the password only lives on disk briefly.
    supervise(tool("openfortivpn"), ["-c", path], afterLaunch: { unlink(path) })

  case .openConnect(let request):
    let arguments: [String]
    do { arguments = try request.arguments() } catch { fail(error.description) }
    supervise(tool("openconnect"), arguments, stdin: request.password)

  case .wireGuardUp(let request):
    let name: String
    let config: String
    do {
      name = try Validation.interfaceName(request.interfaceName)
      config = try WireGuardConfig.validate(request.config)
    } catch let error as Validation.Failure {
      fail(error.description)
    } catch let error as WireGuardConfig.Problem {
      fail(error.description)
    } catch {
      fail("\(error)")
    }
    // wg-quick needs the file again to bring the interface down, so it stays until then.
    let path = writePrivate(config, name: "\(name).conf")
    exit(runToCompletion(tool("wg-quick"), ["up", path]))

  case .wireGuardDown(let interfaceName):
    let name: String
    do { name = try Validation.interfaceName(interfaceName) } catch { fail(error.description) }
    let path = "\(Helper.runDirectory)/\(name).conf"
    let status = runToCompletion(tool("wg-quick"), ["down", path])
    unlink(path)
    exit(status)

  case .stop:
    _ = runToCompletion("/usr/bin/pkill", ["-INT", "-x", "openfortivpn"])
    _ = runToCompletion("/usr/bin/pkill", ["-INT", "-x", "openconnect"])
    exit(0)
  }
}

guard getuid() == 0 || CommandLine.arguments.dropFirst().first == "version" else {
  fail("peony-helper must run as root (through sudo).")
}

switch CommandLine.arguments.dropFirst().first {
case "version":
  print(Helper.version)
case "run":
  let input = FileHandle.standardInput.readDataToEndOfFile()
  guard input.count < 64 * 1024, let request = try? JSONDecoder().decode(HelperRequest.self, from: input) else {
    fail("Expected one JSON request on stdin.")
  }
  handle(request)
default:
  fail("Usage: peony-helper version | run")
}
