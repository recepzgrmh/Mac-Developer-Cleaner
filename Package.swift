// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DevReclaim",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DevReclaim", targets: ["DevReclaim"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DevReclaim",
            dependencies: [],
            path: "DevReclaim",
            exclude: ["Tests", "Info.plist"],
            sources: [
                "App",
                "Core",
                "UI",
                "Models"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DevReclaimTests",
            dependencies: ["DevReclaim"],
            path: "DevReclaim/Tests"
        )
    ]
)
