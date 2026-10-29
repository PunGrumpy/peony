import Foundation
import Testing
@testable import PeonyCore

/// What an agent sees of Peony: the tool list and each tool's name, schema and annotations are the
/// contract, so the golden JSON here changes only when the tools do.
struct MCPTests {
  typealias Tunnel = ControlSnapshot.Tunnel

  static let server = MCPServer(version: "1.2.3")
  static let done = ControlReply.answered(.done, ControlSnapshot(tunnel: .on(ControlTests.officeRef, address: "10.0.0.5", since: nil, hosts: []), vpns: [ControlTests.office]))
  static let failed = ControlReply.answered(.failed, ControlSnapshot(
    tunnel: .failed(ControlTests.officeRef, .init(
      message: "The FortiGate's certificate isn't trusted.",
      fix: .init(kind: .trustCertificate, title: "Trust this certificate in Peony"))),
    vpns: [ControlTests.office]))

  /// The client's side of one exchange: the reply as JSON, and the requests the server made of the app.
  private func exchange(_ message: String, answering reply: ControlReply = done) async throws -> (response: JSON?, requests: [ControlRequest]) {
    var requests: [ControlRequest] = []
    let data = await Self.server.handle(Data(message.utf8)) { request in
      requests.append(request)
      return reply
    }
    guard let data else { return (nil, requests) }
    #expect(data.last == UInt8(ascii: "\n") && !data.dropLast().contains(UInt8(ascii: "\n")), "a reply is exactly one line")
    return (try JSONDecoder().decode(JSON.self, from: data), requests)
  }

