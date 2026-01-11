# swift-mcp-server

A Swift library for building local MCP (Model Context Protocol) servers.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-mcp-server", from: "1.0.0"),
]
```

## Quick Start

```swift
import MCPServer

// 1. Define a tool
struct GreetTool: Tool {
    typealias Context = NoContext

    let name = "greet"
    let description = "Greet someone by name"

    let inputSchema = Schema.object(
        properties: [
            "name": Schema.string(description: "Name to greet"),
        ],
        required: ["name"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        guard let name = arguments["name"]?.stringValue else {
            throw ToolError("Missing name")
        }
        return "Hello, \(name)!"
    }
}

// 2. Create and run server
let server = MCPServer(info: ServerInfo(name: "my-server", version: "1.0.0"))
await server.register(GreetTool())
await server.run()
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

## Schema Helpers

The `Schema` enum provides helpers for building JSON Schema input schemas:

```swift
Schema.object(
    properties: [
        "name": Schema.string(description: "User name"),
        "age": Schema.integer(description: "Age", minimum: 0, maximum: 150),
        "score": Schema.number(description: "Score"),
        "active": Schema.boolean(description: "Is active"),
        "tags": Schema.array(items: Schema.string(), description: "Tags"),
        "level": Schema.string(description: "Level", enum: ["low", "medium", "high"]),
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

## License

MIT
