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
            exclude: ["Tests"],
            sources: [
                "App",
                "Core",
                "UI",
                "Models",
                "Resources"
            ]
        ),
        .testTarget(
            name: "DevReclaimTests",
            dependencies: ["DevReclaim"],
            path: "DevReclaim/Tests"
        )
    ]
)
