# Nabto Edge Client SDK wrapper for iOS / Swift

High level swift wrapper for the [Nabto Edge Client SDK](https://docs.nabto.com/developer.html). Depends on the [low-level](https://docs.nabto.com/developer/api-reference/plain-c-client-sdk/intro.html) NabtoEdgeClientApi [cocoapod](https://cocoapods.org/pods/NabtoEdgeClientApi).

## Installation

Use the following Podfile to install through cocoapods:

```
target 'NabtoEdgeClientHello' do
    use_frameworks!
    pod 'NabtoEdgeClientSwift', '0.9.0'
end
```

## Development of wrapper

To build the wrapper:

```
git clone git@github.com:nabto/edge-client-swift.git
cd edge-client-swift/NabtoEdgeClient
pod install
open NabtoEdgeClient.xcworkspace
```

## Testing pod

Add local repo:

```
pod repo add local-repo ~/git/local-cocoapods-repo.git
```

Push spec to local repo:

```
pod repo push local-repo NabtoEdgeClientSwift.podspec
```
