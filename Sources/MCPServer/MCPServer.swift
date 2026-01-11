import Foundation

/// Configuration for an MCP server.
public struct ServerInfo: Sendable {
    public let name: String
    public let version: String
    public let capabilities: ServerCapabilities

    public init(name: String, version: String, capabilities: ServerCapabilities = .init()) {
        self.name = name
        self.version = version
        self.capabilities = capabilities
    }
}

/// Server capabilities advertised during initialization.
public struct ServerCapabilities: Sendable {
    public let tools: Bool
    public let resources: Bool
    public let prompts: Bool

    public init(tools: Bool = true, resources: Bool = false, prompts: Bool = false) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
    }

    var asJSON: JSONValue {
        var caps: [String: JSONValue] = [:]
        if tools { caps["tools"] = .object([:]) }
        if resources { caps["resources"] = .object([:]) }
        if prompts { caps["prompts"] = .object([:]) }
        return .object(caps)
    }
}

/// Protocol for types that can provide tools to an MCP server.
public protocol ToolProvider<Context>: Sendable {
    associatedtype Context: Sendable
    var tools: [any Tool<Context>] { get }
}

/// The main MCP server that handles JSON-RPC communication over stdio.
public actor MCPServer<Context: Sendable> {
    private let info: ServerInfo
    private let registry: ToolRegistry<Context>
    private let context: Context
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(info: ServerInfo, context: Context) {
        self.info = info
        self.registry = ToolRegistry()
        self.context = context
    }

    /// Register a single tool.
    public func register(_ tool: any Tool<Context>) async {
        await registry.register(tool)
    }

    /// Register multiple tools.
    public func register(_ tools: [any Tool<Context>]) async {
        await registry.register(tools)
    }

    /// Register tools from a provider.
    public func register<P: ToolProvider>(from provider: P) async where P.Context == Context {
        await registry.register(provider.tools)
    }

    /// Run the server, reading from stdin and writing to stdout.
    public func run() async {
        // Unbuffer I/O for immediate response
        setbuf(stdout, nil)
        setbuf(stderr, nil)

        while let line = readLine() {
            guard !line.isEmpty else { continue }

            let response = await handleLine(line)
            if let response = response {
                print(response)
                fflush(stdout)
            }
        }
    }

    // MARK: - Request Handling

    private func handleLine(_ line: String) async -> String? {
        guard let data = line.data(using: .utf8) else {
            return encodeResponse(.init(id: nil, error: .parseError("Invalid UTF-8")))
        }

        let request: JSONRPCRequest
        do {
            request = try decoder.decode(JSONRPCRequest.self, from: data)
        } catch {
            return encodeResponse(.init(id: nil, error: .parseError(error.localizedDescription)))
        }

        // Notifications (no id) don't get responses
        guard let id = request.id else {
            // Handle notification silently
            await handleNotification(request)
            return nil
        }

        let response = await handleRequest(request, id: id)
        return encodeResponse(response)
    }

    private func handleNotification(_ request: JSONRPCRequest) async {
        // Handle known notifications silently
        switch request.method {
        case "notifications/initialized":
            log("Client initialized")
        case "notifications/cancelled":
            log("Request cancelled")
        default:
            log("Unknown notification: \(request.method)")
        }
    }

    private func handleRequest(_ request: JSONRPCRequest, id: RequestID) async -> JSONRPCResponse {
        switch request.method {
        case "initialize":
            return handleInitialize(id: id)

        case "tools/list":
            let tools = await registry.listTools()
            return JSONRPCResponse(id: id, result: tools)

        case "tools/call":
            return await handleToolCall(id: id, params: request.params)

        default:
            return JSONRPCResponse(id: id, error: .methodNotFound(request.method))
        }
    }

    private func handleInitialize(id: RequestID) -> JSONRPCResponse {
        let result: JSONValue = .object([
            "protocolVersion": "2024-11-05",
            "serverInfo": .object([
                "name": .string(info.name),
                "version": .string(info.version)
            ]),
            "capabilities": info.capabilities.asJSON
        ])
        return JSONRPCResponse(id: id, result: result)
    }

    private func handleToolCall(id: RequestID, params: JSONValue?) async -> JSONRPCResponse {
        guard let params = params,
              let name = params["name"]?.stringValue else {
            return JSONRPCResponse(id: id, error: .invalidParams("Missing tool name"))
        }

        let arguments: [String: JSONValue]
        if let args = params["arguments"]?.objectValue {
            arguments = args
        } else {
            arguments = [:]
        }

        do {
            let result = try await registry.call(name: name, arguments: arguments, context: context)
            return JSONRPCResponse(id: id, result: .object([
                "content": .array([
                    .object([
                        "type": "text",
                        "text": .string(result)
                    ])
                ])
            ]))
        } catch {
            return JSONRPCResponse(id: id, error: .serverError(error.localizedDescription))
        }
    }

    // MARK: - Helpers

    private func encodeResponse(_ response: JSONRPCResponse) -> String {
        do {
            let data = try encoder.encode(response)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return #"{"jsonrpc":"2.0","error":{"code":-32603,"message":"Encoding error"}}"#
        }
    }

    private func log(_ message: String) {
        fputs("[\(info.name)] \(message)\n", stderr)
    }
}

// MARK: - Convenience for Stateless Servers

/// A placeholder context for servers that don't need shared state.
public struct NoContext: Sendable {
    public static let shared = NoContext()
    private init() {}
}

extension MCPServer where Context == NoContext {
    /// Create a stateless MCP server.
    public init(info: ServerInfo) {
        self.init(info: info, context: .shared)
    }
}
