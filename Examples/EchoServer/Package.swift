// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EchoServer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "EchoServer",
            dependencies: [
                .product(name: "MCPServer", package: "swift-mcp-server"),
            ]
        ),
    ]
)
