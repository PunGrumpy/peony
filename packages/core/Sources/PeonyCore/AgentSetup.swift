import Foundation

/// How Peony adds itself to a coding agent: as an MCP server the agent starts with `peony mcp`.
public enum AgentSetup {
  public enum Agent: String, CaseIterable, Identifiable, Sendable {
    case claudeCode, codex, cursor

    public var id: Self { self }

    public var title: String {
      switch self {
      case .claudeCode: "Claude Code"
      case .codex: "Codex"
      case .cursor: "Cursor"
      }
    }
  }

  /// What Add does for one agent.
  public enum Install: Equatable, Sendable {
    /// A command for Terminal, so the agent's own CLI writes its config.
    case command(String)
    /// A link the agent's app opens to add the server. `entry` is the same server as an `mcp.json`
    /// entry, for adding it by hand.
    case link(URL, entry: String)

    /// What Copy puts on the clipboard.
    public var copyText: String {
      switch self {
      case .command(let command): command
      case .link(_, let entry): entry
      }
    }
  }

  /// `cli` is the path to the `peony` binary inside the app bundle.
  public static func install(_ agent: Agent, cli: String) -> Install {
    switch agent {
    case .claudeCode:
      return .command("claude mcp add --scope user peony -- \(shellQuoted(cli)) mcp")
    case .codex:
      return .command("codex mcp add peony -- \(shellQuoted(cli)) mcp")
    case .cursor:
      let config = #"{"command":\#(jsonString(cli)),"args":["mcp"]}"#
      // Base64 has + / and =, which a query would read as a space and separators.
      let encoded = Data(config.utf8).base64EncodedString()
        .addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
      let url = URL(string: "cursor://anysphere.cursor-deeplink/mcp/install?name=peony&config=\(encoded)")!
      return .link(url, entry: #"{"mcpServers":{"peony":\#(config)}}"#)
    }
  }

  /// One shell word that stays one word whatever the path holds: single quotes, with each `'`
  /// closed, escaped and reopened.
  public static func shellQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
  }

  private static func jsonString(_ value: String) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    return String(decoding: try! encoder.encode(value), as: UTF8.self)
  }
}
