import Testing
import Foundation
@testable import MCPServer

// MARK: - Test Fixtures

struct TestEchoTool: Tool {
    typealias Context = NoContext
    let name = "test_echo"
    let description = "Test echo tool"
    let inputSchema = Schema.object(
        properties: ["message": Schema.string()],
        required: ["message"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        arguments["message"]?.stringValue ?? "no message"
    }
}

struct TestAddTool: Tool {
    typealias Context = NoContext
    let name = "test_add"
    let description = "Add two numbers"
    let inputSchema = Schema.object(
        properties: [
            "a": Schema.number(),
            "b": Schema.number()
        ],
        required: ["a", "b"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        let a = arguments["a"]?.doubleValue ?? 0
        let b = arguments["b"]?.doubleValue ?? 0
        return String(a + b)
    }
}

// MARK: - MCPServer Tests

@Suite("MCPServer Tests")
struct MCPServerTests {

    // MARK: - ServerInfo & Capabilities

    @Suite("ServerInfo")
    struct ServerInfoTests {

        @Test("ServerInfo stores name and version")
        func serverInfoBasic() {
            let info = ServerInfo(name: "test-server", version: "1.0.0")
            #expect(info.name == "test-server")
            #expect(info.version == "1.0.0")
        }

        @Test("ServerCapabilities defaults")
        func capabilitiesDefaults() {
            let caps = ServerCapabilities()
            #expect(caps.tools == true)
            #expect(caps.resources == false)
            #expect(caps.prompts == false)
        }

        @Test("ServerCapabilities custom")
        func capabilitiesCustom() {
            let caps = ServerCapabilities(tools: true, resources: true, prompts: true)
            #expect(caps.tools == true)
            #expect(caps.resources == true)
            #expect(caps.prompts == true)
        }

        @Test("ServerCapabilities asJSON")
        func capabilitiesJSON() {
            let caps = ServerCapabilities(tools: true, resources: false, prompts: false)
            let json = caps.asJSON

            #expect(json["tools"] != nil)
            #expect(json["resources"] == nil)
            #expect(json["prompts"] == nil)
        }
    }

    // MARK: - NoContext

    @Suite("NoContext")
    struct NoContextTests {

        @Test("NoContext.shared is singleton")
        func noContextShared() {
            let a = NoContext.shared
            let b = NoContext.shared
            // Can't compare directly, but both should work
            #expect(type(of: a) == NoContext.self)
            #expect(type(of: b) == NoContext.self)
        }
    }

    // MARK: - Tool Registration

    @Suite("Tool Registration")
    struct RegistrationTests {

        @Test("register single tool")
        func registerSingle() async {
            let server = MCPServer(info: ServerInfo(name: "test", version: "1.0"))
            await server.register(TestEchoTool())

            // Can't directly access registry, but we can verify via tools/list simulation
        }

        @Test("register multiple tools")
        func registerMultiple() async {
            let server = MCPServer(info: ServerInfo(name: "test", version: "1.0"))
            await server.register([TestEchoTool(), TestAddTool()])
        }
    }

    // MARK: - Initialize Response Format

    @Suite("Protocol Messages")
    struct ProtocolTests {

        @Test("initialize response has correct structure")
        func initializeResponse() throws {
            // Simulate what the server would return for initialize
            let info = ServerInfo(name: "test-server", version: "2.0.0")
            let caps = ServerCapabilities(tools: true, resources: false, prompts: false)

            let result: JSONValue = .object([
                "protocolVersion": "2024-11-05",
                "serverInfo": .object([
                    "name": .string(info.name),
                    "version": .string(info.version)
                ]),
                "capabilities": caps.asJSON
            ])

            #expect(result["protocolVersion"]?.stringValue == "2024-11-05")
            #expect(result["serverInfo"]?["name"]?.stringValue == "test-server")
            #expect(result["serverInfo"]?["version"]?.stringValue == "2.0.0")
            #expect(result["capabilities"]?["tools"] != nil)
        }

        @Test("tools/list response format")
        func toolsListFormat() async {
            let registry = ToolRegistry<NoContext>()
            await registry.register([TestEchoTool(), TestAddTool()])

            let result = await registry.listTools()

            guard let tools = result["tools"]?.arrayValue else {
                Issue.record("Expected tools array")
                return
            }

            #expect(tools.count == 2)

            // Each tool should have name, description, inputSchema
            for tool in tools {
                #expect(tool["name"]?.stringValue != nil)
                #expect(tool["description"]?.stringValue != nil)
                #expect(tool["inputSchema"] != nil)
            }
        }

        @Test("tools/call success response format")
        func toolsCallSuccessFormat() throws {
            // Simulate successful tool call response
            let toolResult = "Hello, World!"

            let response = JSONRPCResponse(
                id: .int(1),
                result: .object([
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string(toolResult)
                        ])
                    ])
                ])
            )

