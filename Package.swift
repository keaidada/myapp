// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "myapp",
    platforms: [.macOS(.v14)],
    dependencies: [
        // CLT 的 swift-testing 安装不完整，从源码构建完整版
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "myapp",
            path: "Sources/myapp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "myappTests",
            dependencies: ["myapp", .product(name: "Testing", package: "swift-testing")],
            path: "Tests/myappTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
