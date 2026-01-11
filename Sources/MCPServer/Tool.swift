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
    ///
    /// Validates arguments against the tool's schema before execution.
    public func call(
        name: String,
        arguments: [String: JSONValue],
        context: Context,
        validate: Bool = true
    ) async throws -> String {
        guard let tool = tools[name] else {
            throw ToolError("Unknown tool: \(name)")
        }

        if validate {
            try SchemaValidator.validate(arguments: arguments, against: tool.inputSchema)
        }

        return try await tool.execute(arguments: arguments, context: context)
    }
}

// MARK: - Schema Validator

/// Validates arguments against a JSON Schema.
public enum SchemaValidator {

    /// Validate arguments against a schema.
    /// Throws `ToolError` if validation fails.
    public static func validate(arguments: [String: JSONValue], against schema: JSONValue) throws {
        // Get schema type - must be object for tool inputs
        guard schema["type"]?.stringValue == "object" else {
            return // Can't validate non-object schemas
        }

        // Check required fields
        if let requiredArray = schema["required"]?.arrayValue {
            let requiredFields = requiredArray.compactMap { $0.stringValue }
            for field in requiredFields {
                if arguments[field] == nil {
                    throw ToolError("Missing required argument: \(field)")
                }
            }
        }

        // Get properties schema
        guard let properties = schema["properties"]?.objectValue else {
            return // No properties to validate
        }

        // Validate each provided argument against its schema
        for (key, value) in arguments {
            guard let propSchema = properties[key] else {
                continue // Extra arguments are allowed
            }

            try validateValue(value, against: propSchema, path: key)
        }
    }

    private static func validateValue(_ value: JSONValue, against schema: JSONValue, path: String) throws {
        guard let expectedType = schema["type"]?.stringValue else {
            return // No type constraint
        }

        let actualType = jsonValueType(value)

        // Check type match (with numeric coercion)
        switch expectedType {
        case "string":
            guard case .string = value else {
                throw ToolError("Invalid type for '\(path)': expected string, got \(actualType)")
            }
            // Check enum constraint
            if let enumValues = schema["enum"]?.arrayValue {
                let allowed = enumValues.compactMap { $0.stringValue }
                if let strValue = value.stringValue, !allowed.contains(strValue) {
                    throw ToolError("Invalid value for '\(path)': must be one of \(allowed.joined(separator: ", "))")
                }
            }

        case "integer":
            // Accept both int and double that are whole numbers
            switch value {
            case .int(let n):
                try validateNumericBounds(Double(n), schema: schema, path: path)
            case .double(let n) where n.truncatingRemainder(dividingBy: 1) == 0:
                try validateNumericBounds(n, schema: schema, path: path)
            default:
                throw ToolError("Invalid type for '\(path)': expected integer, got \(actualType)")
            }

        case "number":
            // Accept both int and double
            switch value {
            case .int(let n):
                try validateNumericBounds(Double(n), schema: schema, path: path)
            case .double(let n):
                try validateNumericBounds(n, schema: schema, path: path)
            default:
                throw ToolError("Invalid type for '\(path)': expected number, got \(actualType)")
            }

        case "boolean":
            guard case .bool = value else {
                throw ToolError("Invalid type for '\(path)': expected boolean, got \(actualType)")
            }

        case "array":
            guard case .array(let items) = value else {
                throw ToolError("Invalid type for '\(path)': expected array, got \(actualType)")
            }
            // Validate array items if schema specifies
            if let itemSchema = schema["items"] {
                for (index, item) in items.enumerated() {
                    try validateValue(item, against: itemSchema, path: "\(path)[\(index)]")
                }
            }

        case "object":
            guard case .object = value else {
                throw ToolError("Invalid type for '\(path)': expected object, got \(actualType)")
            }

        default:
            break // Unknown type, skip validation
        }
    }

    private static func validateNumericBounds(_ value: Double, schema: JSONValue, path: String) throws {
        if let min = schema["minimum"]?.doubleValue ?? schema["minimum"]?.intValue.map(Double.init) {
            if value < min {
                throw ToolError("Value for '\(path)' must be >= \(min)")
            }
        }
        if let max = schema["maximum"]?.doubleValue ?? schema["maximum"]?.intValue.map(Double.init) {
            if value > max {
                throw ToolError("Value for '\(path)' must be <= \(max)")
            }
        }
    }

    private static func jsonValueType(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool: return "boolean"
        case .int: return "integer"
        case .double: return "number"
        case .string: return "string"
        case .array: return "array"
        case .object: return "object"
        }
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

    /// Alias for `integer()` - convenient for migrations.
    public static func int(description: String? = nil, minimum: Int? = nil, maximum: Int? = nil) -> JSONValue {
        integer(description: description, minimum: minimum, maximum: maximum)
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

    /// Alias for `boolean()` - convenient for migrations.
    public static func bool(description: String? = nil) -> JSONValue {
        boolean(description: description)
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
