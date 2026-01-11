import Foundation

/// Errors that can be thrown by tool execution.
public struct ToolError: Error, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}

/// A tool that can be invoked via MCP.
///
/// Generic over `Context` to allow different MCP servers to pass their own
/// domain-specific dependencies (e.g., BLEManager, SerialManager, etc.)
public protocol Tool<Context>: Sendable {
    associatedtype Context

    /// Unique identifier for this tool.
    var name: String { get }

    /// Human-readable description of what this tool does.
    var description: String { get }

    /// JSON Schema describing the tool's input parameters.
    var inputSchema: JSONValue { get }

    /// Execute the tool with the given arguments.
    func execute(arguments: [String: JSONValue], context: Context) async throws -> String
}

/// Registry for managing and dispatching tools.
public actor ToolRegistry<Context: Sendable> {
    private var tools: [String: any Tool<Context>] = [:]

    public init() {}

    /// Register a tool. Overwrites any existing tool with the same name.
    public func register(_ tool: any Tool<Context>) {
        tools[tool.name] = tool
    }

    /// Register multiple tools at once.
    public func register(_ tools: [any Tool<Context>]) {
        for tool in tools {
            self.tools[tool.name] = tool
        }
    }

    /// Get all registered tool names.
    public var toolNames: [String] {
        Array(tools.keys).sorted()
    }

    /// Get a tool by name.
    public func tool(named name: String) -> (any Tool<Context>)? {
        tools[name]
    }

    /// Generate the MCP tools/list response.
    public func listTools() -> JSONValue {
        let toolList: [JSONValue] = tools.values.map { tool in
            .object([
                "name": .string(tool.name),
                "description": .string(tool.description),
                "inputSchema": tool.inputSchema
            ])
        }
        return .object(["tools": .array(toolList)])
    }

    /// Call a tool by name with the given arguments.
    public func call(
        name: String,
        arguments: [String: JSONValue],
        context: Context
    ) async throws -> String {
        guard let tool = tools[name] else {
            throw ToolError("Unknown tool: \(name)")
        }
        return try await tool.execute(arguments: arguments, context: context)
    }
}

// MARK: - Schema Builder Helpers

/// Helpers for building JSON Schema input schemas.
public enum Schema {
    /// Create an object schema with properties.
    public static func object(
        properties: [String: JSONValue],
        required: [String] = []
    ) -> JSONValue {
        var schema: [String: JSONValue] = [
            "type": "object",
            "properties": .object(properties)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        return .object(schema)
    }

    /// String property schema.
    public static func string(description: String? = nil, enum values: [String]? = nil) -> JSONValue {
        var prop: [String: JSONValue] = ["type": "string"]
        if let desc = description {
            prop["description"] = .string(desc)
        }
        if let values = values {
            prop["enum"] = .array(values.map { .string($0) })
        }
        return .object(prop)
    }

    /// Integer property schema.
    public static func integer(description: String? = nil, minimum: Int? = nil, maximum: Int? = nil) -> JSONValue {
        var prop: [String: JSONValue] = ["type": "integer"]
        if let desc = description { prop["description"] = .string(desc) }
        if let min = minimum { prop["minimum"] = .int(min) }
        if let max = maximum { prop["maximum"] = .int(max) }
        return .object(prop)
    }

    /// Number property schema.
    public static func number(description: String? = nil, minimum: Double? = nil, maximum: Double? = nil) -> JSONValue {
        var prop: [String: JSONValue] = ["type": "number"]
        if let desc = description { prop["description"] = .string(desc) }
        if let min = minimum { prop["minimum"] = .double(min) }
        if let max = maximum { prop["maximum"] = .double(max) }
        return .object(prop)
    }

    /// Boolean property schema.
    public static func boolean(description: String? = nil) -> JSONValue {
        var prop: [String: JSONValue] = ["type": "boolean"]
        if let desc = description { prop["description"] = .string(desc) }
        return .object(prop)
    }

    /// Array property schema.
    public static func array(items: JSONValue, description: String? = nil) -> JSONValue {
        var prop: [String: JSONValue] = ["type": "array", "items": items]
        if let desc = description { prop["description"] = .string(desc) }
        return .object(prop)
    }

    /// Empty object schema (no parameters).
    public static var empty: JSONValue {
        .object(["type": "object", "properties": .object([:])])
    }
}
