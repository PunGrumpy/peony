import Foundation
import PeonyCore

/// `peony mcp`: one JSON-RPC message per line on stdin, replies on stdout and nothing else there, until
/// the client closes stdin. The protocol itself lives in PeonyCore.
func serveMCP() async {
  let server = MCPServer(version: appVersion())
  while let line = readLine() {
    guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
          let reply = await server.handle(Data(line.utf8), call: send)
    else { continue }
    FileHandle.standardOutput.write(reply)
  }
}

/// The version of the Peony.app this binary ships in.
private func appVersion() -> String {
  guard let app = containingApp(),
        let info = NSDictionary(contentsOf: app.appending(path: "Contents/Info.plist")),
        let version = info["CFBundleShortVersionString"] as? String
  else { return "unknown" }
  return version
}
