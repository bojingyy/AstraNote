// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AstraNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AstraNotes", targets: ["AstraUI"])
    ],
    dependencies: [
        // Built-in to Swift; no external crypto dependencies needed
    ],
    targets: [
        // MARK: - AstraUI (App Target)
        .executableTarget(
            name: "AstraUI",
            dependencies: ["AstraCore", "AstraData", "AstraPlatform"],
            path: "Sources/AstraUI",
            resources: [
                .process("Assets.xcassets"),
                .copy("AstraNotes_Logo.png")
            ]
        ),
        
        // MARK: - AstraCore (Business Logic & Services)
        .target(
            name: "AstraCore",
            dependencies: ["AstraData", "AstraPlatform"],
            path: "Sources/AstraCore"
        ),
        .testTarget(
            name: "AstraCoreTests",
            dependencies: ["AstraCore", "AstraData", "AstraPlatform"],
            path: "Tests/AstraCoreTests"
        ),
        
        // MARK: - AstraData (Persistence Layer)
        .target(
            name: "AstraData",
            dependencies: ["AstraPlatform"],
            path: "Sources/AstraData"
        ),
        .testTarget(
            name: "AstraDataTests",
            dependencies: ["AstraData", "AstraPlatform"],
            path: "Tests/AstraDataTests"
        ),
        
        // MARK: - AstraPlatform (Platform Integrations)
        .target(
            name: "AstraPlatform",
            path: "Sources/AstraPlatform"
        ),
        .testTarget(
            name: "AstraPlatformTests",
            dependencies: ["AstraPlatform"],
            path: "Tests/AstraPlatformTests"
        ),
        
        // MARK: - Integration Tests
        .testTarget(
            name: "AstraIntegrationTests",
            dependencies: ["AstraCore", "AstraData", "AstraPlatform"],
            path: "Tests/AstraIntegrationTests"
        )
    ]
)
