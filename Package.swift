// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NabtoEdgeClient",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NabtoEdgeClient",
            targets: ["NabtoEdgeClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SomeRandomiOSDev/CBORCoding.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .binaryTarget(
            name: "NabtoEdgeClientApi",
            url: "https://raw.githubusercontent.com/nabto/nabto-client-sdk-releases/v5.15.3/lib/ios-xcframework/NabtoEdgeClientApi.xcframework.zip",
            checksum: "747669aca2c60c32e8653c2018020ca3a51b849c43c1487d71f6e5e992f3feb5"),
        .target(
            name: "NabtoEdgeClient",
            dependencies: ["NabtoEdgeClientApi", "CBORCoding"]),
        .testTarget(
            name: "NabtoEdgeClientTests",
            dependencies: ["NabtoEdgeClient"]),
    ]
)
