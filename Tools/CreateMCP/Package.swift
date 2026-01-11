// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CreateMCP",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "CreateMCP",
            dependencies: [
                .product(name: "MCPServer", package: "swift-mcp-server"),
            ]
        ),
    ]
)
