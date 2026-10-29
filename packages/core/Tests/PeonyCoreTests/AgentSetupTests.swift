import Foundation
import Testing
@testable import PeonyCore

/// The commands and link Settings › Agents runs. Each one reaches a shell or another app, so a
/// path with spaces or quotes must arrive as the one path it is.
struct AgentSetupTests {
  static let cli = "/Applications/Peony.app/Contents/Helpers/peony"
  static let odd = "/Users/o'neil/My Apps/Peony.app/Contents/Helpers/peony"

  @Test func `Claude Code and Codex get their own mcp add command`() {
    #expect(AgentSetup.install(.claudeCode, cli: Self.cli)
      == .command("claude mcp add --scope user peony -- '/Applications/Peony.app/Contents/Helpers/peony' mcp"))
    #expect(AgentSetup.install(.codex, cli: Self.cli)
      == .command("codex mcp add peony -- '/Applications/Peony.app/Contents/Helpers/peony' mcp"))
  }

  @Test func `a path with spaces and a single quote stays one shell word`() {
    #expect(AgentSetup.shellQuoted(Self.odd) == #"'/Users/o'\''neil/My Apps/Peony.app/Contents/Helpers/peony'"#)
    #expect(AgentSetup.install(.codex, cli: Self.odd).copyText
      == #"codex mcp add peony -- '/Users/o'\''neil/My Apps/Peony.app/Contents/Helpers/peony' mcp"#)
  }

  @Test func `the shell reads the quoted path back as exactly one argument`() throws {
    let process = Process()
    process.executableURL = URL(filePath: "/bin/sh")
    process.arguments = ["-c", "printf '%s\\n' \(AgentSetup.shellQuoted(Self.odd)) | wc -l; printf '%s' \(AgentSetup.shellQuoted(Self.odd))"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    process.waitUntilExit()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let lines = output.split(separator: "\n", maxSplits: 1).map(String.init)
    #expect(lines.first?.trimmingCharacters(in: .whitespaces) == "1")
    #expect(lines.last == Self.odd)
  }

  @Test func `Cursor gets a deeplink with the server as base64 JSON`() {
    let install = AgentSetup.install(.cursor, cli: Self.cli)
    let config = "eyJjb21tYW5kIjoiL0FwcGxpY2F0aW9ucy9QZW9ueS5hcHAvQ29udGVudHMvSGVscGVycy9wZW9ueSIsImFyZ3MiOlsibWNwIl19"
    #expect(install == .link(
      URL(string: "cursor://anysphere.cursor-deeplink/mcp/install?name=peony&config=\(config)")!,
      entry: #"{"mcpServers":{"peony":{"command":"/Applications/Peony.app/Contents/Helpers/peony","args":["mcp"]}}}"#))
  }

  @Test func `the deeplink's config decodes back to the exact path, padding and all`() throws {
    let path = #"/Users/o'neil/My "Apps"/Peony.app/Contents/Helpers/peony"#
    guard case .link(let url, _) = AgentSetup.install(.cursor, cli: path) else {
      Issue.record("Cursor should get a link")
      return
    }
    let query = try #require(url.query(percentEncoded: true))
    #expect(query.filter { $0 == "=" || $0 == "+" || $0 == "/" } == "==", "base64's + / = are percent-encoded")
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.first { $0.name == "name" }?.value == "peony")
    let base64 = try #require(items.first { $0.name == "config" }?.value)
    let json = try #require(Data(base64Encoded: base64))
    let config = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
    #expect(config["command"] as? String == path)
    #expect(config["args"] as? [String] == ["mcp"])
  }
}
