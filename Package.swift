// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "cTab",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "cTab",
            path: "Sources/cTab",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "cTabTests",
            dependencies: ["cTab"],
            path: "Tests/cTabTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
