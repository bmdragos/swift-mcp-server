# swift-mcp-server Worklist

## Current Focus

### v1.0 Release ✅
- [x] Tag v1.0.0 release
- [x] Migrate serial-mcp to use library (dogfooding)
  - [x] Replace JSONValue with library version
  - [x] Replace JSONRPC types with library version
  - [x] Replace Tool/ToolRegistry with library version
  - [x] Replace MCPServer with library version
  - [x] Update Package.swift to depend on swift-mcp-server
  - [x] Run tests, verify everything works
  - [x] Document any API gaps discovered

#### Migration Notes (serial-mcp)
Changes required during migration:
- `inputSchema` return type: library uses `JSONValue`, not `[String: JSONValue]`
- `Schema.int()` → `Schema.integer()`
- `Schema.bool()` → `Schema.boolean()`
- Tools need explicit `typealias Context = YourContext`
- Context must conform to `Sendable` (actors work well)
- MCPServer init requires `ServerInfo` and `context` parameters

Lines of code removed: ~400 (MCP boilerplate)
Lines of code changed: ~20 (API adjustments)
Migration time: ~10 minutes

### v1.0.1 - Developer Experience
- [x] Schema aliases for migration ergonomics
  - [x] `Schema.int()` alias for `Schema.integer()`
  - [x] `Schema.bool()` alias for `Schema.boolean()`
  - [x] Add tests for aliases (122 tests total now)
- [x] Swift Macros for @MCPTool
  - [x] Design macro API (user writes `run()`, macro generates `execute()`)
  - [x] Implement macro package (MCPServerMacros, MCPServerMacrosImpl)
  - [x] Auto-generate name, description, inputSchema from function signature
  - [x] Add tests (9 tests for macro functionality, 131 total)

### v1.0.2 - Robustness ✅
- [x] Schema validation in ToolRegistry
  - [x] Validate required fields present
  - [x] Validate types match schema (string, integer, number, boolean, array)
  - [x] Validate numeric bounds (minimum/maximum)
  - [x] Validate string enums
  - [x] Add validation tests (17 tests)
- [x] Extended macro type support
  - [x] Optional types (String?) → not required in schema
  - [x] String enums (CaseIterable) → Schema.string(enum: [...])
  - [x] Add macro tests (21 tests total)

### v1.0.3 - Type Enhancements ✅
- [x] Date → Schema.string(description: "ISO8601 date string")
- [x] Enum default value handling (uses actual default from function signature)

### Future
- [ ] Resources support (if needed)
- [ ] Migrate corebluetooth-mcp
- [ ] Migrate xclaude (major undertaking)

---

## v1.0 - Core Library (COMPLETE)

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
- [x] v1.0.0 tagged and released
- [x] serial-mcp migrated to use library (first consumer!)
- [x] Schema aliases (int/bool) for migration ergonomics
- [x] @MCPTool macro for reduced boilerplate
- [x] Schema validation before tool execution (types, bounds, enums)
- [x] Optional type support in macro (T? → not required)
- [x] String enum support in macro (CaseIterable → enum values in schema)
- [x] Date type support in macro (ISO8601 parsing)
- [x] Enum default value handling (preserves actual defaults)
