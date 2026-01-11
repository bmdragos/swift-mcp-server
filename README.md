# swift-mcp-server

A Swift library for building local MCP (Model Context Protocol) servers.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/bmdragos/swift-mcp-server", branch: "main"),
]

// Target using the macro (recommended)
.target(name: "MyServer", dependencies: [
    .product(name: "MCPServerMacros", package: "swift-mcp-server"),
])

// Or just the core library
.target(name: "MyServer", dependencies: [
    .product(name: "MCPServer", package: "swift-mcp-server"),
])
```

## Quick Start with @MCPTool Macro

The `@MCPTool` macro eliminates boilerplate - just write a `run()` function:

```swift
import MCPServerMacros

@MCPTool("greet", "Greet someone by name")
struct GreetTool {
    func run(name: String, enthusiastic: Bool = false, context: NoContext) async throws -> String {
        let greeting = "Hello, \(name)!"
        return enthusiastic ? greeting.uppercased() : greeting
    }
}

// That's it! The macro generates:
// - name, description properties
// - inputSchema from parameter types
// - execute() wrapper that unpacks arguments and calls run()

let server = MCPServer(info: ServerInfo(name: "my-server", version: "1.0.0"))
await server.register(GreetTool())
await server.run()
```

### Supported Parameter Types

| Swift Type | JSON Schema | Notes |
|------------|-------------|-------|
| `String` | `string` | |
| `Int` | `integer` | With optional min/max |
| `Double` | `number` | |
| `Bool` | `boolean` | |
| `Date` | `string` | ISO8601 format |
| `[T]` | `array` | Array of any supported type |
| `T?` | (not required) | Optional parameters |
| `T = value` | (not required) | Parameters with defaults |
| `MyEnum` | `string` with `enum` | Requires `CaseIterable` |

### Enums

String enums automatically generate allowed values in the schema:

```swift
enum Priority: String, CaseIterable {
    case low, medium, high
}

@MCPTool("create_task", "Create a task")
struct CreateTaskTool {
    func run(title: String, priority: Priority = .medium, context: NoContext) async throws -> String {
        "Created '\(title)' with \(priority.rawValue) priority"
    }
}
// Schema: { "priority": { "type": "string", "enum": ["low", "medium", "high"] } }
```

## Manual Tool Definition

For full control, implement the `Tool` protocol directly:

```swift
import MCPServer

struct GreetTool: Tool {
    typealias Context = NoContext

    let name = "greet"
    let description = "Greet someone by name"

    var inputSchema: JSONValue {
        Schema.object(
            properties: [
                "name": Schema.string(description: "Name to greet"),
            ],
            required: ["name"]
        )
    }

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        guard let name = arguments["name"]?.stringValue else {
            throw ToolError("Missing name")
        }
        return "Hello, \(name)!"
    }
}
```

## Using Context for Shared State

For servers that need shared state (managers, connections, etc.):

```swift
// Define your context
actor MyContext {
    var counter = 0
    func increment() -> Int {
        counter += 1
        return counter
    }
}

// Tools use the context
struct CounterTool: Tool {
    typealias Context = MyContext

    let name = "counter"
    let description = "Increment and return counter"
    let inputSchema = Schema.empty

    func execute(arguments: [String: JSONValue], context: MyContext) async throws -> String {
        let value = await context.increment()
        return "Counter: \(value)"
    }
}

// Create server with context
let context = MyContext()
let server = MCPServer(info: ServerInfo(name: "counter-server", version: "1.0.0"), context: context)
await server.register(CounterTool())
await server.run()
```

## Schema Validation

Arguments are automatically validated against the tool's schema before execution:

- Required fields must be present
- Types must match (string, integer, number, boolean, array)
- Numeric bounds are enforced (`minimum`, `maximum`)
- Enum values are validated

```swift
// This tool requires count to be between 1-100
var inputSchema: JSONValue {
    Schema.object(
        properties: [
            "count": Schema.integer(minimum: 1, maximum: 100),
        ],
        required: ["count"]
    )
}
// Calling with count: 200 throws: "Value for 'count' must be <= 100"
```

To disable validation (if your tool handles it internally):
```swift
try await registry.call(name: "tool", arguments: args, context: ctx, validate: false)
```

## Schema Helpers

The `Schema` enum provides helpers for building JSON Schema:

```swift
Schema.object(
    properties: [
        "name": Schema.string(description: "User name"),
        "age": Schema.integer(minimum: 0, maximum: 150),
        "score": Schema.number(),
        "active": Schema.boolean(),
        "tags": Schema.array(items: Schema.string()),
        "level": Schema.string(enum: ["low", "medium", "high"]),
    ],
    required: ["name"]
)
```

## Grouping Tools

Use `ToolProvider` to group related tools:

```swift
struct MathTools: ToolProvider {
    typealias Context = NoContext

    var tools: [any Tool<NoContext>] {
        [AddTool(), SubtractTool(), MultiplyTool()]
    }
}

// Register all at once
await server.register(from: MathTools())
```

## API Reference

### Macro

| Type | Description |
|------|-------------|
| `@MCPTool` | Generates Tool conformance from a `run()` function |

### Core Types

| Type | Description |
|------|-------------|
| `JSONValue` | Type-safe JSON enum with Codable support |
| `JSONRPCRequest` | Incoming JSON-RPC 2.0 request |
| `JSONRPCResponse` | Outgoing JSON-RPC 2.0 response |
| `JSONRPCError` | JSON-RPC error with standard codes |

### Server

| Type | Description |
|------|-------------|
| `MCPServer<Context>` | Main server actor |
| `ServerInfo` | Server name and version |
| `ServerCapabilities` | Advertised MCP capabilities |
| `NoContext` | Placeholder for stateless servers |

### Tools

| Type | Description |
|------|-------------|
| `Tool` | Protocol for MCP tools |
| `ToolRegistry<Context>` | Registry for managing tools |
| `ToolError` | Error type for tool failures |
| `ToolProvider` | Protocol for grouping tools |
| `Schema` | Helpers for building JSON schemas |
| `SchemaValidator` | Validates arguments against schemas |

## License

MIT