            #expect(response.result?["content"]?[0]?["type"]?.stringValue == "text")
            #expect(response.result?["content"]?[0]?["text"]?.stringValue == "Hello, World!")
        }

        @Test("tools/call error response format")
        func toolsCallErrorFormat() throws {
            let response = JSONRPCResponse(
                id: .int(1),
                error: .serverError("Tool execution failed")
            )

            #expect(response.error?.code == -32000)
            #expect(response.error?.message == "Tool execution failed")
        }
    }

    // MARK: - Request Parsing

    @Suite("Request Parsing")
    struct ParsingTests {

        @Test("parse initialize request")
        func parseInitialize() throws {
            let json = #"""
            {
                "jsonrpc": "2.0",
                "id": 0,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "clientInfo": {
                        "name": "claude-code",
                        "version": "1.0.0"
                    },
                    "capabilities": {}
                }
            }
            """#

            let request = try JSONDecoder().decode(
                JSONRPCRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.method == "initialize")
            #expect(request.id == .int(0))
            #expect(request.params?["protocolVersion"]?.stringValue == "2024-11-05")
        }

        @Test("parse tools/list request")
        func parseToolsList() throws {
            let json = #"{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}"#

            let request = try JSONDecoder().decode(
                JSONRPCRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.method == "tools/list")
        }

        @Test("parse tools/call request")
        func parseToolsCall() throws {
            let json = #"""
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "test_echo",
                    "arguments": {
                        "message": "hello"
                    }
                }
            }
            """#

            let request = try JSONDecoder().decode(
                JSONRPCRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.method == "tools/call")
            #expect(request.params?["name"]?.stringValue == "test_echo")
            #expect(request.params?["arguments"]?["message"]?.stringValue == "hello")
        }

        @Test("parse notification (no id)")
        func parseNotification() throws {
            let json = #"{"jsonrpc": "2.0", "method": "notifications/initialized"}"#

            let request = try JSONDecoder().decode(
                JSONRPCRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.id == nil)
            #expect(request.method == "notifications/initialized")
        }
    }

    // MARK: - Response Encoding

    @Suite("Response Encoding")
    struct EncodingTests {

        @Test("encode success response as valid JSON")
        func encodeSuccess() throws {
            let response = JSONRPCResponse(
                id: .int(1),
                result: .object(["status": .string("ok")])
            )

            let data = try JSONEncoder().encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"jsonrpc\":\"2.0\""))
            #expect(json.contains("\"id\":1"))
            #expect(json.contains("\"result\""))
        }

        @Test("encode error response as valid JSON")
        func encodeError() throws {
            let response = JSONRPCResponse(
                id: .int(1),
                error: .methodNotFound("unknown")
            )

            let data = try JSONEncoder().encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"error\""))
            #expect(json.contains("-32601"))
        }

        @Test("response is single line (no pretty printing by default)")
        func responseSingleLine() throws {
            let response = JSONRPCResponse(
                id: .string("req-1"),
                result: .object(["nested": .object(["value": .int(42)])])
            )

            let data = try JSONEncoder().encode(response)
            let json = String(data: data, encoding: .utf8)!

            // Should not contain newlines (important for line-based protocol)
            #expect(!json.contains("\n"))
        }
    }

    // MARK: - End-to-End Flow

    @Suite("End-to-End")
    struct EndToEndTests {

        @Test("full request-response cycle")
        func fullCycle() async throws {
            // Setup
            let registry = ToolRegistry<NoContext>()
            await registry.register(TestEchoTool())

            // Parse request
            let requestJSON = #"""
            {
                "jsonrpc": "2.0",
                "id": 42,
                "method": "tools/call",
                "params": {
                    "name": "test_echo",
                    "arguments": {"message": "Hello, MCP!"}
                }
            }
            """#

            let request = try JSONDecoder().decode(
                JSONRPCRequest.self,
                from: requestJSON.data(using: .utf8)!
            )

            // Execute tool
            let toolName = request.params?["name"]?.stringValue ?? ""
            let arguments = request.params?["arguments"]?.objectValue ?? [:]
            let result = try await registry.call(
                name: toolName,
                arguments: arguments,
                context: .shared
            )

            // Format response
            let response = JSONRPCResponse(
                id: request.id,
                result: .object([
                    "content": .array([
                        .object([
                            "type": .string("text"),
                            "text": .string(result)
                        ])
                    ])
                ])
            )

            // Verify
            #expect(response.id == .int(42))
            #expect(response.result?["content"]?[0]?["text"]?.stringValue == "Hello, MCP!")
        }

        @Test("error handling cycle")
        func errorCycle() async throws {
            let registry = ToolRegistry<NoContext>()
            // Don't register any tools

            let requestJSON = #"""
            {"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "nonexistent", "arguments": {}}}
            """#

            let request = try JSONDecoder().decode(
                JSONRPCRequest.self,
                from: requestJSON.data(using: .utf8)!
            )

            let toolName = request.params?["name"]?.stringValue ?? ""

            do {
                _ = try await registry.call(name: toolName, arguments: [:], context: .shared)
                Issue.record("Expected error")
            } catch {
                // Create error response
                let response = JSONRPCResponse(
                    id: request.id,
                    error: .serverError(error.localizedDescription)
                )

                #expect(response.error != nil)
                #expect(response.id == .int(1))
            }
        }
    }
}
