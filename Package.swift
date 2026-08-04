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
            url: "https://raw.githubusercontent.com/nabto/nabto-client-sdk-releases/v5.15.4/lib/ios-xcframework/NabtoEdgeClientApi.xcframework.zip",
            checksum: "d7a54670e1cd8b1f9616207eebfc60f15ac45c7ec6d080cbf6f8d234986e8b60"),
        .target(
            name: "NabtoEdgeClient",
            dependencies: ["NabtoEdgeClientApi", "CBORCoding"]),
        .testTarget(
            name: "NabtoEdgeClientTests",
            dependencies: ["NabtoEdgeClient"]),
    ]
)
