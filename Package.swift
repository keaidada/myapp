// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppManager",
    platforms: [.macOS(.v14)],
    dependencies: [
        // CLT 的 swift-testing 安装不完整，从源码构建完整版
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "AppManager",
            path: "Sources/AppManager",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AppManagerTests",
            dependencies: ["AppManager", .product(name: "Testing", package: "swift-testing")],
            path: "Tests/AppManagerTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
