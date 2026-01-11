import Testing
import MCPServerMacros

// MARK: - Test Tools Using Macro

@MCPTool("echo", "Echo back a message")
struct EchoTool {
    func run(message: String, context: NoContext) async throws -> String {
        message
    }
}

@MCPTool("greet", "Greet someone with options")
struct GreetTool {
    func run(name: String, loud: Bool = false, context: NoContext) async throws -> String {
        let greeting = "Hello, \(name)!"
        return loud ? greeting.uppercased() : greeting
    }
}

@MCPTool("add", "Add two integers")
struct AddTool {
    func run(a: Int, b: Int, context: NoContext) async throws -> String {
        String(a + b)
    }
}

@MCPTool("search", "Search with optional filter")
struct SearchTool {
    func run(query: String, filter: String?, limit: Int?, context: NoContext) async throws -> String {
        var result = "Searching: \(query)"
        if let filter = filter {
            result += " with filter: \(filter)"
        }
        if let limit = limit {
            result += " (limit: \(limit))"
        }
        return result
    }
}

// MARK: - Enum Test Types

enum Priority: String, CaseIterable {
    case low
    case medium
    case high
}

enum Status: String, CaseIterable {
    case pending
    case active
    case completed
}

@MCPTool("create_task", "Create a task with priority")
struct CreateTaskTool {
    func run(title: String, priority: Priority, context: NoContext) async throws -> String {
        "Created task '\(title)' with priority: \(priority.rawValue)"
    }
}

@MCPTool("update_task", "Update task with optional status")
struct UpdateTaskTool {
    func run(id: String, status: Status?, context: NoContext) async throws -> String {
        if let status = status {
            return "Updated task \(id) to status: \(status.rawValue)"
        } else {
            return "Updated task \(id) (no status change)"
        }
    }
}

@MCPTool("quick_task", "Create a task with default priority")
struct QuickTaskTool {
    func run(title: String, priority: Priority = .medium, context: NoContext) async throws -> String {
        "Quick task '\(title)' with priority: \(priority.rawValue)"
    }
}

// MARK: - Date Test Tools

import Foundation

@MCPTool("schedule_event", "Schedule an event at a date")
struct ScheduleEventTool {
    func run(name: String, date: Date, context: NoContext) async throws -> String {
        let formatter = ISO8601DateFormatter()
        return "Scheduled '\(name)' for \(formatter.string(from: date))"
    }
}

@MCPTool("query_events", "Query events with optional date filter")
struct QueryEventsTool {
    func run(filter: String, since: Date?, context: NoContext) async throws -> String {
        if let since = since {
            let formatter = ISO8601DateFormatter()
            return "Querying '\(filter)' since \(formatter.string(from: since))"
        } else {
            return "Querying '\(filter)' (all time)"
        }
    }
}

// MARK: - Tests

@Suite("MCPTool Macro Tests")
struct MCPToolMacroTests {

    @Test("macro generates correct name")
    func macroGeneratesName() {
        let tool = EchoTool()
        #expect(tool.name == "echo")
    }

    @Test("macro generates correct description")
    func macroGeneratesDescription() {
        let tool = EchoTool()
        #expect(tool.description == "Echo back a message")
    }

    @Test("macro generates inputSchema with required field")
    func macroGeneratesSchema() {
        let tool = EchoTool()
        let schema = tool.inputSchema

        #expect(schema["type"]?.stringValue == "object")
        #expect(schema["properties"]?["message"]?["type"]?.stringValue == "string")

        let required = schema["required"]?.arrayValue
        #expect(required?.contains(.string("message")) == true)
    }

    @Test("macro generates execute that calls run")
    func macroGeneratesExecute() async throws {
        let tool = EchoTool()
        let result = try await tool.execute(
            arguments: ["message": .string("Hello!")],
            context: .shared
        )
        #expect(result == "Hello!")
    }

    @Test("tool with optional parameters has correct schema")
    func optionalParameterSchema() {
        let tool = GreetTool()
        let schema = tool.inputSchema

        // Both name and loud should be in properties
        #expect(schema["properties"]?["name"]?["type"]?.stringValue == "string")
        #expect(schema["properties"]?["loud"]?["type"]?.stringValue == "boolean")

        // Only name should be required
        let required = schema["required"]?.arrayValue
        #expect(required?.count == 1)
        #expect(required?.contains(.string("name")) == true)
    }

    @Test("tool with optional parameters uses defaults")
    func optionalParameterDefaults() async throws {
        let tool = GreetTool()

        // Without loud parameter - should use default (false)
        let result1 = try await tool.execute(
            arguments: ["name": .string("World")],
            context: .shared
        )
        #expect(result1 == "Hello, World!")

        // With loud = true
        let result2 = try await tool.execute(
            arguments: ["name": .string("World"), "loud": .bool(true)],
            context: .shared
        )
        #expect(result2 == "HELLO, WORLD!")
    }

