// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NabtoEdgeClient",
    defaultLocalization: "en",
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
            url: "https://downloads.nabto.com/assets/edge/ios/api/0.0.5-nsurldebug/NabtoEdgeClientApiFW.xcframework.zip",
            checksum: "1819582a02520cdc8512a9eaac7e5a049d75a06d82ac93f56f46ba34a7a13c61"),
        .target(
            name: "NabtoEdgeClient",
            dependencies: ["NabtoEdgeClientApi", "CBORCoding"],
            path: "NabtoEdgeClient",
            exclude: ["NabtoEdgeClientTests", "HostForTests"]),
    ]
)
