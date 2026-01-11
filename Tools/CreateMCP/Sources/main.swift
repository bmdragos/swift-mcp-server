import Foundation
import MCPServer

// MARK: - Create MCP Project Tool

struct CreateMCPProjectTool: Tool {
    typealias Context = NoContext

    let name = "create_mcp_project"
    let description = "Create a new Swift MCP server project with the swift-mcp-server library"

    let inputSchema = Schema.object(
        properties: [
            "name": Schema.string(description: "Project name (e.g., 'my-mcp-server')"),
            "path": Schema.string(description: "Parent directory to create project in (e.g., '/Users/bd/Coding')"),
            "library_path": Schema.string(description: "Path to swift-mcp-server library (default: /Users/bd/Coding/swift-mcp-server)"),
            "tool_name": Schema.string(description: "Name of the initial example tool to create (e.g., 'hello')"),
            "tool_description": Schema.string(description: "Description of the initial tool"),
            "with_context": Schema.boolean(description: "Whether to include a context actor for shared state (default: false)"),
        ],
        required: ["name", "path"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        guard let name = arguments["name"]?.stringValue else {
            throw ToolError("Missing required argument: name")
        }
        guard let parentPath = arguments["path"]?.stringValue else {
            throw ToolError("Missing required argument: path")
        }

        let libraryPath = arguments["library_path"]?.stringValue ?? "/Users/bd/Coding/swift-mcp-server"
        let toolName = arguments["tool_name"]?.stringValue ?? "hello"
        let toolDescription = arguments["tool_description"]?.stringValue ?? "A sample tool"
        let withContext = arguments["with_context"]?.boolValue ?? false

        let projectPath = (parentPath as NSString).appendingPathComponent(name)
        let fm = FileManager.default

        // Check parent exists
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: parentPath, isDirectory: &isDir), isDir.boolValue else {
            throw ToolError("Parent directory does not exist: \(parentPath)")
        }

        // Check project doesn't already exist
        if fm.fileExists(atPath: projectPath) {
            throw ToolError("Project already exists: \(projectPath)")
        }

        // Create directories
        let sourcesPath = (projectPath as NSString).appendingPathComponent("Sources")
        try fm.createDirectory(atPath: sourcesPath, withIntermediateDirectories: true)

        // Generate files
        let packageSwift = generatePackageSwift(name: name, libraryPath: libraryPath)
        let mainSwift = generateMainSwift(
            serverName: name,
            toolName: toolName,
            toolDescription: toolDescription,
            withContext: withContext
        )

        try packageSwift.write(
            toFile: (projectPath as NSString).appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try mainSwift.write(
            toFile: (sourcesPath as NSString).appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )

        return """
            Created MCP server project: \(name)
            Location: \(projectPath)

            Files created:
            - Package.swift
            - Sources/main.swift

            To build and run:
              cd \(projectPath)
              swift build

            To add to Claude Code, add to ~/.claude/claude_desktop_config.json:
            {
              "mcpServers": {
                "\(name)": {
                  "command": "\(projectPath)/.build/debug/\(name)"
                }
              }
            }
            """
    }

    private func generatePackageSwift(name: String, libraryPath: String) -> String {
        """
        // swift-tools-version: 6.0

        import PackageDescription

        let package = Package(
            name: "\(name)",
            platforms: [.macOS(.v14)],
            dependencies: [
                // Local path - update to GitHub URL once published:
                // .package(url: "https://github.com/yourusername/swift-mcp-server", from: "1.0.0"),
                .package(path: "\(libraryPath)"),
            ],
            targets: [
                .executableTarget(
                    name: "\(name)",
                    dependencies: [
                        .product(name: "MCPServer", package: "swift-mcp-server"),
                    ]
                ),
            ]
        )
        """
    }

    private func generateMainSwift(
        serverName: String,
        toolName: String,
        toolDescription: String,
        withContext: Bool
    ) -> String {
        let structName = toolName.capitalized.replacingOccurrences(of: "-", with: "") + "Tool"

        if withContext {
            return """
                import MCPServer

                // MARK: - Context (shared state)

                actor AppContext {
                    // Add your shared state here
                    // e.g., managers, connections, caches
                }

                // MARK: - Tools

                struct \(structName): Tool {
                    typealias Context = AppContext

                    let name = "\(toolName)"
                    let description = "\(toolDescription)"

                    let inputSchema = Schema.object(
                        properties: [
                            "message": Schema.string(description: "Input message"),
                        ],
                        required: ["message"]
                    )

                    func execute(arguments: [String: JSONValue], context: AppContext) async throws -> String {
                        guard let message = arguments["message"]?.stringValue else {
                            throw ToolError("Missing required argument: message")
                        }

                        // TODO: Implement your tool logic here
                        return "Received: \\(message)"
                    }
                }

                // MARK: - Server

                let context = AppContext()
                let server = MCPServer(
                    info: ServerInfo(name: "\(serverName)", version: "1.0.0"),
                    context: context
                )

                await server.register(\(structName)())
                await server.run()
                """
        } else {
            return """
                import MCPServer

                // MARK: - Tools

                struct \(structName): Tool {
                    typealias Context = NoContext

                    let name = "\(toolName)"
                    let description = "\(toolDescription)"

                    let inputSchema = Schema.object(
                        properties: [
                            "message": Schema.string(description: "Input message"),
                        ],
                        required: ["message"]
                    )

                    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
                        guard let message = arguments["message"]?.stringValue else {
                            throw ToolError("Missing required argument: message")
                        }

                        // TODO: Implement your tool logic here
                        return "Received: \\(message)"
                    }
                }

                // MARK: - Server

                let server = MCPServer(info: ServerInfo(name: "\(serverName)", version: "1.0.0"))

                await server.register(\(structName)())
                await server.run()
                """
        }
    }
}

// MARK: - List Templates Tool

struct ListTemplatesTool: Tool {
    typealias Context = NoContext

    let name = "list_mcp_templates"
    let description = "List available MCP project templates and options"

    let inputSchema = Schema.empty

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        """
        Available options for create_mcp_project:

        Required:
          - name: Project name (e.g., 'my-mcp-server')
          - path: Parent directory (e.g., '/Users/bd/Coding')

        Optional:
          - tool_name: Initial tool name (default: 'hello')
          - tool_description: Tool description (default: 'A sample tool')
          - with_context: Include context actor for shared state (default: false)

        Examples:

        1. Simple stateless server:
           create_mcp_project(name: "echo-mcp", path: "/Users/bd/Coding")

        2. Server with shared state (for managers, connections, etc.):
           create_mcp_project(
               name: "device-mcp",
               path: "/Users/bd/Coding",
               tool_name: "connect",
               tool_description: "Connect to a device",
               with_context: true
           )
        """
    }
}

// MARK: - Server

let server = MCPServer(info: ServerInfo(name: "create-mcp", version: "1.0.0"))

await server.register([
    CreateMCPProjectTool(),
    ListTemplatesTool(),
])
await server.run()
