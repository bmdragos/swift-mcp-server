import Testing
import Foundation
@testable import MCPServer

@Suite("JSONRPC Tests")
struct JSONRPCTests {

    // MARK: - RequestID

    @Suite("RequestID")
    struct RequestIDTests {

        @Test("encode string ID")
        func encodeStringID() throws {
            let id = RequestID.string("abc-123")
            let data = try JSONEncoder().encode(id)
            let json = String(data: data, encoding: .utf8)!
            #expect(json == "\"abc-123\"")
        }

        @Test("encode int ID")
        func encodeIntID() throws {
            let id = RequestID.int(42)
            let data = try JSONEncoder().encode(id)
            let json = String(data: data, encoding: .utf8)!
            #expect(json == "42")
        }

        @Test("decode string ID")
        func decodeStringID() throws {
            let json = "\"request-1\""
            let id = try JSONDecoder().decode(RequestID.self, from: json.data(using: .utf8)!)
            #expect(id == .string("request-1"))
        }

        @Test("decode int ID")
        func decodeIntID() throws {
            let json = "123"
            let id = try JSONDecoder().decode(RequestID.self, from: json.data(using: .utf8)!)
            #expect(id == .int(123))
        }

        @Test("string and int IDs are not equal")
        func stringIntNotEqual() {
            #expect(RequestID.string("42") != RequestID.int(42))
        }
    }

    // MARK: - JSONRPCRequest

    @Suite("JSONRPCRequest")
    struct RequestTests {

        @Test("decode minimal request")
        func decodeMinimal() throws {
            let json = #"{"jsonrpc": "2.0", "method": "test"}"#
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)

            #expect(request.jsonrpc == "2.0")
            #expect(request.method == "test")
            #expect(request.id == nil)
            #expect(request.params == nil)
        }

        @Test("decode request with string ID")
        func decodeStringID() throws {
            let json = #"{"jsonrpc": "2.0", "id": "req-1", "method": "test"}"#
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)

