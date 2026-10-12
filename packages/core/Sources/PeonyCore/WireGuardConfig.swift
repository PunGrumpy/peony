import Foundation

/// Checks a wg-quick configuration before root ever sees it.
///
/// wg-quick runs `PreUp`, `PostUp`, `PreDown` and `PostDown` as shell commands,
/// as root. A pasted config with one of those would be a root shell for anyone
/// who can write to Peony's profiles, so they're refused outright.
public enum WireGuardConfig {
  public static let forbiddenKeys: Set<String> = ["preup", "postup", "predown", "postdown", "saveconfig"]

  public enum Problem: Error, Equatable, CustomStringConvertible {
    case empty
    case missingSection(String)
    case runsCommands(key: String, line: Int)
    case unreadableLine(Int)

    public var description: String {
      switch self {
      case .empty: "The configuration is empty."
      case .missingSection(let name): "The configuration needs an [\(name)] section."
      case .runsCommands(let key, let line):
        "Line \(line) uses \(key), which runs shell commands as root. Peony doesn't allow it; remove the line."
      case .unreadableLine(let line): "Line \(line) isn't a [Section] or a Key = Value pair."
      }
    }
  }

  /// Returns the config normalized to `\n` line endings, or throws the first problem found.
  public static func validate(_ text: String) throws(Problem) -> String {
    let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { throw .empty }

    var sections: Set<String> = []
    for (index, raw) in lines.enumerated() {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty || line.hasPrefix("#") { continue }
      if line.hasPrefix("["), line.hasSuffix("]") {
        sections.insert(line.dropFirst().dropLast().lowercased())
        continue
      }
      guard let equals = line.firstIndex(of: "=") else { throw .unreadableLine(index + 1) }
      let key = line[..<equals].trimmingCharacters(in: .whitespaces)
      if forbiddenKeys.contains(key.lowercased()) { throw .runsCommands(key: key, line: index + 1) }
    }
    guard sections.contains("interface") else { throw .missingSection("Interface") }
    guard sections.contains("peer") else { throw .missingSection("Peer") }
    return lines.joined(separator: "\n")
  }
}
