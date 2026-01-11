// Re-export MCPServer so users only need one import
@_exported import MCPServer

/// Macro that transforms a struct into a Tool-conforming type.
///
/// Usage:
/// ```swift
/// @MCPTool("echo", "Echo back a message")
/// struct EchoTool {
///     func run(message: String, uppercase: Bool = false, context: NoContext) async throws -> String {
///         uppercase ? message.uppercased() : message
///     }
/// }
/// ```
///
/// The macro generates:
/// - `typealias Context` (inferred from run's context parameter)
/// - `let name` and `let description` (from macro arguments)
/// - `var inputSchema` (inferred from run parameters, excluding context)
/// - `func execute(arguments:context:)` wrapper that unpacks JSONValue arguments and calls run()
///
/// ## Parameter Type Mapping
/// - `String` → `Schema.string()`
/// - `Int` → `Schema.integer()`
/// - `Double`/`Float` → `Schema.number()`
/// - `Bool` → `Schema.boolean()`
/// - `[T]` → `Schema.array(items: ...)`
///
/// ## Required vs Optional
/// - Parameters without default values are marked as required in the schema
/// - Parameters with default values are optional
///
/// ## Example with Custom Context
/// ```swift
/// @MCPTool("counter", "Increment the counter")
/// struct CounterTool {
///     func run(context: CounterContext) async throws -> String {
///         String(await context.increment())
///     }
/// }
/// ```
@attached(member, names: named(Context), named(name), named(description), named(inputSchema), named(execute))
@attached(extension, conformances: Tool)
public macro MCPTool(_ name: String, _ description: String) = #externalMacro(
    module: "MCPServerMacrosImpl",
    type: "MCPToolMacro"
)
