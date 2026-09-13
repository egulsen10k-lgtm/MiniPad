// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiniPad",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MiniPad", targets: ["MiniPad"])
    ],
    targets: [
        .executableTarget(
            name: "MiniPad",
            path: "MacNotchPro",
            resources: [
                .process("Assets.xcassets")
            ],
            linkerSettings: [
                .unsafeFlags(["-framework", "MediaPlayer"])
            ]
        ),
        .testTarget(
            name: "MiniPadTests",
            dependencies: ["MiniPad"],
            path: "Tests/MacNotchProTests"
        )
    ]
)
