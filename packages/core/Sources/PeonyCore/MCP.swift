import Foundation

/// `peony mcp`: the Model Context Protocol, so an agent lists Peony's tools beside its own instead of
/// shelling out. One line of JSON-RPC in, at most one line out, with the work done by the same
/// `ControlRequest` the command line sends. The transport (stdin and stdout) stays in the CLI.
///
/// The tools are a subset of `Control`, on purpose: secrets, certificate trust and editing VPNs aren't
/// reachable from here either.
public struct MCPServer: Sendable {
  /// Newest first. A client that asks for another version is answered with the first.
  static let protocolVersions = ["2025-06-18", "2025-03-26"]

  static let instructions = """
    Peony is a macOS menu-bar VPN switcher. It keeps one VPN on at a time. connect_vpn turns any other \
    VPN off, then waits until the chosen one is on and its hosts have been checked, so a result of \
    "done" means the network is ready. Certificate trust and adding or editing VPNs happen in the \
    Peony app: when a failure's fix names a button, tell the user to press it there. Start with \
    vpn_status or list_vpns.
    """

  /// The app's version, reported as the server's.
  public let version: String

  public init(version: String) {
    self.version = version
  }

  /// The reply to one line from the client, newline included, or nil when none is owed: a
  /// notification, or a response to something the server never asked.
  public func handle(_ line: Data, call: (ControlRequest) async -> ControlReply) async -> Data? {
    guard let message = try? JSONDecoder().decode(JSON.self, from: line) else {
      return Self.failure(.null, code: -32700, "Parse error")
    }
    guard case .object(let fields) = message else {
      return Self.failure(.null, code: -32600, "Invalid Request")
    }
    guard let id = fields["id"] else { return nil }
    guard case .string(let method)? = fields["method"] else {
      return fields["result"] != nil || fields["error"] != nil ? nil : Self.failure(id, code: -32600, "Invalid Request")
    }
    let params = fields["params"]?.object ?? [:]

    switch method {
    case "initialize":
      let asked = params["protocolVersion"]?.string
      return Self.success(id, [
        "protocolVersion": .string(asked.flatMap { Self.protocolVersions.contains($0) ? $0 : nil } ?? Self.protocolVersions[0]),
        "capabilities": ["tools": [:]],
        "serverInfo": ["name": "peony", "version": .string(version)],
        "instructions": .string(Self.instructions),
      ])
    case "ping":
      return Self.success(id, [:])
    case "tools/list":
      return Self.success(id, ["tools": .array(Self.tools.map(\.listing))])
    case "tools/call":
      guard let name = params["name"]?.string else { return Self.failure(id, code: -32602, "tools/call needs the name of a tool.") }
      guard let tool = Self.tools.first(where: { $0.name == name }) else {
        return Self.failure(id, code: -32602, "Unknown tool \"\(name)\". Available: \(Self.tools.map(\.name).joined(separator: ", ")).")
      }
      let arguments: [String: JSON]
      switch params["arguments"] {
      case nil, .null?: arguments = [:]
      case .object(let object)?: arguments = object
      default: return Self.failure(id, code: -32602, "A tool's arguments must be an object.")
      }
      let request: ControlRequest
      do {
        request = try tool.request(arguments)
      } catch {
        return Self.success(id, .object(Self.content(text: error.message, isError: true)))
      }
      return Self.success(id, Self.result(await call(request)))
    default:
      return Self.failure(id, code: -32601, "Method not found: \(method)")
    }
  }

  // MARK: Tools

  struct Tool: Sendable {
    var name: String
    var title: String
    var description: String
    var inputSchema: JSON
    var annotations: JSON
    var request: @Sendable ([String: JSON]) throws(ArgumentError) -> ControlRequest

    var listing: JSON {
      ["name": .string(name), "title": .string(title), "description": .string(description), "inputSchema": inputSchema, "annotations": annotations]
    }
  }

  /// A tool call whose arguments don't fit the schema. The agent reads the message, so it says what to send.
  struct ArgumentError: Error {
    var message: String
  }