            #expect(request.id == .string("req-1"))
        }

        @Test("decode request with int ID")
        func decodeIntID() throws {
            let json = #"{"jsonrpc": "2.0", "id": 42, "method": "test"}"#
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)

            #expect(request.id == .int(42))
        }

        @Test("decode request with params object")
        func decodeParamsObject() throws {
            let json = #"{"jsonrpc": "2.0", "id": 1, "method": "add", "params": {"a": 1, "b": 2}}"#
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)

            #expect(request.params?["a"]?.intValue == 1)
            #expect(request.params?["b"]?.intValue == 2)
        }

        @Test("decode tools/call request")
        func decodeToolsCall() throws {
            let json = #"""
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "echo",
                    "arguments": {
                        "message": "hello"
                    }
                }
            }
            """#
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)

            #expect(request.method == "tools/call")
            #expect(request.params?["name"]?.stringValue == "echo")
            #expect(request.params?["arguments"]?["message"]?.stringValue == "hello")
        }

        @Test("decode initialize request")
        func decodeInitialize() throws {
            let json = #"""
            {
                "jsonrpc": "2.0",
                "id": 0,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "clientInfo": {
                        "name": "test-client",
                        "version": "1.0.0"
                    }
                }
            }
            """#
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: json.data(using: .utf8)!)

            #expect(request.method == "initialize")
            #expect(request.params?["protocolVersion"]?.stringValue == "2024-11-05")
        }
    }

    // MARK: - JSONRPCResponse

    @Suite("JSONRPCResponse")
    struct ResponseTests {

        @Test("encode success response")
        func encodeSuccess() throws {
            let response = JSONRPCResponse(id: .int(1), result: .string("ok"))
            let data = try JSONEncoder().encode(response)
            let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

            #expect(decoded.jsonrpc == "2.0")
            #expect(decoded.id == .int(1))
            #expect(decoded.result?.stringValue == "ok")
            #expect(decoded.error == nil)
        }

        @Test("encode error response")
        func encodeError() throws {
            let error = JSONRPCError(code: -32600, message: "Invalid request")
            let response = JSONRPCResponse(id: .int(1), error: error)
            let data = try JSONEncoder().encode(response)
            let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

            #expect(decoded.result == nil)
            #expect(decoded.error?.code == -32600)
            #expect(decoded.error?.message == "Invalid request")
        }

        @Test("encode response with null ID")
        func encodeNullID() throws {
            let response = JSONRPCResponse(id: nil, error: .parseError("bad json"))
            let data = try JSONEncoder().encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"jsonrpc\":\"2.0\""))
            #expect(json.contains("-32700")) // parse error code
        }

        @Test("encode tool result response")
        func encodeToolResult() throws {
            let result: JSONValue = .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string("Hello, world!")
                    ])
                ])
            ])
            let response = JSONRPCResponse(id: .string("req-1"), result: result)
            let data = try JSONEncoder().encode(response)
            let decoded = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

            #expect(decoded.result?["content"]?[0]?["text"]?.stringValue == "Hello, world!")
        }
    }

    // MARK: - JSONRPCError

    @Suite("JSONRPCError")
    struct ErrorTests {

        @Test("standard error codes")
        func standardCodes() {
            #expect(JSONRPCError.parseError("test").code == -32700)
            #expect(JSONRPCError.invalidRequest("test").code == -32600)
            #expect(JSONRPCError.methodNotFound("test").code == -32601)
            #expect(JSONRPCError.invalidParams("test").code == -32602)
            #expect(JSONRPCError.internalError("test").code == -32603)
        }

        @Test("server error default code")
        func serverErrorDefault() {
            let error = JSONRPCError.serverError("something failed")
            #expect(error.code == -32000)
            #expect(error.message == "something failed")
        }

        @Test("server error custom code")
        func serverErrorCustom() {
            let error = JSONRPCError.serverError("custom error", code: -32050)
            #expect(error.code == -32050)
        }

        @Test("method not found includes method name")
        func methodNotFoundMessage() {
            let error = JSONRPCError.methodNotFound("unknown/method")
            #expect(error.message.contains("unknown/method"))
        }

        @Test("error with data")
        func errorWithData() throws {
            let error = JSONRPCError(
                code: -32000,
                message: "Tool failed",
                data: .object(["details": .string("more info")])
            )
            let data = try JSONEncoder().encode(error)
            let decoded = try JSONDecoder().decode(JSONRPCError.self, from: data)

            #expect(decoded.data?["details"]?.stringValue == "more info")
        }
    }

    // MARK: - Full Round-trip

    @Suite("Full Message Round-trip")
    struct RoundTripTests {

        @Test("request and response round-trip")
        func requestResponseRoundTrip() throws {
            // Simulate a tools/call request
            let requestJSON = #"""
            {
                "jsonrpc": "2.0",
                "id": 42,
                "method": "tools/call",
                "params": {
                    "name": "echo",
                    "arguments": {"message": "test"}
                }
            }
            """#

            let request = try JSONDecoder().decode(
                JSONRPCRequest.self,
                from: requestJSON.data(using: .utf8)!
            )

            // Verify request parsed correctly
            #expect(request.id == .int(42))
            #expect(request.method == "tools/call")

            // Create a response
            let response = JSONRPCResponse(
                id: request.id,
                result: .object([
                    "content": .array([
                        .object(["type": .string("text"), "text": .string("test")])
                    ])
                ])
            )

            // Encode and decode response
            let responseData = try JSONEncoder().encode(response)
            let decodedResponse = try JSONDecoder().decode(
                JSONRPCResponse.self,
                from: responseData
            )

            #expect(decodedResponse.id == .int(42))
            #expect(decodedResponse.result?["content"]?[0]?["text"]?.stringValue == "test")
        }
    }
}
