// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AgentObservatory",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgentObservatory", targets: ["AgentObservatory"]),
        .library(name: "AgentObservatoryCore", targets: ["AgentObservatoryCore"])
    ],
    targets: [
        .target(name: "AgentObservatoryCore"),
        .executableTarget(
            name: "AgentObservatory",
            dependencies: ["AgentObservatoryCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AgentObservatoryCoreTests",
            dependencies: ["AgentObservatoryCore"]
        )
    ]
)
