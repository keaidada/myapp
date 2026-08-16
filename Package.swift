// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AppManager",
            path: "Sources/AppManager",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AppManagerTests",
            dependencies: ["AppManager"],
            path: "Tests/AppManagerTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
