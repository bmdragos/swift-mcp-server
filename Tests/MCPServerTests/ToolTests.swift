import Testing
import Foundation
@testable import MCPServer

// MARK: - Test Tools

struct EchoTool: Tool {
    typealias Context = NoContext

    let name = "echo"
    let description = "Echo back the input"
    let inputSchema = Schema.object(
        properties: ["message": Schema.string(description: "Message to echo")],
        required: ["message"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        guard let message = arguments["message"]?.stringValue else {
            throw ToolError("Missing message")
        }
        return message
    }
}

struct AddTool: Tool {
    typealias Context = NoContext

    let name = "add"
    let description = "Add two numbers"
    let inputSchema = Schema.object(
        properties: [
            "a": Schema.number(description: "First number"),
            "b": Schema.number(description: "Second number")
        ],
        required: ["a", "b"]
    )

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        guard let a = arguments["a"]?.doubleValue,
              let b = arguments["b"]?.doubleValue else {
            throw ToolError("Missing a or b")
        }
        return String(a + b)
    }
}

struct FailingTool: Tool {
    typealias Context = NoContext

    let name = "fail"
    let description = "Always fails"
    let inputSchema = Schema.empty

    func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
        throw ToolError("This tool always fails")
    }
}

// Context-aware tool for testing
actor CounterContext: Sendable {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }

    func current() -> Int {
        return count
    }
}

struct CounterTool: Tool {
    typealias Context = CounterContext

    let name = "counter"
    let description = "Increment counter"
    let inputSchema = Schema.empty

    func execute(arguments: [String: JSONValue], context: CounterContext) async throws -> String {
        let value = await context.increment()
        return String(value)
    }
}

// MARK: - Tests

@Suite("Tool Tests")
struct ToolTests {

    // MARK: - ToolError

    @Suite("ToolError")
    struct ToolErrorTests {

        @Test("ToolError has message")
        func errorMessage() {
            let error = ToolError("Something went wrong")
            #expect(error.message == "Something went wrong")
            #expect(error.description == "Something went wrong")
        }

        @Test("ToolError conforms to Error")
        func errorConformance() {
            let error: Error = ToolError("test")
            // ToolError conforms to Error protocol
            #expect(error is ToolError)
            #expect((error as! ToolError).message == "test")
        }
    }

    // MARK: - ToolRegistry

    @Suite("ToolRegistry")
    struct RegistryTests {

        @Test("register single tool")
        func registerSingle() async {
            let registry = ToolRegistry<NoContext>()
            await registry.register(EchoTool())

            let names = await registry.toolNames
            #expect(names == ["echo"])
        }

        @Test("register multiple tools")
        func registerMultiple() async {
            let registry = ToolRegistry<NoContext>()
            await registry.register([EchoTool(), AddTool(), FailingTool()])

            let names = await registry.toolNames
            #expect(names.count == 3)
            #expect(names.contains("echo"))
            #expect(names.contains("add"))
            #expect(names.contains("fail"))
        }

        @Test("lookup tool by name")
        func lookupTool() async {
            let registry = ToolRegistry<NoContext>()
            await registry.register(EchoTool())

            let tool = await registry.tool(named: "echo")
            #expect(tool?.name == "echo")
            #expect(tool?.description == "Echo back the input")
        }

        @Test("lookup nonexistent tool returns nil")
        func lookupMissing() async {
            let registry = ToolRegistry<NoContext>()
            let tool = await registry.tool(named: "nonexistent")
            #expect(tool == nil)
        }

        @Test("overwrite tool with same name")
        func overwriteTool() async {
            let registry = ToolRegistry<NoContext>()
            await registry.register(EchoTool())
            await registry.register(EchoTool()) // Register again

            let names = await registry.toolNames
            #expect(names.count == 1)
        }

        @Test("listTools returns correct format")
        func listToolsFormat() async throws {
            let registry = ToolRegistry<NoContext>()
            await registry.register(EchoTool())

            let list = await registry.listTools()

            // Should have "tools" key with array
            guard let tools = list["tools"]?.arrayValue else {
                Issue.record("Expected tools array")
                return
            }

            #expect(tools.count == 1)

            let tool = tools[0]
            #expect(tool["name"]?.stringValue == "echo")
            #expect(tool["description"]?.stringValue == "Echo back the input")
            #expect(tool["inputSchema"] != nil)
        }

        @Test("call tool successfully")
        func callToolSuccess() async throws {
            let registry = ToolRegistry<NoContext>()
            await registry.register(EchoTool())

            let result = try await registry.call(
                name: "echo",
                arguments: ["message": .string("hello")],
                context: .shared
            )

            #expect(result == "hello")
        }

        @Test("call tool with numeric arguments")
        func callToolNumeric() async throws {
            let registry = ToolRegistry<NoContext>()
            await registry.register(AddTool())

            let result = try await registry.call(
                name: "add",
                arguments: ["a": .int(2), "b": .int(3)],
                context: .shared
            )

            #expect(result == "5.0")
        }

        @Test("call unknown tool throws")
        func callUnknownTool() async {
            let registry = ToolRegistry<NoContext>()

            do {
                _ = try await registry.call(
                    name: "nonexistent",
                    arguments: [:],
                    context: .shared
                )
                Issue.record("Expected error to be thrown")
            } catch let error as ToolError {
                #expect(error.message.contains("Unknown tool"))
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }

        @Test("call failing tool propagates error")
        func callFailingTool() async {
            let registry = ToolRegistry<NoContext>()
            await registry.register(FailingTool())

            do {
                _ = try await registry.call(
                    name: "fail",
                    arguments: [:],
                    context: .shared
                )
                Issue.record("Expected error to be thrown")
            } catch let error as ToolError {
                #expect(error.message == "This tool always fails")
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }

        @Test("call tool with missing required argument")
        func callMissingArgument() async {
            let registry = ToolRegistry<NoContext>()
            await registry.register(EchoTool())

            do {
                _ = try await registry.call(
                    name: "echo",
                    arguments: [:], // Missing "message"
                    context: .shared
                )
                Issue.record("Expected error to be thrown")
            } catch let error as ToolError {
                #expect(error.message.contains("Missing"))
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - Context-aware Tools

    @Suite("Context-aware Tools")
    struct ContextTests {

        @Test("tool can use context")
        func toolUsesContext() async throws {
            let context = CounterContext()
            let registry = ToolRegistry<CounterContext>()
            await registry.register(CounterTool())

            let result1 = try await registry.call(name: "counter", arguments: [:], context: context)
            let result2 = try await registry.call(name: "counter", arguments: [:], context: context)
            let result3 = try await registry.call(name: "counter", arguments: [:], context: context)

            #expect(result1 == "1")
            #expect(result2 == "2")
            #expect(result3 == "3")
        }

        @Test("context state persists across calls")
        func contextPersistence() async throws {
            let context = CounterContext()
            let registry = ToolRegistry<CounterContext>()
            await registry.register(CounterTool())

            // Make some calls
            _ = try await registry.call(name: "counter", arguments: [:], context: context)
            _ = try await registry.call(name: "counter", arguments: [:], context: context)

            // Check context state directly
            let current = await context.current()
            #expect(current == 2)
        }
    }
}
