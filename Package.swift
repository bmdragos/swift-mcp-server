// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-mcp-server",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MCPServer", targets: ["MCPServer"]),
        .library(name: "MCPServerMacros", targets: ["MCPServerMacros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
    ],
    targets: [
        // Core library
        .target(name: "MCPServer"),
        .testTarget(name: "MCPServerTests", dependencies: ["MCPServer"]),

        // Macro implementation (compiler plugin)
        .macro(
            name: "MCPServerMacrosImpl",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Macro declarations (what users import)
        .target(
            name: "MCPServerMacros",
            dependencies: ["MCPServer", "MCPServerMacrosImpl"]
        ),

        // Macro tests
        .testTarget(
            name: "MCPServerMacrosTests",
            dependencies: [
                "MCPServerMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
