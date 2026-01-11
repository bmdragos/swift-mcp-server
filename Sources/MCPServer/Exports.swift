// Re-export all public types for convenience
// Users can just `import MCPServer` to get everything

// Note: All types are already public, this file exists for documentation
// and to ensure the module has a clear entry point.

/*
 Public API Summary:

 Types:
 - JSONValue          - Type-safe JSON representation
 - RequestID          - JSON-RPC request identifier
 - JSONRPCRequest     - Incoming request structure
 - JSONRPCResponse    - Outgoing response structure
 - JSONRPCError       - Error structure with standard codes

 Server:
 - MCPServer<Context> - Main server actor
 - ServerInfo         - Server name/version configuration
 - ServerCapabilities - Advertised capabilities
 - NoContext          - Placeholder for stateless servers

 Tools:
 - Tool               - Protocol for implementing tools
 - ToolRegistry       - Registry for managing tools
 - ToolError          - Error type for tool failures
 - ToolProvider       - Protocol for grouping related tools
 - Schema             - Helpers for building JSON schemas
*/
