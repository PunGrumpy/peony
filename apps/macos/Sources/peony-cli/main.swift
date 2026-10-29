// peony: drive Peony.app from a terminal, a script or an AI agent.
//
//   peony list | status | connect <name|id> | disconnect   [--json] [--timeout <seconds>]
//
// It asks the running app over its control socket and never starts a tunnel itself: the app is
// the only owner of the connection. It depends on PeonyCore alone, so it can't.
import Foundation
import PeonyCore

let usage = """
  Usage: peony <command> [--json] [--timeout <seconds>]

  Commands:
    list                 your VPNs, and which one is active
    status               the tunnel: state, address, failure and its fix, host checks
    connect <name|id>    turn any other VPN off, connect this one, and wait until it's on or failed
    disconnect           turn the active VPN off and wait until it's off

  Options:
    --json               print one JSON object on stdout, the same shape for every command
    --timeout <seconds>  how long connect and disconnect wait, 1 to 600 (90 and 30 by default)
    -h, --help           show this help

  connect and disconnect open Peony if it isn't running; list and status don't.

  Exit codes: 0 done, 1 the VPN failed, 2 usage, 3 Peony isn't available,
  4 no VPN by that name, 5 timed out, 6 interrupted by another request

  """

enum Command: Equatable {
  case help
  case list
  case status
  case connect(String, WaitLimit)
  case disconnect(WaitLimit)

  /// Nil for what `peony` answers by itself. `list` is `status` printed as a list.
  var request: ControlRequest? {
    switch self {
    case .help: nil
    case .list, .status: .status
    case .connect(let vpn, let wait): .connect(vpn: vpn, wait: wait)
    case .disconnect(let wait): .disconnect(wait: wait)
    }
  }

  /// Reading status never opens Peony; changing the tunnel does.
  var launchesApp: Bool {
    switch self {
    case .help, .list, .status: false
    case .connect, .disconnect: true
    }
  }
}

struct Invocation {
  var command: Command
  var json: Bool
}

struct UsageError: Error {
  var message: String
}

func parse(_ arguments: [String]) throws(UsageError) -> Invocation {
  var json = false
  var timeout: WaitLimit?
  var operands: [String] = []
  var rest = arguments[...]

  func seconds(_ text: String) throws(UsageError) -> WaitLimit {
    guard let value = Int(text), let limit = WaitLimit(seconds: value) else {
      throw UsageError(message: "--timeout takes a whole number of seconds from 1 to 600, not \"\(text)\".")
    }
    return limit
  }

  while let argument = rest.popFirst() {
    switch argument {
    case "--json":
      json = true
    case "-h", "--help":
      return Invocation(command: .help, json: json)
    case "--timeout":
      guard let value = rest.popFirst() else { throw UsageError(message: "--timeout needs a number of seconds.") }
      timeout = try seconds(value)
    case _ where argument.hasPrefix("--timeout="):
      timeout = try seconds(String(argument.dropFirst("--timeout=".count)))
    case "--":
      operands += rest
      rest = []
    case _ where argument.hasPrefix("-") && argument.count > 1:
      throw UsageError(message: "Unknown option \(argument).")
    default:
      operands.append(argument)
    }
  }

  guard let name = operands.first else { throw UsageError(message: "Say what to do.") }
  let arguments = operands.dropFirst()
  let command: Command
  switch name {
  case "help":
    command = .help
  case "list", "status":
    guard arguments.isEmpty else { throw UsageError(message: "\(name) takes no arguments.") }
    guard timeout == nil else { throw UsageError(message: "--timeout only applies to connect and disconnect.") }
    command = name == "list" ? .list : .status
  case "connect":
    guard arguments.count == 1, let vpn = arguments.first, !vpn.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw UsageError(message: "connect takes one VPN name or id. Quote a name that has spaces.")
    }
    command = .connect(vpn, timeout ?? .connect)
  case "disconnect":
    guard arguments.isEmpty else { throw UsageError(message: "disconnect takes no arguments.") }
    command = .disconnect(timeout ?? .disconnect)
  default:
    throw UsageError(message: "Unknown command \(name).")
  }
  return Invocation(command: command, json: json)
}

/// Sends the request, opening Peony first when the command may and nothing answered.
func send(_ request: ControlRequest, launching: Bool) async -> ControlReply {
  guard let path = Control.socketPath() else { return .refused(.pathTooLong) }
  // The app holds a connect or disconnect until its own deadline, so allow a little past it.
  let timeout: Duration = switch request {
  case .status: .seconds(5)
  case .connect(_, let wait), .disconnect(let wait): wait.duration + .seconds(10)
  }
  let reply = await ControlSocket.send(request, to: path, timeout: timeout)
  guard launching, reply == .refused(.notRunning) else { return reply }
  guard launchApp() else { return .refused(.couldNotLaunch) }

  let deadline = ContinuousClock.now + .seconds(10)
  while ContinuousClock.now < deadline {
    try? await Task.sleep(for: .milliseconds(250))
    switch await ControlSocket.send(.status, to: path, timeout: .seconds(2)) {
    case .refused(.notRunning): continue
    case .answered: return await ControlSocket.send(request, to: path, timeout: timeout)
    case let other: return other
    }
  }
  return .refused(.couldNotLaunch)
}

