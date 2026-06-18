# NabtoEdgeClientHello

Minimal SwiftUI demo app for the Nabto Edge Client SDK. Consumes the SDK via the local Swift Package at `../`.

On launch it shows the SDK version. Tapping the button opens a Nabto Edge connection to a hardcoded test device and sends a CoAP `GET /hello-world`, displaying the status code and response body.

## Prerequisites

- macOS with Xcode 14+ installed
- [XcodeGen](https://github.com/yonki/XcodeGen) — `brew install xcodegen`
- An Apple Developer Team ID (for code signing)

## One-time setup

1. Create your local signing config:

   ```sh
   cp Signing.xcconfig.sample Signing.xcconfig
   ```

   Edit `Signing.xcconfig` and set `DEVELOPMENT_TEAM` to your Apple Developer Team ID. This file is gitignored.

2. Generate the Xcode project:

   ```sh
   xcodegen generate
   ```

   This produces `NabtoEdgeClientHello.xcodeproj` from `project.yml`. Re-run any time you change `project.yml` or add/remove source files.

## Running

### From Xcode

```sh
open NabtoEdgeClientHello.xcodeproj
```

Pick a simulator or device and hit Run.

### From the command line

```sh
xcodebuild \
  -project NabtoEdgeClientHello.xcodeproj \
  -scheme NabtoEdgeClientHello \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug \
  build

xcrun simctl boot 'iPhone 16' 2>/dev/null || true
open -a Simulator
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/NabtoEdgeClientHello-*/Build/Products/Debug-iphonesimulator/NabtoEdgeClientHello.app
xcrun simctl launch booted com.nabto.edge.NabtoEdgeClientHello
```

## Layout

```
NabtoEdgeClientHello/
├── project.yml                ← XcodeGen spec (committed)
├── Signing.xcconfig.sample    ← signing template (committed)
├── Signing.xcconfig           ← your team ID (gitignored)
├── README.md
└── NabtoEdgeClientHello/
    ├── NabtoEdgeClientHelloApp.swift
    ├── ContentView.swift
    └── Assets.xcassets/
```

The generated `NabtoEdgeClientHello.xcodeproj/` is not tracked — run `xcodegen generate` after cloning.
