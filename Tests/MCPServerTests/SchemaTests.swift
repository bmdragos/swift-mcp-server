import Testing
import Foundation
@testable import MCPServer

@Suite("Schema Helper Tests")
struct SchemaTests {

    // MARK: - Schema.object

    @Suite("Schema.object")
    struct ObjectTests {

        @Test("empty object schema")
        func emptyObject() {
            let schema = Schema.object(properties: [:])

            #expect(schema["type"]?.stringValue == "object")
            #expect(schema["properties"]?.objectValue?.isEmpty == true)
            #expect(schema["required"] == nil)
        }

        @Test("object with properties")
        func objectWithProperties() {
            let schema = Schema.object(
                properties: [
                    "name": Schema.string(),
                    "age": Schema.integer()
                ]
            )

            #expect(schema["type"]?.stringValue == "object")
            #expect(schema["properties"]?["name"]?["type"]?.stringValue == "string")
            #expect(schema["properties"]?["age"]?["type"]?.stringValue == "integer")
        }

        @Test("object with required fields")
        func objectWithRequired() {
            let schema = Schema.object(
                properties: ["name": Schema.string()],
                required: ["name"]
            )

            let required = schema["required"]?.arrayValue
            #expect(required?.count == 1)
            #expect(required?[0].stringValue == "name")
        }

        @Test("object with multiple required fields")
        func objectWithMultipleRequired() {
            let schema = Schema.object(
                properties: [
                    "a": Schema.string(),
                    "b": Schema.string(),
                    "c": Schema.string()
                ],
                required: ["a", "b"]
            )

            let required = schema["required"]?.arrayValue
            #expect(required?.count == 2)
        }
    }

    // MARK: - Schema.string

    @Suite("Schema.string")
    struct StringTests {

        @Test("basic string schema")
        func basicString() {
            let schema = Schema.string()
            #expect(schema["type"]?.stringValue == "string")
            #expect(schema["description"] == nil)
            #expect(schema["enum"] == nil)
        }

        @Test("string with description")
        func stringWithDescription() {
            let schema = Schema.string(description: "A user's name")
            #expect(schema["type"]?.stringValue == "string")
            #expect(schema["description"]?.stringValue == "A user's name")
        }

        @Test("string with enum values")
        func stringWithEnum() {
            let schema = Schema.string(enum: ["low", "medium", "high"])

            let enumValues = schema["enum"]?.arrayValue
            #expect(enumValues?.count == 3)
            #expect(enumValues?[0].stringValue == "low")
            #expect(enumValues?[1].stringValue == "medium")
            #expect(enumValues?[2].stringValue == "high")
        }

        @Test("string with description and enum")
        func stringWithDescriptionAndEnum() {
            let schema = Schema.string(
                description: "Priority level",
                enum: ["low", "high"]
            )

            #expect(schema["description"]?.stringValue == "Priority level")
            #expect(schema["enum"]?.arrayValue?.count == 2)
        }
    }

    // MARK: - Schema.integer

    @Suite("Schema.integer")
    struct IntegerTests {

        @Test("basic integer schema")
        func basicInteger() {
            let schema = Schema.integer()
            #expect(schema["type"]?.stringValue == "integer")
        }

        @Test("integer with description")
        func integerWithDescription() {
            let schema = Schema.integer(description: "User's age")
            #expect(schema["description"]?.stringValue == "User's age")
        }

        @Test("integer with minimum")
        func integerWithMinimum() {
            let schema = Schema.integer(minimum: 0)
            #expect(schema["minimum"]?.intValue == 0)
        }

        @Test("integer with maximum")
        func integerWithMaximum() {
            let schema = Schema.integer(maximum: 100)
            #expect(schema["maximum"]?.intValue == 100)
        }

        @Test("integer with range")
        func integerWithRange() {
            let schema = Schema.integer(
                description: "Percentage",
                minimum: 0,
                maximum: 100
            )

            #expect(schema["description"]?.stringValue == "Percentage")
            #expect(schema["minimum"]?.intValue == 0)
            #expect(schema["maximum"]?.intValue == 100)
        }
    }

    // MARK: - Schema.number

    @Suite("Schema.number")
    struct NumberTests {

        @Test("basic number schema")
        func basicNumber() {
            let schema = Schema.number()
            #expect(schema["type"]?.stringValue == "number")
        }

        @Test("number with description")
        func numberWithDescription() {
            let schema = Schema.number(description: "Temperature in Celsius")
            #expect(schema["description"]?.stringValue == "Temperature in Celsius")
        }

        @Test("number with minimum")
        func numberWithMinimum() {
            let schema = Schema.number(minimum: -273.15)
            #expect(schema["minimum"]?.doubleValue == -273.15)
        }

