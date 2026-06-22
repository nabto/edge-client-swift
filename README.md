# Nabto Edge Client SDK wrapper for iOS / Swift

High-level Swift wrapper for the [Nabto Edge Client SDK](https://docs.nabto.com/developer.html). Distributed as a Swift Package; the underlying [low-level C SDK](https://docs.nabto.com/developer/api-reference/plain-c-client-sdk/intro.html) is pulled in as a binary `XCFramework` from the [nabto-client-sdk-releases](https://github.com/nabto/nabto-client-sdk-releases) repository.

Supports iOS 13+ and macOS 10.15+.

## Installation

### Xcode

`File` → `Add Package Dependencies…` and enter:

```
https://github.com/nabto/edge-client-swift
```

Add the `NabtoEdgeClient` library product to your target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/nabto/edge-client-swift", from: "4.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "NabtoEdgeClient", package: "edge-client-swift")
        ]
    )
]
```

For broader integration guidance, see the [iOS getting started guide](https://docs.nabto.com/developer/guides/get-started/ios/intro.html).

## Usage

See the [API intro](https://docs.nabto.com/developer/api-reference/ios-sdk/intro.html) for an overview of how to use the wrapper to invoke Nabto Edge devices.

A minimal SwiftUI example app lives in [`NabtoEdgeClientHello/`](NabtoEdgeClientHello/) — see its README for build instructions. For more detailed usage of individual SDK features, the [integration tests](Tests/NabtoEdgeClientTests/NabtoEdgeClientTests.swift) are the most complete reference.

## Development of the wrapper

```sh
git clone git@github.com:nabto/edge-client-swift.git
cd edge-client-swift
swift build
```

Or open `Package.swift` directly in Xcode:

```sh
open Package.swift
```

## Running tests

Most tests run against central Nabto-hosted test devices. A few cover mDNS discovery and require a local device — those are opt-in.

### Default run

```sh
swift test
```

mDNS-dependent tests skip with a clear message. This is what CI runs (see `.github/workflows/ci.yml`).

### Including the local mDNS tests

First start a local `simple_mdns_device` in another terminal:

```sh
git clone --recursive git@github.com:nabto/nabto-embedded-sdk.git
cd nabto-embedded-sdk
mkdir _build && cd _build
cmake -j ..
./examples/simple_mdns/simple_mdns_device pr-mdns de-mdns swift-test-subtype swift-txt-key swift-txt-val
```

Then run the suite with the opt-in flag:

```sh
NABTO_TEST_LOCAL_MDNS_DEVICE=1 swift test
```

From Xcode: open `Package.swift`, edit the `NabtoEdgeClientTests` scheme → `Run` → `Arguments` → `Environment Variables`, and add `NABTO_TEST_LOCAL_MDNS_DEVICE` = `1`. Then `Product` → `Test` (⌘U).
