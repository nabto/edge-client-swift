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
            url: "https://downloads.nabto.com/assets/edge/ios/api/0.0.6-nsurldebug/NabtoEdgeClientApiFW.xcframework.zip",
            checksum: "40d98461cbb299aa3be86b3469ad5c0c9b257cd5560f0177d40aeed90f3a19f9"),
//            url: "https://downloads.nabto.com/assets/edge/ios/api/0.0.5-nsurldebug/NabtoEdgeClientApiFW.xcframework.zip",
//            checksum: "9cdf35eb9438d0b010a074a70e5aeffe3e43fc75fcb9262f015b3dbb60aa8f2e"),
        .target(
            name: "NabtoEdgeClient",
            dependencies: ["NabtoEdgeClientApi", "CBORCoding"],
            path: "NabtoEdgeClient",
            exclude: ["NabtoEdgeClientTests", "HostForTests"]),
    ]
)
