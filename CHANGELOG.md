# Changelog

## [4.0.1] - 2026-08-04

### Changed

* Update underlying Nabto Edge Client SDK to 5.15.4.

## [4.0.0] - 2026-06-23

### Changed

* Migrated distribution from CocoaPods to Swift Package Manager. The underlying Nabto Edge Client C SDK is now consumed as a binary `XCFramework` target pulled from [nabto-client-sdk-releases](https://github.com/nabto/nabto-client-sdk-releases) instead of via the `NabtoEdgeClientApi` pod.
* Source layout moved to the SPM convention: `Sources/NabtoEdgeClient/` and `Tests/NabtoEdgeClientTests/`.
* Example app rewritten as a SwiftUI project under `NabtoEdgeClientHello/`, consuming the wrapper as a local Swift Package.
* Tests that require a local `simple_mdns_device` are now opt-in via `NABTO_TEST_LOCAL_MDNS_DEVICE=1`; default `swift test` skips them cleanly so CI and contributors without a local device aren't blocked.
* Update underlying Nabto Edge Client SDK to 5.15.3.

### Removed

* CocoaPods podspec, Podfile, and `.xcworkspace`. The legacy `build.sh` / `sync.sh` pod-publishing helpers are no longer wired into any release flow.

## [3.2.0] - 2023-12-06

### Added

* Added Swift async support.

## [3.1.0] - 2023-01-22

### Added

* Added Connection.getType() to distinguish between .DIRECT and .RELAY connections.


## [3.0.4] - 2023-01-05

### Added

* Added PORT_IN_USE error code.

### Changed

* Update underlying Nabto Edge Client SDK to 5.12.0.

## [3.0.3] - 2022-09-14

### Changed

* Update underlying Nabto Edge Client SDK to 5.11.0.

## [3.0.2] - 2022-09-05

### Bug fixes

* Fixed crash in mDNS scanner that could occur if scan was stopped while a result callback was still active.

## [3.0.1] - 2022-08-31

### Bug fixes

* Fixed wrong visibility of members in NabtoEdgeClientLogMessage

## [3.0.0] - 2022-06-12

### Breaking

* Moved IamUtil helper class to separate pod NabtoEdgeIamUtil (as it introduced various dependencies, adding complexity for users of the plain client wrapper).

## [2.2.0]

### Adding

* Added IamUtil helper class to simplify pairing and user management.

## [2.1.0]

### Adding

* arm64 simulator support

## [2.0.0] - 2021-11-22

### Bug fixes
 * Fixed several leaks that could occur when stopping the client.
 * Fixed a crash that could occur during STUN.

### Breaking
 * Stream functions no longer return ABORTED but STOPPED instead (only reason for major version bump (semver compliance)).

## [1.1.2] - 2021-10-13

### Bug fixes
 * Fixed crashes if using Nabto 4/Micro and Nabto 5/Edge libs in the same app.
 * Fixed crashes that could occur when stopping the client.