  private func call(_ name: String, _ arguments: String = "{}", answering reply: ControlReply = done) async throws -> (response: JSON, requests: [ControlRequest]) {
    let (response, requests) = try await exchange(
      #"{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"\#(name)","arguments":\#(arguments)}}"#, answering: reply)
    return (try #require(response), requests)
  }

  private func result(_ response: JSON) throws -> [String: JSON] {
    try #require(response.object?["result"]?.object)
  }

  private func text(_ result: [String: JSON]) throws -> String {
    guard case .array(let content)? = result["content"], case .string(let text)? = content.first?.object?["text"] else {
      throw ExpectationFailed()
    }
    return text
  }

  private struct ExpectationFailed: Error {}

  // MARK: Handshake

  @Test(arguments: ["2025-06-18", "2025-03-26"])
  func `initialize answers a version it supports with that same version`(version: String) async throws {
    let (response, _) = try await exchange(
      #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"\#(version)","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}"#)
    let result = try result(try #require(response))
    #expect(result["protocolVersion"] == .string(version))
  }

  @Test func `initialize answers an unknown version with the newest, and describes the server`() async throws {
    let (reply, requests) = try await exchange(
      #"{"jsonrpc":"2.0","id":"abc","method":"initialize","params":{"protocolVersion":"1999-01-01"}}"#)
    let response = try #require(reply)
    #expect(response.object?["id"] == "abc")
    #expect(response.object?["jsonrpc"] == "2.0")
    let result = try result(response)
    #expect(result["protocolVersion"] == "2025-06-18")
    #expect(result["capabilities"] == ["tools": [:]])
    #expect(result["serverInfo"] == ["name": "peony", "version": "1.2.3"])
    let instructions = try #require(result["instructions"]?.string)
    #expect(instructions.contains("one VPN on at a time") && instructions.contains("connect_vpn"))
    #expect(requests.isEmpty)
  }

  @Test func `ping answers with an empty result`() async throws {
    let (response, _) = try await exchange(#"{"jsonrpc":"2.0","id":3,"method":"ping"}"#)
    #expect(response == ["jsonrpc": "2.0", "id": 3, "result": [:]])
  }

  // MARK: Tools

  @Test func `tools/list is the golden list, apart from the prose written for the agent`() async throws {
    let data = try #require(await Self.server.handle(Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#.utf8)) { _ in Self.done })
    let tools = try #require(try result(try JSONDecoder().decode(JSON.self, from: data))["tools"])
    let golden = #"""
      [
        {
          "name": "list_vpns", "title": "List VPNs",
          "inputSchema": { "type": "object", "additionalProperties": false },
          "annotations": { "title": "List VPNs", "readOnlyHint": true, "openWorldHint": false }
        },
        {
          "name": "vpn_status", "title": "VPN status",
          "inputSchema": { "type": "object", "additionalProperties": false },
          "annotations": { "title": "VPN status", "readOnlyHint": true, "openWorldHint": false }
        },
        {
          "name": "connect_vpn", "title": "Connect a VPN",
          "inputSchema": {
            "type": "object",
            "properties": {
              "vpn": { "type": "string" },
              "timeout_seconds": { "type": "integer", "minimum": 1, "maximum": 600, "default": 90 }
            },
            "required": ["vpn"],
            "additionalProperties": false
          },
          "annotations": { "title": "Connect a VPN", "readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false }
        },
        {
          "name": "disconnect_vpn", "title": "Disconnect the VPN",
          "inputSchema": {
            "type": "object",
            "properties": {
              "timeout_seconds": { "type": "integer", "minimum": 1, "maximum": 600, "default": 30 }
            },
            "additionalProperties": false
          },
          "annotations": { "title": "Disconnect the VPN", "readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false }
        }
      ]
      """#
    #expect(tools.removing("description") == (try JSONDecoder().decode(JSON.self, from: Data(golden.utf8))))
    guard case .array(let listed) = tools else { throw ExpectationFailed() }
    for tool in listed {
      #expect((tool.object?["description"]?.string?.count ?? 0) > 80, "\(tool.object?["name"]?.string ?? "")")
    }
  }

  @Test func `every tool is annotated and takes an object`() throws {
    #expect(MCPServer.tools.map(\.name) == ["list_vpns", "vpn_status", "connect_vpn", "disconnect_vpn"])
    for tool in MCPServer.tools {
      #expect(tool.inputSchema.object?["type"] == "object", "\(tool.name)")
      #expect(tool.annotations.object?["readOnlyHint"] != nil, "\(tool.name)")
    }
  }

  @Test func `list_vpns and vpn_status ask the app for its status`() async throws {
    for name in ["list_vpns", "vpn_status"] {
      let (_, requests) = try await call(name)
      #expect(requests == [.status], "\(name)")
    }
  }

  @Test func `connect_vpn asks for a connect and returns the CLI's JSON as text and as an object`() async throws {
    let (response, requests) = try await call("connect_vpn", #"{"vpn":"Office"}"#)
    #expect(requests == [.connect(vpn: "Office", wait: .connect)])
    #expect(response.object?["id"] == 7)
    let result = try result(response)
    #expect(result["isError"] == false)
    let text = try text(result)
    #expect(text == Control.envelope(Self.done))
    let structured = try #require(result["structuredContent"])
    #expect(structured == (try JSONDecoder().decode(JSON.self, from: Data(text.utf8))))
    #expect(structured.object?["outcome"] == "done")
    #expect(structured.object?["tunnel"]?.object?["state"] == "on")
  }

  @Test func `connect_vpn passes its timeout on, and disconnect_vpn has its own default`() async throws {
    let (_, connect) = try await call("connect_vpn", #"{"vpn":"Home","timeout_seconds":600}"#)
    #expect(connect == [.connect(vpn: "Home", wait: try #require(WaitLimit(seconds: 600)))])
    let (_, disconnect) = try await call("disconnect_vpn")
    #expect(disconnect == [.disconnect(wait: .disconnect)])
    let (_, patient) = try await call("disconnect_vpn", #"{"timeout_seconds":1}"#)
    #expect(patient == [.disconnect(wait: try #require(WaitLimit(seconds: 1)))])
  }

  @Test func `a failed connect is an error that still says why and how to fix it`() async throws {
    let (response, _) = try await call("connect_vpn", #"{"vpn":"Office"}"#, answering: Self.failed)
    let result = try result(response)
    #expect(result["isError"] == true)
    let text = try text(result)
    #expect(text.contains("The FortiGate's certificate isn't trusted."))
    #expect(text.contains("Trust this certificate in Peony"))
    #expect(result["structuredContent"]?.object?["tunnel"]?.object?["failure"]?.object?["message"] == "The FortiGate's certificate isn't trusted.")
  }

  @Test func `a refusal is an error with the envelope's message`() async throws {
    let refusal = ControlReply.refused(.noSuchVPN(query: "nope", vpns: [ControlTests.office]))
    let (response, _) = try await call("connect_vpn", #"{"vpn":"nope"}"#, answering: refusal)
    let result = try result(response)
    #expect(result["isError"] == true)
    #expect(try text(result).contains("No VPN is named"))
    #expect(result["structuredContent"]?.object?["error"]?.object?["code"] == "noSuchVPN")
  }

  @Test func `status while Peony isn't running is an error that says so`() async throws {
    let (response, _) = try await call("vpn_status", answering: .refused(.notRunning))
    let result = try result(response)
    #expect(result["isError"] == true)
    #expect(try text(result).contains("Peony isn't running."))
    #expect(result["structuredContent"]?.object?["error"]?.object?["code"] == "notRunning")
  }

  @Test(arguments: [ControlOutcome.timedOut, .interrupted, .failed])
  func `every outcome the CLI exits non-zero for is an error`(outcome: ControlOutcome) async throws {
    let reply = ControlReply.answered(outcome, ControlSnapshot(tunnel: .off, vpns: []))
    let (response, _) = try await call("disconnect_vpn", answering: reply)
    #expect(try result(response)["isError"] == true)
    #expect(reply.exitCode != 0)
  }

  // MARK: Bad requests

  @Test(arguments: [
    "{}",
    #"{"vpn":""}"#,
    #"{"vpn":"  "}"#,
    #"{"vpn":7}"#,
    #"{"vpn":"Office","timeout_seconds":0}"#,
    #"{"vpn":"Office","timeout_seconds":601}"#,
    #"{"vpn":"Office","timeout_seconds":"30"}"#,
    #"{"vpn":"Office","timeout_seconds":1.5}"#,
  ])
  func `bad arguments are a tool error, not a protocol error, and reach no app`(arguments: String) async throws {
    let (response, requests) = try await call("connect_vpn", arguments)
    let result = try result(response)
    #expect(result["isError"] == true)
    #expect(!(try text(result)).isEmpty)
    #expect(result["structuredContent"] == nil)
    #expect(requests.isEmpty)
  }

  @Test func `a timeout out of range is explained`() async throws {
    let (response, _) = try await call("disconnect_vpn", #"{"timeout_seconds":9000}"#)
    let result = try result(response)
    #expect(result["isError"] == true)
    #expect(try text(result).contains("from 1 to 600"))
  }

  @Test func `a missing vpn says what to send`() async throws {
    let (response, _) = try await call("connect_vpn")
    #expect(try text(try result(response)).contains("list_vpns"))
  }

  @Test func `an unknown tool is invalid params, and lists the real ones`() async throws {
    let (response, requests) = try await call("reboot_router")
    let error = try #require(response.object?["error"]?.object)
    #expect(error["code"] == -32602)
    #expect(try #require(error["message"]?.string).contains("connect_vpn"))
    #expect(response.object?["result"] == nil)
    #expect(requests.isEmpty)
  }

  @Test(arguments: [
    #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{}}"#,
    #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"vpn_status","arguments":[]}}"#,
  ])
  func `a tools/call that isn't well formed is invalid params`(message: String) async throws {
    let (response, requests) = try await exchange(message)
    #expect(try #require(response).object?["error"]?.object?["code"] == -32602)
    #expect(requests.isEmpty)
  }

  @Test func `an unknown method is method not found, keeping the caller's id`() async throws {
    let (reply, _) = try await exchange(#"{"jsonrpc":"2.0","id":"x-1","method":"resources/list"}"#)
    let response = try #require(reply)
    #expect(response.object?["id"] == "x-1")
    #expect(response.object?["error"]?.object?["code"] == -32601)
  }

  @Test(arguments: [
    #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
    #"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":1}}"#,
    #"{"jsonrpc":"2.0","method":"resources/list"}"#,
    #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"disconnect_vpn"}}"#,
    #"{"jsonrpc":"2.0","id":1,"result":{}}"#,
  ])
  func `a notification gets no reply, and a call without an id runs nothing`(message: String) async throws {
    let (response, requests) = try await exchange(message)
    #expect(response == nil)
    #expect(requests.isEmpty)
  }

  @Test func `text that isn't JSON is a parse error`() async throws {
    let (response, _) = try await exchange("{not json")
    #expect(response == ["jsonrpc": "2.0", "id": .null, "error": ["code": -32700, "message": "Parse error"]])
  }

  @Test func `JSON that isn't a request is invalid`() async throws {
    for message in ["[]", "7", #"{"jsonrpc":"2.0","id":1}"#] {
      let (response, _) = try await exchange(message)
      #expect(try #require(response).object?["error"]?.object?["code"] == -32600, "\(message)")
    }
  }
}

private extension JSON {
  /// Every field with this key removed, at any depth.
  func removing(_ key: String) -> JSON {
    switch self {
    case .object(let fields): .object(fields.filter { $0.key != key }.mapValues { $0.removing(key) })
    case .array(let elements): .array(elements.map { $0.removing(key) })
    default: self
    }
  }
}
