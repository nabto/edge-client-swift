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
            url: "https://downloads.nabto.com/assets/edge/ios/api/0.0.7-nsurldebug/NabtoEdgeClientApiFW.xcframework.zip",
            checksum: "78990743fcc058a170e1610afeff4a50f715b2ef952f5c0c9b45f8b9e1658b86"),
//            url: "https://downloads.nabto.com/assets/edge/ios/api/0.0.5-nsurldebug/NabtoEdgeClientApiFW.xcframework.zip",
//            checksum: "9cdf35eb9438d0b010a074a70e5aeffe3e43fc75fcb9262f015b3dbb60aa8f2e"),
        .target(
            name: "NabtoEdgeClient",
            dependencies: ["NabtoEdgeClientApi", "CBORCoding"],
            path: "NabtoEdgeClient",
            exclude: ["NabtoEdgeClientTests", "HostForTests"]),
    ]
)