    @Test("tool with integer parameters")
    func integerParameters() async throws {
        let tool = AddTool()

        // Check schema
        #expect(tool.inputSchema["properties"]?["a"]?["type"]?.stringValue == "integer")
        #expect(tool.inputSchema["properties"]?["b"]?["type"]?.stringValue == "integer")

        // Check execution
        let result = try await tool.execute(
            arguments: ["a": .int(2), "b": .int(3)],
            context: .shared
        )
        #expect(result == "5")
    }

    @Test("tool throws on missing required argument")
    func missingRequiredArgument() async {
        let tool = EchoTool()

        do {
            _ = try await tool.execute(arguments: [:], context: .shared)
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(String(describing: error).contains("Missing required argument"))
        }
    }

    @Test("tools work with ToolRegistry")
    func toolsWorkWithRegistry() async throws {
        let registry = ToolRegistry<NoContext>()
        await registry.register(EchoTool())
        await registry.register(GreetTool())
        await registry.register(AddTool())

        let tools = await registry.listTools()
        let toolArray = tools["tools"]?.arrayValue ?? []
        #expect(toolArray.count == 3)

        // Test calling through registry
        let result = try await registry.call(
            name: "echo",
            arguments: ["message": .string("test")],
            context: .shared
        )
        #expect(result == "test")
    }

    // MARK: - Optional Type Support

    @Test("optional parameters are not required in schema")
    func optionalNotRequired() {
        let tool = SearchTool()
        let schema = tool.inputSchema

        // Only query should be required
        let required = schema["required"]?.arrayValue ?? []
        #expect(required.count == 1)
        #expect(required.contains(.string("query")))
        #expect(!required.contains(.string("filter")))
        #expect(!required.contains(.string("limit")))
    }

    @Test("optional parameters are in schema properties")
    func optionalInProperties() {
        let tool = SearchTool()
        let schema = tool.inputSchema

        // All parameters should be in properties
        #expect(schema["properties"]?["query"]?["type"]?.stringValue == "string")
        #expect(schema["properties"]?["filter"]?["type"]?.stringValue == "string")
        #expect(schema["properties"]?["limit"]?["type"]?.stringValue == "integer")
    }

    @Test("optional parameters pass nil when omitted")
    func optionalPassesNil() async throws {
        let tool = SearchTool()

        // Call with only required argument
        let result = try await tool.execute(
            arguments: ["query": .string("test")],
            context: .shared
        )
        #expect(result == "Searching: test")
    }

    @Test("optional parameters pass value when provided")
    func optionalPassesValue() async throws {
        let tool = SearchTool()

        // Call with all arguments
        let result = try await tool.execute(
            arguments: [
                "query": .string("test"),
                "filter": .string("active"),
                "limit": .int(10)
            ],
            context: .shared
        )
        #expect(result == "Searching: test with filter: active (limit: 10)")
    }

    @Test("optional parameters work with partial args")
    func optionalPartial() async throws {
        let tool = SearchTool()

        // Call with some optional args
        let result = try await tool.execute(
            arguments: [
                "query": .string("test"),
                "limit": .int(5)
            ],
            context: .shared
        )
        #expect(result == "Searching: test (limit: 5)")
    }

    // MARK: - String Enum Support

    @Test("enum schema includes allowed values")
    func enumSchemaValues() {
        let tool = CreateTaskTool()
        let schema = tool.inputSchema

        // Priority should be string type with enum values
        #expect(schema["properties"]?["priority"]?["type"]?.stringValue == "string")

        let enumValues = schema["properties"]?["priority"]?["enum"]?.arrayValue ?? []
        #expect(enumValues.count == 3)
        #expect(enumValues.contains(.string("low")))
        #expect(enumValues.contains(.string("medium")))
        #expect(enumValues.contains(.string("high")))
    }

    @Test("required enum is in required array")
    func enumRequired() {
        let tool = CreateTaskTool()
        let schema = tool.inputSchema

        let required = schema["required"]?.arrayValue ?? []
        #expect(required.contains(.string("title")))
        #expect(required.contains(.string("priority")))
    }

    @Test("enum parameter executes correctly")
    func enumExecution() async throws {
        let tool = CreateTaskTool()

        let result = try await tool.execute(
            arguments: [
                "title": .string("Write tests"),
                "priority": .string("high")
            ],
            context: .shared
        )
        #expect(result == "Created task 'Write tests' with priority: high")
    }