  /// The one list `tools/list` shows and `tools/call` runs.
  static let tools: [Tool] = [
    Tool(
      name: "list_vpns",
      title: "List VPNs",
      description: """
        List the VPNs saved in Peony, each with its id, name, kind, endpoint and the hosts Peony checks \
        once it is on, and which one is active. Use it to find the exact name or id for connect_vpn. \
        Never changes the tunnel and never opens Peony: if Peony isn't running it fails with notRunning.
        """,
      inputSchema: noInput,
      annotations: annotations(title: "List VPNs", readOnly: true),
      request: { _ in .status }),
    Tool(
      name: "vpn_status",
      title: "VPN status",
      description: """
        Report the tunnel right now: off, connecting, on, disconnecting or failed. When on, it gives the \
        address and whether each host Peony checks is reachable. When failed, it gives the message and \
        the fix. When connecting, signingIn is true while a browser sign-in waits for the user in \
        Peony's window. Use it before connect_vpn or disconnect_vpn, and after a timedOut result. \
        Never changes the tunnel and never opens Peony: if Peony isn't running it fails with notRunning.
        """,
      inputSchema: noInput,
      annotations: annotations(title: "VPN status", readOnly: true),
      request: { _ in .status }),
    Tool(
      name: "connect_vpn",
      title: "Connect a VPN",
      description: """
        Connect a VPN saved in Peony. Peony keeps one VPN on at a time, so this turns any other VPN off \
        first. It then waits until the VPN is on and each of its hosts has been checked, or it fails, or \
        timeout_seconds runs out. Opens Peony if it isn't running. Safe to repeat: connecting the VPN \
        that is already on changes nothing. The outcome is done, failed (read tunnel.failure.message \
        and its fix; a fix with a command is something to run), timedOut (it may still be coming up, so \
        call vpn_status) or interrupted (someone else changed the tunnel). Trusting a certificate and \
        editing a VPN happen in the Peony app, so tell the user when a fix needs that.
        """,
      inputSchema: [
        "type": "object",
        "properties": [
          "vpn": ["type": "string", "description": "The VPN's name, matched exactly and ignoring case, or its id. Both come from list_vpns."],
          "timeout_seconds": timeoutSchema(default: .connect),
        ],
        "required": ["vpn"],
        "additionalProperties": false,
      ],
      annotations: annotations(title: "Connect a VPN", readOnly: false, destructive: false, idempotent: true),
      request: { arguments throws(ArgumentError) in
        guard let vpn = arguments["vpn"]?.string, !vpn.trimmingCharacters(in: .whitespaces).isEmpty else {
          throw ArgumentError(message: "vpn is required: the name or id of a VPN from list_vpns.")
        }
        return .connect(vpn: vpn, wait: try wait(arguments, default: .connect))
      }),
    Tool(
      name: "disconnect_vpn",
      title: "Disconnect the VPN",
      description: """
        Turn the active VPN off and wait until it is off, or timeout_seconds runs out. Opens Peony if it \
        isn't running. Safe to repeat: with no VPN on it changes nothing, and it clears a failed \
        connection so vpn_status stops reporting it.
        """,
      inputSchema: [
        "type": "object",
        "properties": ["timeout_seconds": timeoutSchema(default: .disconnect)],
        "additionalProperties": false,
      ],
      annotations: annotations(title: "Disconnect the VPN", readOnly: false, destructive: false, idempotent: true),
      request: { arguments throws(ArgumentError) in .disconnect(wait: try wait(arguments, default: .disconnect)) }),
  ]

  private static let noInput: JSON = ["type": "object", "additionalProperties": false]

  private static func annotations(title: String, readOnly: Bool, destructive: Bool? = nil, idempotent: Bool? = nil) -> JSON {
    var hints: [String: JSON] = ["title": .string(title), "readOnlyHint": .bool(readOnly), "openWorldHint": false]
    if let destructive { hints["destructiveHint"] = .bool(destructive) }
    if let idempotent { hints["idempotentHint"] = .bool(idempotent) }
    return .object(hints)
  }

  private static func timeoutSchema(default limit: WaitLimit) -> JSON {
    [
      "type": "integer",
      "minimum": .int(WaitLimit.range.lowerBound),
      "maximum": .int(WaitLimit.range.upperBound),
      "default": .int(limit.seconds),
      "description": "How many seconds to wait for the tunnel to settle.",
    ]
  }

  private static func wait(_ arguments: [String: JSON], default limit: WaitLimit) throws(ArgumentError) -> WaitLimit {
    switch arguments["timeout_seconds"] {
    case nil, .null?:
      return limit
    case .int(let seconds)?:
      if let wait = WaitLimit(seconds: seconds) { return wait }
    default:
      break
    }
    throw ArgumentError(message: "timeout_seconds must be a whole number of seconds from \(WaitLimit.range.lowerBound) to \(WaitLimit.range.upperBound).")
  }

  // MARK: Replies

  /// The same JSON the CLI prints with `--json`, as text for any client and as an object for those
  /// that read `structuredContent`. A reply the CLI would exit non-zero for is an error, with the
  /// failure and its fix still in the text.
  private static func result(_ reply: ControlReply) -> JSON {
    let text = Control.envelope(reply)
    var fields = content(text: text, isError: reply.exitCode != 0)
    if let envelope = try? JSONDecoder().decode(JSON.self, from: Data(text.utf8)) {
      fields["structuredContent"] = envelope
    }
    return .object(fields)
  }

  private static func content(text: String, isError: Bool) -> [String: JSON] {
    ["content": [["type": "text", "text": .string(text)]], "isError": .bool(isError)]
  }

  private static func success(_ id: JSON, _ result: JSON) -> Data? {
    try? Control.line(["jsonrpc": "2.0", "id": id, "result": result] as JSON)
  }

  private static func failure(_ id: JSON, code: Int, _ message: String) -> Data? {
    try? Control.line(["jsonrpc": "2.0", "id": id, "error": ["code": .int(code), "message": .string(message)]] as JSON)
  }
}

/// Any JSON value, so a request's `id` and `params` are echoed and read without a type per method.
enum JSON: Equatable, Sendable {
  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case array([JSON])
  case object([String: JSON])

  var string: String? {
    if case .string(let value) = self { value } else { nil }
  }

  var object: [String: JSON]? {
    if case .object(let value) = self { value } else { nil }
  }
}

extension JSON: Codable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSON].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSON].self))
    }
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .int(let value): try container.encode(value)
    case .double(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
}

extension JSON: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral,
  ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
  init(booleanLiteral value: Bool) { self = .bool(value) }
  init(integerLiteral value: Int) { self = .int(value) }
  init(stringLiteral value: String) { self = .string(value) }
  init(arrayLiteral elements: JSON...) { self = .array(elements) }
  init(dictionaryLiteral elements: (String, JSON)...) { self = .object(Dictionary(elements, uniquingKeysWith: { $1 })) }
}
