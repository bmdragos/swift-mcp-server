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
            "tool_name": Schema.string(description: "Name of the initial example tool to create (e.g., 'hello')"),
            "tool_description": Schema.string(description: "Description of the initial tool"),
            "with_context": Schema.boolean(description: "Whether to include a context actor for shared state (default: false)"),
            "use_macro": Schema.boolean(description: "Use @MCPTool macro for simpler syntax (default: true)"),
            "local_library": Schema.string(description: "Use local library path instead of GitHub (for development)"),
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

        let localLibrary = arguments["local_library"]?.stringValue
        let toolName = arguments["tool_name"]?.stringValue ?? "hello"
        let toolDescription = arguments["tool_description"]?.stringValue ?? "A sample tool"
        let withContext = arguments["with_context"]?.boolValue ?? false
        let useMacro = arguments["use_macro"]?.boolValue ?? true

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
        let packageSwift = generatePackageSwift(name: name, localLibrary: localLibrary, useMacro: useMacro)
        let mainSwift = generateMainSwift(
            serverName: name,
            toolName: toolName,
            toolDescription: toolDescription,
            withContext: withContext,
            useMacro: useMacro
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

    private func generatePackageSwift(name: String, localLibrary: String?, useMacro: Bool) -> String {
        let dependency: String
        if let localPath = localLibrary {
            dependency = ".package(path: \"\(localPath)\"),"
        } else {
            dependency = ".package(url: \"https://github.com/bmdragos/swift-mcp-server\", from: \"1.0.0\"),"
        }

        let product = useMacro ? "MCPServerMacros" : "MCPServer"

        return """
            // swift-tools-version: 6.0

            import PackageDescription

            let package = Package(
                name: "\(name)",
                platforms: [.macOS(.v14)],
                dependencies: [
                    \(dependency)
                ],
                targets: [
                    .executableTarget(
                        name: "\(name)",
                        dependencies: [
                            .product(name: "\(product)", package: "swift-mcp-server"),
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
        withContext: Bool,
        useMacro: Bool
    ) -> String {
        let structName = toolName.capitalized.replacingOccurrences(of: "-", with: "") + "Tool"

        if useMacro {
            return generateMacroStyle(
                serverName: serverName,
                toolName: toolName,
                toolDescription: toolDescription,
                structName: structName,
                withContext: withContext
            )
        } else {
            return generateProtocolStyle(
                serverName: serverName,
                toolName: toolName,
                toolDescription: toolDescription,
                structName: structName,
                withContext: withContext
            )
        }
    }

    private func generateMacroStyle(
        serverName: String,
        toolName: String,
        toolDescription: String,
        structName: String,
        withContext: Bool
    ) -> String {
        if withContext {
            return """
                import MCPServerMacros

                // MARK: - Context (shared state)

                actor AppContext {
                    // Add your shared state here
                    // e.g., managers, connections, caches
                }

                // MARK: - Tools

                @MCPTool("\(toolName)", "\(toolDescription)")
                struct \(structName) {
                    func run(message: String, context: AppContext) async throws -> String {
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
                import MCPServerMacros

                // MARK: - Tools

                @MCPTool("\(toolName)", "\(toolDescription)")
                struct \(structName) {
                    func run(message: String, context: NoContext) async throws -> String {
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

    private func generateProtocolStyle(
        serverName: String,
        toolName: String,
        toolDescription: String,
        structName: String,
        withContext: Bool
    ) -> String {
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
          - use_macro: Use @MCPTool macro for simpler syntax (default: true)
          - local_library: Use local library path instead of GitHub URL

        Examples:

        1. Simple server with @MCPTool macro (recommended):
           create_mcp_project(name: "echo-mcp", path: "/Users/bd/Coding")

        2. Server with shared state:
           create_mcp_project(
               name: "device-mcp",
               path: "/Users/bd/Coding",
               tool_name: "connect",
               tool_description: "Connect to a device",
               with_context: true
           )

        3. Manual Tool protocol (more control over schema):
           create_mcp_project(
               name: "advanced-mcp",
               path: "/Users/bd/Coding",
               use_macro: false
           )

        4. Development with local library:
           create_mcp_project(
               name: "dev-mcp",
               path: "/Users/bd/Coding",
               local_library: "/Users/bd/Coding/swift-mcp-server"
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
