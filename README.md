# Nabto Edge Client SDK wrapper for iOS / Swift

High level swift wrapper for the Nabto Edge Client SDK. See the [iOS guide](https://docs.nabto.com/developer/guides/get-started/ios/intro.html) to get started.

This wrapper depends on the [low-level](https://docs.nabto.com/developer/api-reference/plain-c-client-sdk/intro.html) NabtoEdgeClientApi [cocoapod](https://cocoapods.org/pods/NabtoEdgeClientApi).

For a general intro to Nabto Edge and its purpose and capabilities, see the overview on our [documentation site](https://docs.nabto.com/developer/guides/overview/platform-overview.html).

## Installation

Use the following Podfile to install through cocoapods:

```
target 'NabtoEdgeClientHello' do
    use_frameworks!
    pod 'NabtoEdgeClientSwift', '1.0.0'
end
```

## Development of wrapper

To build the wrapper, retrieving dependencies through CocoaPods:

```
git clone git@github.com:nabto/edge-client-swift.git
cd edge-client-swift/NabtoEdgeClient
pod install
open NabtoEdgeClient.xcworkspace
```

Alternatively, obtain the Nabto Edge Client SDK binary library directly from the [artifacts repo](https://github.com/nabto/nabto5-releases) instead of using CocoaPods.

## Running integration tests

Remote tests are run towards some central test devices.

To enable testing of mDNS discovery, run a local test device as follows:

```
git clone --recursive git@github.com:nabto/nabto-embedded-sdk.git
cd nabto-embedded-sdk
mkdir _build
cd _build
cmake -j ..
cd _build
./examples/simple_mdns/simple_mdns_device pr-mdns de-mdns swift-test-subtype swift-txt-key swift-txt-val
```

Execute test from xcode or commandline:

```
xcodebuild test -workspace "NabtoEdgeClient/NabtoEdgeClient.xcworkspace" -scheme NabtoEdgeClientTests \
  -destination 'platform=iOS Simulator,name=iPhone 8'
```

## Testing the resulting pod for Swift

Add local repo:

```
pod repo add local-repo ~/git/local-cocoapods-repo.git
```

Push spec to local repo:

```
pod repo push local-repo NabtoEdgeClientSwift.podspec
```
