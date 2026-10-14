import Foundation
import PeonyCore

/// `Tools.find` for tools only the app runs. The root helper shares `Tools`, so a client
/// that lives inside a Mac app is looked up here, where the helper never sees it.
enum AppTools {
  private static let bundled = ["tailscale": "/Applications/Tailscale.app/Contents/MacOS/Tailscale"]

  static func find(_ name: String) -> String? {
    Tools.find(name) ?? bundled[name].flatMap { FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil }
  }
}

/// A VPN whose own background service holds the tunnel. Peony asks its command-line client to
/// start and stop it and reads its status, so none of it goes through the root helper.
struct Daemon {
  var tool: String
  var parse: (Data) throws -> DaemonStatus

  static let netBird = Daemon(tool: "netbird", parse: { try DaemonStatus(netBird: $0) })
  static let tailscale = Daemon(tool: "tailscale", parse: { try DaemonStatus(tailscale: $0) })

  var executable: String { AppTools.find(tool) ?? "/opt/homebrew/bin/\(tool)" }

  /// Nil when the client isn't there or the service doesn't answer.
  func status() async -> DaemonStatus? {
    guard let result = try? await Command.run(executable, "status", "--json") else { return nil }
    return try? parse(result.output)
  }
}

extension Profile.Kind {
  var daemon: Daemon? {
    switch self {
    case .netBird: .netBird
    case .tailscale: .tailscale
    case .forti, .openConnect, .wireGuard: nil
    }
  }
}
