// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgentNotch",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "AgentNotch", targets: ["AgentNotch"])
    ],
    targets: [
        .executableTarget(
            name: "AgentNotch",
            path: "Sources/AgentNotch"
        )
    ],
    swiftLanguageModes: [.v5]
)
