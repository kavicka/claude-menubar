// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeMenuBar",
            path: "Sources/ClaudeMenuBar"
        )
    ]
)
