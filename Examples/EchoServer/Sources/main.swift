import MCPServer

// MARK: - Define a Tool

struct EchoTool: Tool {
    typealias Context = NoContext

    let name = "echo"
    let description = "Echo back the input message"

    let inputSchema = Schema.object(
        properties: [
            "message": Schema.string(description: "Message to echo back"),
            "uppercase": Schema.boolean(description: "Convert to uppercase"),
        ],
        required: ["message"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        guard let message = arguments["message"]?.stringValue else {
            throw ToolError("Missing required argument: message")
        }

        let uppercase = arguments["uppercase"]?.boolValue ?? false
        return uppercase ? message.uppercased() : message
    }
}

struct AddTool: Tool {
    typealias Context = NoContext

    let name = "add"
    let description = "Add two numbers"

    let inputSchema = Schema.object(
        properties: [
            "a": Schema.number(description: "First number"),
            "b": Schema.number(description: "Second number"),
        ],
        required: ["a", "b"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        guard let a = arguments["a"]?.doubleValue,
              let b = arguments["b"]?.doubleValue else {
            throw ToolError("Missing required arguments: a and b")
        }
        return String(a + b)
    }
}

// MARK: - Run the Server

let server = MCPServer(info: ServerInfo(
    name: "echo-server",
    version: "1.0.0"
))

await server.register([EchoTool(), AddTool()])
await server.run()
