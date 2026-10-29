import Foundation
import PeonyCore

/// Sends the request, opening Peony first when the request may and nothing answered.
func send(_ request: ControlRequest) async -> ControlReply {
  guard let path = Control.socketPath() else { return .refused(.pathTooLong) }
  // The app holds a connect or disconnect until its own deadline, so allow a little past it.
  let timeout: Duration = switch request {
  case .status: .seconds(5)
  case .connect(_, let wait), .disconnect(let wait): wait.duration + .seconds(10)
  }
  let reply = await ControlSocket.send(request, to: path, timeout: timeout)
  guard request.launchesApp, reply == .refused(.notRunning) else { return reply }
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

/// The Peony.app this binary sits in (Contents/Helpers/peony), so another copy elsewhere on disk is
/// never the one launched or reported. Nil when run from anywhere else.
func containingApp() -> URL? {
  let executable = (Bundle.main.executableURL ?? URL(filePath: CommandLine.arguments[0])).resolvingSymlinksInPath()
  let helpers = executable.deletingLastPathComponent()
  let app = helpers.deletingLastPathComponent().deletingLastPathComponent()
  return helpers.lastPathComponent == "Helpers" && app.pathExtension == "app" ? app : nil
}

/// Opens Peony.app, or by bundle id when this binary runs from anywhere else.
func launchApp() -> Bool {
  let target = containingApp().map { [$0.path(percentEncoded: false)] } ?? ["-b", "app.peony.Peony"]
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
