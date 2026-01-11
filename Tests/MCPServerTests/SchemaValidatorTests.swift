import Testing
import Foundation
@testable import MCPServer

@Suite("Schema Validator Tests")
struct SchemaValidatorTests {

    // MARK: - Required Fields

    @Suite("Required Fields")
    struct RequiredFieldsTests {

        @Test("passes when all required fields present")
        func allRequiredPresent() throws {
            let schema = Schema.object(
                properties: ["name": Schema.string(), "age": Schema.integer()],
                required: ["name", "age"]
            )

            try SchemaValidator.validate(
                arguments: ["name": .string("Alice"), "age": .int(30)],
                against: schema
            )
        }

        @Test("fails when required field missing")
        func missingRequired() {
            let schema = Schema.object(
                properties: ["name": Schema.string(), "age": Schema.integer()],
                required: ["name", "age"]
            )

            do {
                try SchemaValidator.validate(
                    arguments: ["name": .string("Alice")],
                    against: schema
                )
                Issue.record("Expected validation error")
            } catch let error as ToolError {
                #expect(error.message.contains("Missing required argument: age"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("passes when optional fields omitted")
        func optionalFieldsOmitted() throws {
            let schema = Schema.object(
                properties: ["name": Schema.string(), "nickname": Schema.string()],
                required: ["name"]
            )

            try SchemaValidator.validate(
                arguments: ["name": .string("Alice")],
                against: schema
            )
        }

        @Test("allows extra arguments not in schema")
        func extraArguments() throws {
            let schema = Schema.object(
                properties: ["name": Schema.string()],
                required: ["name"]
            )

            try SchemaValidator.validate(
                arguments: ["name": .string("Alice"), "extra": .string("ignored")],
                against: schema
            )
        }
    }

    // MARK: - Type Validation

    @Suite("Type Validation")
    struct TypeValidationTests {

        @Test("validates string type")
        func stringType() throws {
            let schema = Schema.object(properties: ["msg": Schema.string()])

            try SchemaValidator.validate(arguments: ["msg": .string("hello")], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["msg": .int(42)], against: schema)
                Issue.record("Expected type error")
            } catch let error as ToolError {
                #expect(error.message.contains("expected string"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validates integer type")
        func integerType() throws {
            let schema = Schema.object(properties: ["count": Schema.integer()])

            try SchemaValidator.validate(arguments: ["count": .int(42)], against: schema)

            // Whole number doubles are accepted as integers
            try SchemaValidator.validate(arguments: ["count": .double(42.0)], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["count": .double(42.5)], against: schema)
                Issue.record("Expected type error")
            } catch let error as ToolError {
                #expect(error.message.contains("expected integer"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validates number type")
        func numberType() throws {
            let schema = Schema.object(properties: ["value": Schema.number()])

            try SchemaValidator.validate(arguments: ["value": .double(3.14)], against: schema)
            try SchemaValidator.validate(arguments: ["value": .int(42)], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["value": .string("not a number")], against: schema)
                Issue.record("Expected type error")
            } catch let error as ToolError {
                #expect(error.message.contains("expected number"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validates boolean type")
        func booleanType() throws {
            let schema = Schema.object(properties: ["flag": Schema.boolean()])

            try SchemaValidator.validate(arguments: ["flag": .bool(true)], against: schema)
            try SchemaValidator.validate(arguments: ["flag": .bool(false)], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["flag": .string("true")], against: schema)
                Issue.record("Expected type error")
            } catch let error as ToolError {
                #expect(error.message.contains("expected boolean"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validates array type")
        func arrayType() throws {
            let schema = Schema.object(properties: ["items": Schema.array(items: Schema.string())])

            try SchemaValidator.validate(
                arguments: ["items": .array([.string("a"), .string("b")])],
                against: schema
            )

            do {
                try SchemaValidator.validate(arguments: ["items": .string("not array")], against: schema)
                Issue.record("Expected type error")
            } catch let error as ToolError {
                #expect(error.message.contains("expected array"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validates array item types")
        func arrayItemTypes() {
            let schema = Schema.object(properties: ["nums": Schema.array(items: Schema.integer())])

            do {
                try SchemaValidator.validate(
                    arguments: ["nums": .array([.int(1), .string("two"), .int(3)])],
                    against: schema
                )
                Issue.record("Expected type error")
            } catch let error as ToolError {
                #expect(error.message.contains("nums[1]"))
                #expect(error.message.contains("expected integer"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Numeric Bounds

    @Suite("Numeric Bounds")
    struct NumericBoundsTests {

        @Test("validates integer minimum")
        func integerMinimum() throws {
            let schema = Schema.object(properties: ["age": Schema.integer(minimum: 0)])

            try SchemaValidator.validate(arguments: ["age": .int(0)], against: schema)
            try SchemaValidator.validate(arguments: ["age": .int(100)], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["age": .int(-1)], against: schema)
                Issue.record("Expected bounds error")
            } catch let error as ToolError {
                #expect(error.message.contains("must be >= 0"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validates integer maximum")
        func integerMaximum() throws {
            let schema = Schema.object(properties: ["percent": Schema.integer(maximum: 100)])

            try SchemaValidator.validate(arguments: ["percent": .int(100)], against: schema)
            try SchemaValidator.validate(arguments: ["percent": .int(0)], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["percent": .int(101)], against: schema)
                Issue.record("Expected bounds error")
            } catch let error as ToolError {
                #expect(error.message.contains("must be <= 100"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validates integer range")
        func integerRange() throws {
            let schema = Schema.object(properties: ["score": Schema.integer(minimum: 1, maximum: 10)])

            try SchemaValidator.validate(arguments: ["score": .int(5)], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["score": .int(0)], against: schema)
                Issue.record("Expected bounds error")
            } catch {
                // Expected
            }

            do {
                try SchemaValidator.validate(arguments: ["score": .int(11)], against: schema)
                Issue.record("Expected bounds error")
            } catch {
                // Expected
            }
        }

        @Test("validates number bounds")
        func numberBounds() throws {
            let schema = Schema.object(properties: ["temp": Schema.number(minimum: -273.15, maximum: 1000.0)])

            try SchemaValidator.validate(arguments: ["temp": .double(20.5)], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["temp": .double(-300.0)], against: schema)
                Issue.record("Expected bounds error")
            } catch {
                // Expected
            }
        }
    }

    // MARK: - Enum Validation

    @Suite("Enum Validation")
    struct EnumValidationTests {

        @Test("validates string enum")
        func stringEnum() throws {
            let schema = Schema.object(
                properties: ["level": Schema.string(enum: ["low", "medium", "high"])]
            )

            try SchemaValidator.validate(arguments: ["level": .string("low")], against: schema)
            try SchemaValidator.validate(arguments: ["level": .string("high")], against: schema)

            do {
                try SchemaValidator.validate(arguments: ["level": .string("invalid")], against: schema)
                Issue.record("Expected enum error")
            } catch let error as ToolError {
                #expect(error.message.contains("must be one of"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Integration with ToolRegistry

    @Suite("ToolRegistry Integration")
    struct RegistryIntegrationTests {

        @Test("registry validates before execution")
        func registryValidates() async {
            let registry = ToolRegistry<NoContext>()

            struct StrictTool: Tool {
                typealias Context = NoContext
                let name = "strict"
                let description = "A tool with strict schema"
                var inputSchema: JSONValue {
                    Schema.object(
                        properties: ["count": Schema.integer(minimum: 1, maximum: 10)],
                        required: ["count"]
                    )
                }

                func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
                    "executed"
                }
            }

            await registry.register(StrictTool())

            // Valid call should work
            do {
                let result = try await registry.call(
                    name: "strict",
                    arguments: ["count": .int(5)],
                    context: .shared
                )
                #expect(result == "executed")
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            // Invalid type should fail
            do {
                _ = try await registry.call(
                    name: "strict",
                    arguments: ["count": .string("five")],
                    context: .shared
                )
                Issue.record("Expected validation error")
            } catch let error as ToolError {
                #expect(error.message.contains("expected integer"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            // Out of bounds should fail
            do {
                _ = try await registry.call(
                    name: "strict",
                    arguments: ["count": .int(100)],
                    context: .shared
                )
                Issue.record("Expected validation error")
            } catch let error as ToolError {
                #expect(error.message.contains("must be <= 10"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("validation can be disabled")
        func validationDisabled() async throws {
            let registry = ToolRegistry<NoContext>()

            struct LenientTool: Tool {
                typealias Context = NoContext
                let name = "lenient"
                let description = "Handles its own validation"
                var inputSchema: JSONValue {
                    Schema.object(
                        properties: ["value": Schema.integer()],
                        required: ["value"]
                    )
                }

                func execute(arguments: [String: JSONValue], context: NoContext) async throws -> String {
                    "executed"
                }
            }

            await registry.register(LenientTool())

            // With validation disabled, wrong type gets through to tool
            let result = try await registry.call(
                name: "lenient",
                arguments: ["value": .string("not an int")],
                context: .shared,
                validate: false
            )
            #expect(result == "executed")
        }
    }
}
