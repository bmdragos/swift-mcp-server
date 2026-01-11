import Testing
import Foundation
@testable import MCPServer

@Suite("JSONValue Tests")
struct JSONValueTests {

    // MARK: - Encoding/Decoding Round-trips

    @Suite("Round-trip Encoding")
    struct RoundTripTests {

        @Test("null round-trips")
        func nullRoundTrip() throws {
            let value = JSONValue.null
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .null)
        }

        @Test("bool true round-trips")
        func boolTrueRoundTrip() throws {
            let value = JSONValue.bool(true)
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .bool(true))
        }

        @Test("bool false round-trips")
        func boolFalseRoundTrip() throws {
            let value = JSONValue.bool(false)
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .bool(false))
        }

        @Test("int round-trips")
        func intRoundTrip() throws {
            let value = JSONValue.int(42)
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .int(42))
        }

        @Test("negative int round-trips")
        func negativeIntRoundTrip() throws {
            let value = JSONValue.int(-999)
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .int(-999))
        }

        @Test("double round-trips")
        func doubleRoundTrip() throws {
            let value = JSONValue.double(3.14159)
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            if case .double(let v) = decoded {
                #expect(abs(v - 3.14159) < 0.00001)
            } else {
                Issue.record("Expected double")
            }
        }

        @Test("string round-trips")
        func stringRoundTrip() throws {
            let value = JSONValue.string("hello world")
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .string("hello world"))
        }

        @Test("empty string round-trips")
        func emptyStringRoundTrip() throws {
            let value = JSONValue.string("")
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .string(""))
        }

        @Test("string with special characters round-trips")
        func specialCharsRoundTrip() throws {
            let value = JSONValue.string("hello\nworld\t\"quoted\"\\backslash")
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .string("hello\nworld\t\"quoted\"\\backslash"))
        }

        @Test("unicode string round-trips")
        func unicodeRoundTrip() throws {
            let value = JSONValue.string("Hello 世界 🌍")
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .string("Hello 世界 🌍"))
        }

        @Test("array round-trips")
        func arrayRoundTrip() throws {
            let value = JSONValue.array([.int(1), .string("two"), .bool(true)])
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == value)
        }

        @Test("empty array round-trips")
        func emptyArrayRoundTrip() throws {
            let value = JSONValue.array([])
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .array([]))
        }

        @Test("object round-trips")
        func objectRoundTrip() throws {
            let value = JSONValue.object(["name": .string("test"), "count": .int(5)])
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == value)
        }

        @Test("empty object round-trips")
        func emptyObjectRoundTrip() throws {
            let value = JSONValue.object([:])
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == .object([:]))
        }

        @Test("nested structure round-trips")
        func nestedRoundTrip() throws {
            let value = JSONValue.object([
                "users": .array([
                    .object(["name": .string("Alice"), "age": .int(30)]),
                    .object(["name": .string("Bob"), "age": .int(25)])
                ]),
                "metadata": .object([
                    "version": .string("1.0"),
                    "flags": .array([.bool(true), .bool(false)])
                ])
            ])
            let encoded = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
            #expect(decoded == value)
        }
    }

    // MARK: - Literal Expressibility

    @Suite("Literal Expressibility")
    struct LiteralTests {

        @Test("string literal")
        func stringLiteral() {
            let value: JSONValue = "hello"
            #expect(value == .string("hello"))
        }

        @Test("int literal")
        func intLiteral() {
            let value: JSONValue = 42
            #expect(value == .int(42))
        }

        @Test("float literal")
        func floatLiteral() {
            let value: JSONValue = 3.14
            #expect(value == .double(3.14))
        }

        @Test("bool literal")
        func boolLiteral() {
            let trueVal: JSONValue = true
            let falseVal: JSONValue = false
            #expect(trueVal == .bool(true))
            #expect(falseVal == .bool(false))
        }

        @Test("nil literal")
        func nilLiteral() {
            let value: JSONValue = nil
            #expect(value == .null)
        }

        @Test("array literal")
        func arrayLiteral() {
            let value: JSONValue = [1, "two", true]
            #expect(value == .array([.int(1), .string("two"), .bool(true)]))
        }

        @Test("dictionary literal")
        func dictionaryLiteral() {
            let value: JSONValue = ["name": "test", "count": 5]
            #expect(value["name"] == .string("test"))
            #expect(value["count"] == .int(5))
        }
    }

    // MARK: - Convenience Accessors

    @Suite("Convenience Accessors")
    struct AccessorTests {

        @Test("stringValue accessor")
        func stringValue() {
            #expect(JSONValue.string("hello").stringValue == "hello")
            #expect(JSONValue.int(42).stringValue == nil)
            #expect(JSONValue.null.stringValue == nil)
        }

        @Test("intValue accessor")
        func intValue() {
            #expect(JSONValue.int(42).intValue == 42)
            #expect(JSONValue.string("42").intValue == nil)
            #expect(JSONValue.null.intValue == nil)
        }

        @Test("doubleValue accessor")
        func doubleValue() {
            #expect(JSONValue.double(3.14).doubleValue == 3.14)
            #expect(JSONValue.int(42).doubleValue == 42.0) // int coerces to double
            #expect(JSONValue.string("3.14").doubleValue == nil)
        }

        @Test("boolValue accessor")
        func boolValue() {
            #expect(JSONValue.bool(true).boolValue == true)
            #expect(JSONValue.bool(false).boolValue == false)
            #expect(JSONValue.int(1).boolValue == nil)
        }

        @Test("arrayValue accessor")
        func arrayValue() {
            let arr: [JSONValue] = [.int(1), .int(2)]
            #expect(JSONValue.array(arr).arrayValue == arr)
            #expect(JSONValue.object([:]).arrayValue == nil)
        }

        @Test("objectValue accessor")
        func objectValue() {
            let obj: [String: JSONValue] = ["key": .string("value")]
            #expect(JSONValue.object(obj).objectValue == obj)
            #expect(JSONValue.array([]).objectValue == nil)
        }

        @Test("isNull accessor")
        func isNull() {
            #expect(JSONValue.null.isNull == true)
            #expect(JSONValue.string("").isNull == false)
            #expect(JSONValue.int(0).isNull == false)
        }
    }

    // MARK: - Subscript Access

    @Suite("Subscript Access")
    struct SubscriptTests {

        @Test("object subscript by key")
        func objectSubscript() {
            let obj: JSONValue = .object(["name": .string("test"), "count": .int(5)])
            #expect(obj["name"] == .string("test"))
            #expect(obj["count"] == .int(5))
            #expect(obj["missing"] == nil)
        }

        @Test("array subscript by index")
        func arraySubscript() {
            let arr: JSONValue = .array([.string("a"), .string("b"), .string("c")])
            #expect(arr[0] == .string("a"))
            #expect(arr[1] == .string("b"))
            #expect(arr[2] == .string("c"))
            #expect(arr[3] == nil)
            #expect(arr[-1] == nil)
        }

        @Test("subscript on wrong type returns nil")
        func wrongTypeSubscript() {
            let str: JSONValue = .string("hello")
            #expect(str["key"] == nil)
            #expect(str[0] == nil)
        }

        @Test("chained subscript access")
        func chainedSubscript() {
            let nested: JSONValue = .object([
                "users": .array([
                    .object(["name": .string("Alice")])
                ])
            ])
            #expect(nested["users"]?[0]?["name"] == .string("Alice"))
        }
    }

    // MARK: - Decoding from Raw JSON

    @Suite("Decoding from JSON strings")
    struct DecodingTests {

        @Test("decode from JSON string")
        func decodeFromJSON() throws {
            let json = #"{"name": "test", "values": [1, 2, 3], "active": true}"#
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

            #expect(decoded["name"]?.stringValue == "test")
            #expect(decoded["values"]?[0]?.intValue == 1)
            #expect(decoded["active"]?.boolValue == true)
        }

        @Test("decode preserves number types")
        func decodeNumberTypes() throws {
            // Integer should decode as int
            let intJSON = "42"
            let intValue = try JSONDecoder().decode(JSONValue.self, from: intJSON.data(using: .utf8)!)
            #expect(intValue.intValue == 42)

            // Float should decode as double
            let floatJSON = "3.14"
            let floatValue = try JSONDecoder().decode(JSONValue.self, from: floatJSON.data(using: .utf8)!)
            #expect(floatValue.doubleValue != nil)
        }
    }
}