    @Test("invalid enum value throws error")
    func enumInvalidValue() async {
        let tool = CreateTaskTool()

        do {
            _ = try await tool.execute(
                arguments: [
                    "title": .string("Test"),
                    "priority": .string("invalid")
                ],
                context: .shared
            )
            Issue.record("Expected error for invalid enum value")
        } catch {
            #expect(String(describing: error).contains("invalid argument"))
        }
    }

    @Test("optional enum schema includes values")
    func optionalEnumSchema() {
        let tool = UpdateTaskTool()
        let schema = tool.inputSchema

        // Status should be string type with enum values
        #expect(schema["properties"]?["status"]?["type"]?.stringValue == "string")

        let enumValues = schema["properties"]?["status"]?["enum"]?.arrayValue ?? []
        #expect(enumValues.count == 3)
        #expect(enumValues.contains(.string("pending")))
        #expect(enumValues.contains(.string("active")))
        #expect(enumValues.contains(.string("completed")))

        // Status should NOT be required
        let required = schema["required"]?.arrayValue ?? []
        #expect(!required.contains(.string("status")))
    }

    @Test("optional enum passes nil when omitted")
    func optionalEnumNil() async throws {
        let tool = UpdateTaskTool()

        let result = try await tool.execute(
            arguments: ["id": .string("123")],
            context: .shared
        )
        #expect(result == "Updated task 123 (no status change)")
    }

    @Test("optional enum passes value when provided")
    func optionalEnumValue() async throws {
        let tool = UpdateTaskTool()

        let result = try await tool.execute(
            arguments: [
                "id": .string("123"),
                "status": .string("completed")
            ],
            context: .shared
        )
        #expect(result == "Updated task 123 to status: completed")
    }

    @Test("enum with default is not required")
    func enumDefaultNotRequired() {
        let tool = QuickTaskTool()
        let schema = tool.inputSchema

        let required = schema["required"]?.arrayValue ?? []
        #expect(required.contains(.string("title")))
        #expect(!required.contains(.string("priority")))
    }

    @Test("enum with default uses default when omitted")
    func enumDefaultUsed() async throws {
        let tool = QuickTaskTool()

        let result = try await tool.execute(
            arguments: ["title": .string("Test task")],
            context: .shared
        )
        #expect(result == "Quick task 'Test task' with priority: medium")
    }

    @Test("enum with default uses provided value")
    func enumDefaultOverridden() async throws {
        let tool = QuickTaskTool()

        let result = try await tool.execute(
            arguments: [
                "title": .string("Urgent task"),
                "priority": .string("high")
            ],
            context: .shared
        )
        #expect(result == "Quick task 'Urgent task' with priority: high")
    }

    // MARK: - Date Support

    @Test("date schema has string type with description")
    func dateSchemaType() {
        let tool = ScheduleEventTool()
        let schema = tool.inputSchema

        #expect(schema["properties"]?["date"]?["type"]?.stringValue == "string")
        #expect(schema["properties"]?["date"]?["description"]?.stringValue == "ISO8601 date string")
    }

    @Test("required date is in required array")
    func dateRequired() {
        let tool = ScheduleEventTool()
        let schema = tool.inputSchema

        let required = schema["required"]?.arrayValue ?? []
        #expect(required.contains(.string("name")))
        #expect(required.contains(.string("date")))
    }

    @Test("date parameter parses ISO8601 string")
    func dateExecution() async throws {
        let tool = ScheduleEventTool()

        let result = try await tool.execute(
            arguments: [
                "name": .string("Meeting"),
                "date": .string("2024-06-15T14:30:00Z")
            ],
            context: .shared
        )
        #expect(result == "Scheduled 'Meeting' for 2024-06-15T14:30:00Z")
    }

    @Test("invalid date throws error")
    func dateInvalidValue() async {
        let tool = ScheduleEventTool()

        do {
            _ = try await tool.execute(
                arguments: [
                    "name": .string("Test"),
                    "date": .string("not a date")
                ],
                context: .shared
            )
            Issue.record("Expected error for invalid date")
        } catch {
            #expect(String(describing: error).contains("invalid date"))
        }
    }

    @Test("optional date passes nil when omitted")
    func optionalDateNil() async throws {
        let tool = QueryEventsTool()

        let result = try await tool.execute(
            arguments: ["filter": .string("meetings")],
            context: .shared
        )
        #expect(result == "Querying 'meetings' (all time)")
    }

    @Test("optional date passes value when provided")
    func optionalDateValue() async throws {
        let tool = QueryEventsTool()

        let result = try await tool.execute(
            arguments: [
                "filter": .string("meetings"),
                "since": .string("2024-01-01T00:00:00Z")
            ],
            context: .shared
        )
        #expect(result == "Querying 'meetings' since 2024-01-01T00:00:00Z")
    }
}