        @Test("number with maximum")
        func numberWithMaximum() {
            let schema = Schema.number(maximum: 100.0)
            #expect(schema["maximum"]?.doubleValue == 100.0)
        }

        @Test("number with range")
        func numberWithRange() {
            let schema = Schema.number(
                description: "Score",
                minimum: 0.0,
                maximum: 10.0
            )

            #expect(schema["minimum"]?.doubleValue == 0.0)
            #expect(schema["maximum"]?.doubleValue == 10.0)
        }
    }

    // MARK: - Schema.boolean

    @Suite("Schema.boolean")
    struct BooleanTests {

        @Test("basic boolean schema")
        func basicBoolean() {
            let schema = Schema.boolean()
            #expect(schema["type"]?.stringValue == "boolean")
        }

        @Test("boolean with description")
        func booleanWithDescription() {
            let schema = Schema.boolean(description: "Is active")
            #expect(schema["type"]?.stringValue == "boolean")
            #expect(schema["description"]?.stringValue == "Is active")
        }
    }

    // MARK: - Schema.array

    @Suite("Schema.array")
    struct ArrayTests {

        @Test("array of strings")
        func arrayOfStrings() {
            let schema = Schema.array(items: Schema.string())

            #expect(schema["type"]?.stringValue == "array")
            #expect(schema["items"]?["type"]?.stringValue == "string")
        }

        @Test("array of integers")
        func arrayOfIntegers() {
            let schema = Schema.array(items: Schema.integer())

            #expect(schema["type"]?.stringValue == "array")
            #expect(schema["items"]?["type"]?.stringValue == "integer")
        }

        @Test("array with description")
        func arrayWithDescription() {
            let schema = Schema.array(
                items: Schema.string(),
                description: "List of tags"
            )

            #expect(schema["description"]?.stringValue == "List of tags")
        }

        @Test("array of objects")
        func arrayOfObjects() {
            let itemSchema = Schema.object(
                properties: ["name": Schema.string()],
                required: ["name"]
            )
            let schema = Schema.array(items: itemSchema)

            #expect(schema["items"]?["type"]?.stringValue == "object")
            #expect(schema["items"]?["properties"]?["name"] != nil)
        }
    }

    // MARK: - Schema.empty

    @Suite("Schema.empty")
    struct EmptyTests {

        @Test("empty schema has no properties")
        func emptySchema() {
            let schema = Schema.empty

            #expect(schema["type"]?.stringValue == "object")
            #expect(schema["properties"]?.objectValue?.isEmpty == true)
        }
    }

    // MARK: - Complex Schemas

    @Suite("Complex Schemas")
    struct ComplexTests {

        @Test("nested object schema")
        func nestedObject() {
            let addressSchema = Schema.object(
                properties: [
                    "street": Schema.string(description: "Street address"),
                    "city": Schema.string(description: "City name"),
                    "zip": Schema.string(description: "ZIP code")
                ],
                required: ["city"]
            )

            let userSchema = Schema.object(
                properties: [
                    "name": Schema.string(description: "User's full name"),
                    "age": Schema.integer(minimum: 0),
                    "address": addressSchema
                ],
                required: ["name"]
            )

            // Verify nested structure
            #expect(userSchema["properties"]?["address"]?["type"]?.stringValue == "object")
            #expect(userSchema["properties"]?["address"]?["properties"]?["city"] != nil)
        }

        @Test("MCP tool input schema example")
        func mcpToolSchema() {
            // Real-world example: an echo tool schema
            let schema = Schema.object(
                properties: [
                    "message": Schema.string(description: "Message to echo back"),
                    "uppercase": Schema.boolean(description: "Convert to uppercase"),
                    "repeat": Schema.integer(
                        description: "Number of times to repeat",
                        minimum: 1,
                        maximum: 10
                    )
                ],
                required: ["message"]
            )

            // Verify it's valid JSON Schema structure
            #expect(schema["type"]?.stringValue == "object")
            #expect(schema["properties"]?["message"]?["type"]?.stringValue == "string")
            #expect(schema["properties"]?["uppercase"]?["type"]?.stringValue == "boolean")
            #expect(schema["properties"]?["repeat"]?["minimum"]?.intValue == 1)

            let required = schema["required"]?.arrayValue
            #expect(required?.contains(.string("message")) == true)
        }

        @Test("schema is valid JSON")
        func schemaIsValidJSON() throws {
            let schema = Schema.object(
                properties: [
                    "query": Schema.string(description: "Search query"),
                    "limit": Schema.integer(minimum: 1, maximum: 100)
                ],
                required: ["query"]
            )

            // Should encode to valid JSON
            let data = try JSONEncoder().encode(schema)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"type\":\"object\""))
            #expect(json.contains("\"query\""))
        }
    }
}
