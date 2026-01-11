import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

/// The @MCPTool macro implementation.
///
/// Transforms a struct with a `run` function into a full Tool conformance.
///
/// Usage:
/// ```swift
/// @MCPTool("my_tool", "Description of the tool")
/// struct MyTool {
///     func run(message: String, count: Int = 10, context: MyContext) async throws -> String {
///         // implementation
///     }
/// }
/// ```
///
/// Generates:
/// - `typealias Context = <inferred from run>`
/// - `let name = "<provided>"`
/// - `let description = "<provided>"`
/// - `var inputSchema: JSONValue { ... }` based on run parameters
/// - `func execute(arguments:context:)` wrapper that unpacks and calls run()
public struct MCPToolMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract arguments from @MCPTool("name", "description")
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              arguments.count >= 2 else {
            throw MacroError("@MCPTool requires name and description arguments")
        }

        let nameArg = arguments[arguments.startIndex]
        let descArg = arguments[arguments.index(after: arguments.startIndex)]

        guard let nameLiteral = nameArg.expression.as(StringLiteralExprSyntax.self),
              let descLiteral = descArg.expression.as(StringLiteralExprSyntax.self) else {
            throw MacroError("@MCPTool arguments must be string literals")
        }

        let toolName = extractStringLiteral(nameLiteral)
        let toolDesc = extractStringLiteral(descLiteral)

        // Find the run function
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError("@MCPTool can only be applied to structs")
        }

        let runFunc = structDecl.memberBlock.members.compactMap { member -> FunctionDeclSyntax? in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self),
                  funcDecl.name.text == "run" else {
                return nil
            }
            return funcDecl
        }.first

        guard let runFunc = runFunc else {
            throw MacroError("@MCPTool requires a 'run' function")
        }

        // Parse parameters to extract context type and build schema
        let params = runFunc.signature.parameterClause.parameters
        var contextType: String = "NoContext"
        var schemaProperties: [(name: String, type: String, isOptional: Bool, hasDefault: Bool, defaultExpr: String?, isEnum: Bool)] = []

        for param in params {
            let paramName = (param.secondName ?? param.firstName).text
            let paramType = param.type.description.trimmingCharacters(in: .whitespaces)

            if paramName == "context" {
                contextType = paramType
                continue
            }

            let isOptional = paramType.hasSuffix("?")
            let hasDefault = param.defaultValue != nil
            let defaultExpr = param.defaultValue?.value.description.trimmingCharacters(in: .whitespaces)
            let isEnum = isEnumType(paramType)
            schemaProperties.append((paramName, paramType, isOptional, hasDefault, defaultExpr, isEnum))
        }

        // Generate schema properties code
        var propertiesLines: [String] = []
        for prop in schemaProperties {
            if prop.isEnum {
                let cleanType = prop.type.replacingOccurrences(of: "?", with: "")
                // Generate runtime enum schema using CaseIterable
                propertiesLines.append("\"\(prop.name)\": Schema.string(enum: \(cleanType).allCases.map { $0.rawValue })")
            } else {
                let schemaType = swiftTypeToSchema(prop.type)
                propertiesLines.append("\"\(prop.name)\": \(schemaType)")
            }
        }
        let propertiesCode = propertiesLines.joined(separator: ",\n                    ")

        // Required fields: not optional AND no default value
        let requiredFields = schemaProperties.filter { !$0.isOptional && !$0.hasDefault }.map { "\"\($0.name)\"" }
        let requiredCode = requiredFields.isEmpty ? "" : ", required: [\(requiredFields.joined(separator: ", "))]"

        // Generate argument unpacking code
        var unpackingLines: [String] = []
        for prop in schemaProperties {
            let cleanType = prop.type.replacingOccurrences(of: "?", with: "")
            let isDate = isDateType(prop.type)

            if prop.isEnum {
                // Enum type - convert from string via rawValue
                if prop.isOptional {
                    unpackingLines.append("let \(prop.name) = arguments[\"\(prop.name)\"]?.stringValue.flatMap { \(cleanType)(rawValue: $0) }")
                } else if prop.hasDefault {
                    unpackingLines.append("let \(prop.name) = arguments[\"\(prop.name)\"]?.stringValue.flatMap { \(cleanType)(rawValue: $0) }")
                } else {
                    // Required enum
                    unpackingLines.append("""
                    guard let \(prop.name)Raw = arguments["\(prop.name)"]?.stringValue,
                                  let \(prop.name) = \(cleanType)(rawValue: \(prop.name)Raw) else {
                                throw ToolError("Missing or invalid argument: \(prop.name)")
                            }
                    """)
                }
            } else if isDate {
                // Date type - parse ISO8601 string
                if prop.isOptional {
                    unpackingLines.append("let \(prop.name) = arguments[\"\(prop.name)\"]?.stringValue.flatMap { ISO8601DateFormatter().date(from: $0) }")
                } else if prop.hasDefault {
                    unpackingLines.append("let \(prop.name) = arguments[\"\(prop.name)\"]?.stringValue.flatMap { ISO8601DateFormatter().date(from: $0) }")
                } else {
                    // Required date
                    unpackingLines.append("""
                    guard let \(prop.name)String = arguments["\(prop.name)"]?.stringValue,
                                  let \(prop.name) = ISO8601DateFormatter().date(from: \(prop.name)String) else {
                                throw ToolError("Missing or invalid date argument: \(prop.name)")
                            }
                    """)
                }
            } else {
                let accessor = accessorForType(prop.type)
                if prop.isOptional || prop.hasDefault {
                    // Optional or has default - just try to get the value
                    unpackingLines.append("let \(prop.name) = arguments[\"\(prop.name)\"]\(accessor)")
                } else {
                    // Required - must be present
                    unpackingLines.append("""
                    guard let \(prop.name) = arguments["\(prop.name)"]\(accessor) else {
                                throw ToolError("Missing required argument: \(prop.name)")
                            }
                    """)
                }
            }
        }
        let unpackingCode = unpackingLines.joined(separator: "\n        ")

        // Generate the call arguments to run()
        var callArgParts: [String] = []
        for prop in schemaProperties {
            let isDate = isDateType(prop.type)
            if prop.isOptional {
                // Optional type - pass the value directly
                callArgParts.append("\(prop.name): \(prop.name)")
            } else if prop.hasDefault {
                // Has default - use nil coalescing with actual default or placeholder
                let defaultVal = prop.defaultExpr ?? defaultValuePlaceholder(prop.type)
                callArgParts.append("\(prop.name): \(prop.name) ?? \(defaultVal)")
            } else if prop.isEnum || isDate {
                // Required enum or date - pass directly (guard let ensures non-nil)
                callArgParts.append("\(prop.name): \(prop.name)")
            } else {
                // Required - pass directly
                callArgParts.append("\(prop.name): \(prop.name)")
            }
        }
        callArgParts.append("context: context")
        let callArgs = callArgParts.joined(separator: ", ")

        // Build the generated members
        var members: [DeclSyntax] = []

        // typealias Context
        members.append("public typealias Context = \(raw: contextType)")

        // let name
        members.append("public let name = \(literal: toolName)")

        // let description
        members.append("public let description = \(literal: toolDesc)")

        // inputSchema
        let schemaDecl: DeclSyntax = """
        public var inputSchema: JSONValue {
                Schema.object(
                    properties: [
                        \(raw: propertiesCode)
                    ]\(raw: requiredCode)
                )
            }
        """
        members.append(schemaDecl)

        // execute wrapper
        let executeDecl: DeclSyntax
        if unpackingCode.isEmpty {
            executeDecl = """
            public func execute(arguments: [String: JSONValue], context: \(raw: contextType)) async throws -> String {
                    return try await run(\(raw: callArgs))
                }
            """
        } else {
            executeDecl = """
            public func execute(arguments: [String: JSONValue], context: \(raw: contextType)) async throws -> String {
                    \(raw: unpackingCode)
                    return try await run(\(raw: callArgs))
                }
            """
        }
        members.append(executeDecl)

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let toolExtension: DeclSyntax = """
        extension \(type.trimmed): Tool {}
        """
        guard let ext = toolExtension.as(ExtensionDeclSyntax.self) else {
            return []
        }
        return [ext]
    }

    // MARK: - Helpers

    private static func extractStringLiteral(_ literal: StringLiteralExprSyntax) -> String {
        // Get the content between quotes
        literal.segments.description
    }

    private static func swiftTypeToSchema(_ type: String) -> String {
        let cleanType = type.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "?", with: "")

        switch cleanType {
        case "String":
            return "Schema.string()"
        case "Int":
            return "Schema.integer()"
        case "Double", "Float":
            return "Schema.number()"
        case "Bool":
            return "Schema.boolean()"
        case "Date":
            return "Schema.string(description: \"ISO8601 date string\")"
        case let t where t.hasPrefix("[") && t.hasSuffix("]"):
            let inner = String(t.dropFirst().dropLast())
            return "Schema.array(items: \(swiftTypeToSchema(inner)))"
        default:
            return "Schema.string()"
        }
    }

    private static func accessorForType(_ type: String) -> String {
        let cleanType = type.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "?", with: "")

        switch cleanType {
        case "String":
            return "?.stringValue"
        case "Int":
            return "?.intValue"
        case "Double", "Float":
            return "?.doubleValue"
        case "Bool":
            return "?.boolValue"
        default:
            return "?.stringValue"
        }
    }

    private static func defaultValuePlaceholder(_ type: String) -> String {
        let cleanType = type.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "?", with: "")

        switch cleanType {
        case "String":
            return "\"\""
        case "Int":
            return "0"
        case "Double", "Float":
            return "0.0"
        case "Bool":
            return "false"
        default:
            return "\"\""
        }
    }

    /// Detect if a type is likely a String enum (custom type, not a known primitive).
    /// Enums must conform to CaseIterable and RawRepresentable with String raw value.
    private static func isEnumType(_ type: String) -> Bool {
        let cleanType = type.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "?", with: "")

        // Known primitive types are not enums
        let knownTypes = ["String", "Int", "Double", "Float", "Bool", "Date"]
        if knownTypes.contains(cleanType) {
            return false
        }

        // Array types are not enums
        if cleanType.hasPrefix("[") && cleanType.hasSuffix("]") {
            return false
        }

        // Must start with uppercase letter (Swift type naming convention)
        guard let first = cleanType.first, first.isUppercase else {
            return false
        }

        return true
    }

    /// Check if a type is Date
    private static func isDateType(_ type: String) -> Bool {
        let cleanType = type.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "?", with: "")
        return cleanType == "Date"
    }
}

// MARK: - Error

struct MacroError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}

// MARK: - Plugin

@main
struct MCPServerMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MCPToolMacro.self,
    ]
}
