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
            url: "https://raw.githubusercontent.com/nabto/nabto-client-sdk-releases/v5.15.5/lib/ios-xcframework/NabtoEdgeClientApi.xcframework.zip",
            checksum: "2276fef0535beb0045f4f18fa398d477416e9fd791b051a7344fc0b01f6dcac0"),
        .target(
            name: "NabtoEdgeClient",
            dependencies: ["NabtoEdgeClientApi", "CBORCoding"]),
        .testTarget(
            name: "NabtoEdgeClientTests",
            dependencies: ["NabtoEdgeClient"]),
    ]
)
