// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-mcp-server",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MCPServer", targets: ["MCPServer"]),
    ],
    targets: [
        .target(name: "MCPServer"),
        .testTarget(name: "MCPServerTests", dependencies: ["MCPServer"]),
    ]
)
