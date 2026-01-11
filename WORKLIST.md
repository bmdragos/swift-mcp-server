# swift-mcp-server Worklist

## v1.0 - Core Library

### Tests (robustnessmaxxxing) ✅
- [x] JSONValue tests (119 tests total)
  - [x] Encode/decode round-trips for all types (null, bool, int, double, string, array, object)
  - [x] Literal expressibility (string, int, float, bool, array, dict, nil)
  - [x] Subscript access (object keys, array indices)
  - [x] Edge cases (nested structures, empty arrays/objects, special characters)
- [x] JSONRPC tests
  - [x] RequestID encoding (string and int variants)
  - [x] JSONRPCRequest parsing
  - [x] JSONRPCResponse encoding (success and error cases)
  - [x] JSONRPCError standard codes
- [x] Tool tests
  - [x] ToolRegistry registration and lookup
  - [x] ToolRegistry.listTools() output format
  - [x] ToolRegistry.call() dispatch
  - [x] ToolError handling
  - [x] Context-aware tools
- [x] Schema tests
  - [x] Schema.object() with properties and required
  - [x] Schema.string() with description and enum
  - [x] Schema.integer() with min/max
  - [x] Schema.number() with min/max
  - [x] Schema.boolean()
  - [x] Schema.array()
  - [x] Schema.empty
- [x] MCPServer integration tests
  - [x] Initialize handshake
  - [x] tools/list response format
  - [x] tools/call success and error responses
  - [x] End-to-end request/response cycle

### CI/CD ✅
- [x] GitHub Actions workflow for tests
- [x] Run tests on PR and push to main
- [x] Build examples in CI

---

## v1.1 - Extended Protocol

### Resources Support
- [ ] Resource protocol
- [ ] ResourceRegistry
- [ ] resources/list handler
- [ ] resources/read handler

### Prompts Support
- [ ] Prompt protocol
- [ ] PromptRegistry
- [ ] prompts/list handler
- [ ] prompts/get handler

---

## v1.2 - Advanced Features

### Progress & Logging
- [ ] Progress notification support for long-running tools
- [ ] Configurable logging (stderr verbosity levels)
- [ ] Structured logging output

### Developer Experience
- [ ] Better error messages with context
- [ ] Tool validation (schema validation before execute)
- [ ] Async tool timeout support

---

## Done
- [x] JSONValue enum with Codable
- [x] JSON-RPC 2.0 types
- [x] Tool protocol with generic context
- [x] ToolRegistry
- [x] Schema helpers
- [x] MCPServer actor with stdio transport
- [x] NoContext for stateless servers
- [x] EchoServer example
- [x] CreateMCP scaffolding tool
- [x] GitHub repo (bmdragos/swift-mcp-server)
- [x] Added to Claude Code config