/// Opens the Peony.app this binary sits in (Contents/Helpers/peony), so another copy elsewhere on
/// disk is never the one launched. Run from anywhere else, it opens Peony by bundle id.
func launchApp() -> Bool {
  let executable = (Bundle.main.executableURL ?? URL(filePath: CommandLine.arguments[0])).resolvingSymlinksInPath()
  let helpers = executable.deletingLastPathComponent()
  let app = helpers.deletingLastPathComponent().deletingLastPathComponent()
  let target = helpers.lastPathComponent == "Helpers" && app.pathExtension == "app"
    ? [app.path(percentEncoded: false)]
    : ["-b", "app.peony.Peony"]
  let open = Process()
  open.executableURL = URL(filePath: "/usr/bin/open")
  open.arguments = ["-g"] + target
  do {
    try open.run()
  } catch {
    return false
  }
  open.waitUntilExit()
  return open.terminationStatus == 0
}

/// JSON is the reply as it came, one object on stdout. Text is a short summary for people, with
/// refusals on stderr.
func render(_ reply: ControlReply, for command: Command, json: Bool) -> (stdout: String, stderr: String) {
  if json {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let text = (try? encoder.encode(reply)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    return (text + "\n", "")
  }
  switch reply {
  case .refused(let refusal):
    var lines = ["peony: " + refusal.message]
    if case .ambiguous(_, let matches) = refusal {
      lines += matches.map { "  \($0.id.uuidString)  \($0.name)  \($0.endpoint)" }
    }
    return ("", lines.joined(separator: "\n") + "\n")
  case .answered(let outcome, let snapshot):
    if command == .list { return (list(snapshot), "") }
    var lines: [String] = []
    switch outcome {
    case .done, .failed:
      break
    case .timedOut:
      lines.append("Timed out while the tunnel was still changing.")
    case .interrupted:
      lines.append("Interrupted: someone else connected or disconnected, or the sign-in window was closed.")
    }
    return ((lines + describe(snapshot.tunnel)).joined(separator: "\n") + "\n", "")
  }
}

func describe(_ tunnel: ControlSnapshot.Tunnel) -> [String] {
  switch tunnel {
  case .off:
    return ["No VPN is on."]
  case .connecting(let vpn, let signingIn):
    return [signingIn ? "Connecting \(vpn.name): finish signing in in Peony's window." : "Connecting \(vpn.name)…"]
  case .disconnecting(let vpn):
    return ["Disconnecting \(vpn.name)…"]
  case .on(let vpn, let address, _, let hosts):
    let width = hosts.map(\.host.count).max() ?? 0
    return ["\(vpn.name) is on" + (address.map { " at \($0)" } ?? "")] + hosts.map { host in
      let status = switch host.status {
      case .checking: "checking"
      case .reachable(let milliseconds): "reachable    \(milliseconds) ms"
      case .unreachable: "unreachable"
      }
      return "  " + host.host.padding(toLength: width + 3, withPad: " ", startingAt: 0) + status
    }
  case .failed(let vpn, let failure):
    let fix = failure.fix.map { fix in fix.command.map { "Fix: run `\($0)`" } ?? "Fix in Peony: \(fix.title)" }
    return ["\(vpn.name) failed: \(failure.message)"] + (fix.map { [$0] } ?? [])
  }
}

func list(_ snapshot: ControlSnapshot) -> String {
  guard !snapshot.vpns.isEmpty else { return "No VPNs yet. Add one in Peony's settings.\n" }
  let active = snapshot.tunnel.vpn?.id
  let state = switch snapshot.tunnel {
  case .off: ""
  case .connecting: "connecting"
  case .disconnecting: "disconnecting"
  case .on: "on"
  case .failed: "failed"
  }
  let rows = snapshot.vpns.map { vpn in
    let kind = switch vpn.kind {
    case .forti: "FortiGate"
    case .openConnect: "OpenConnect"
    case .wireGuard: "WireGuard"
    case .openVPN: "OpenVPN"
    case .netBird: "NetBird"
    case .tailscale: "Tailscale"
    }
    return [vpn.id == active ? "*" : " ", vpn.name, kind, vpn.endpoint, vpn.id == active ? state : ""]
  }
  let widths = (1...3).map { column in rows.map { $0[column].count }.max() ?? 0 }
  return rows.map { row in
    let padded = (1...3).map { row[$0].padding(toLength: widths[$0 - 1], withPad: " ", startingAt: 0) }
    return ([row[0]] + padded + [row[4]]).joined(separator: "  ").replacingOccurrences(of: " +$", with: "", options: .regularExpression)
  }.joined(separator: "\n") + "\n"
}

let invocation: Invocation
do {
  invocation = try parse(Array(CommandLine.arguments.dropFirst()))
} catch {
  FileHandle.standardError.write(Data("peony: \(error.message)\n\n\(usage)".utf8))
  exit(ControlReply.usageExitCode)
}

guard let request = invocation.command.request else {
  print(usage, terminator: "")
  exit(0)
}
let reply = await send(request, launching: invocation.command.launchesApp)
let output = render(reply, for: invocation.command, json: invocation.json)
FileHandle.standardOutput.write(Data(output.stdout.utf8))
FileHandle.standardError.write(Data(output.stderr.utf8))
exit(reply.exitCode)
