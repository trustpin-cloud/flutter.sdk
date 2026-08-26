# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [6.3.0] - 2026-08-26

### Added

- `TrustPinConfiguration.embeddedConfigurationFile`: name of a signed
  configuration bundled with the app (an iOS/macOS bundle resource, an Android
  asset), used only when no online source and no previously fetched
  configuration is available, typically the app's very first start during an
  outage. It is verified against `publicKey` during setup. Intended only for
  apps whose bundled resources are protected by RASP; see "Embedded
  configuration" in the README.
- The same file can be declared in the platform configuration files read by
  `setupWithNativeBundle`: `EmbeddedConfigurationFile` in `TrustPin-Info.plist`,
  `embedded_configuration_asset` in `trustpin.json`.

### Changed

- Updated iOS/macOS native SDK to 6.3.0 and Android native SDK to 6.3.0.
- A configuration the SDK has fetched and validated is now retained on the
  device and remains usable after a process restart when every configuration
  source is unreachable.

## [6.2.0] - 2026-07-20

### Changed

- Updated iOS/macOS native SDK to 6.2.0 and Android native SDK to 6.2.0.
  Native dependencies now accept patch updates within 6.2.x instead of an
  exact pin (SwiftPM `upToNextMinor`, CocoaPods `~>`, Gradle
  `strictly("[6.2.0, 6.3.0)")`).

## [6.1.0] - 2026-07-09

### Added

- `TrustPin.validationEvents` — static broadcast stream of
  `TrustPinValidationEvent`, surfacing the native SDKs' new validation
  telemetry hook. Events fire for definitive pin verdicts only
  (`PINS_MISMATCH`, `ALL_PINS_EXPIRED`, `DOMAIN_NOT_REGISTERED` in strict
  mode, plus successes on registered domains) and are observe-only: the
  verdict is decided before the event is emitted. Failure events carry the
  presented leaf certificate as PEM. One stream covers all instances; the
  native listener is installed on first listen and removed on last cancel.
- `TrustPin.logs` — static broadcast stream of `TrustPinLogEvent`,
  surfacing the native SDKs' new global log sink. Routes SDK log output
  (level, instanceId, message) into the host app's logging pipeline; while
  no one listens the SDK keeps logging to its platform default. Per-instance
  verbosity remains controlled by `setLogLevel`. The native sink is
  installed on first listen and removed on last cancel.
- New Android-only error codes surfaced through `TrustPinException`:
  `SETUP_IN_PROGRESS` (`isSetupInProgress`), `LOCK_TIMEOUT`
  (`isLockTimeout`), `SSL_CONTEXT_SETUP_FAILED` (`isSslContextSetupFailed`),
  and `UNSUPPORTED_DEVICE` (`isUnsupportedDevice`). These cases previously
  collapsed into `INVALID_PROJECT_CONFIG`. An operation attempted before
  `setup` still maps to `INVALID_PROJECT_CONFIG` on every platform.

### Changed

- Updated iOS/macOS native SDK to 6.1.0 and Android native SDK to 6.1.2.
  No deployment-target or `minSdk` changes.
- Timeouts for `fetchCertificate` and `validateConnection` are now enforced
  by the native SDKs (`timeout:` overloads on iOS/macOS, the `timeout`
  parameter on Android) instead of a plugin-level race. For
  `validateConnection` the caller's timeout still bounds the composed
  operation: the verify phase receives whatever the fetch phase left of the
  budget. Timeouts keep surfacing as `FETCH_CERTIFICATE_TIMEOUT`.

## [6.0.0] - 2026-06-18

### Added

- `TrustPin.awaitConfiguration({timeout})` — explicit fail-closed gate that
  waits until the pinning configuration has been fetched, signature-verified,
  and accepted by the SDK's integrity check. Pairs with the now non-blocking
  `setup`.
- `TrustPin.isConfigurationLoaded` — synchronous, non-fetching state read
  reporting whether a validated pinning payload is currently cached.
- New error codes surfaced through `TrustPinException`: `ALREADY_INITIALIZED`
  (with `isAlreadyInitialized`) and `CONFIG_INTEGRITY_FAILED` (with
  `isConfigIntegrityFailed`).

### Changed

- Updated iOS/macOS native SDK to 6.0.0 and Android native SDK to 6.0.0.
- **Raised minimum deployment targets** to match TrustPinKit 6.0.0: iOS 15,
  macOS 13, watchOS 8, tvOS 15, visionOS 2. Apps consuming this plugin must
  raise their iOS deployment target to 15.0 (the sample app was updated to
  match). Android `minSdk` is unchanged at 25.
- **`setup` is now non-blocking and one-shot.** It performs local credential
  validation and starts a background preload of the pinning configuration; it
  no longer waits on the network. Fetch and validation errors now surface
  fail-closed from `validateConnection` / `verify`, or eagerly from
  `awaitConfiguration`, rather than from `setup`. Calling `setup` a second
  time on the same instance throws `ALREADY_INITIALIZED` — create a separate
  named instance via `TrustPin.instance(id)` for a different pinning context.
- Certificate verification is fail-closed in **both** strict and permissive
  modes: when no validated configuration is available, verification fails with
  `ERROR_FETCHING_PINNING_INFO` regardless of mode.
- **Internal:** the iOS and macOS native sources are now a single shared
  `darwin/` source set (`sharedDarwinSource`) instead of two near-identical
  copies, with `#if`-guarded platform differences. No effect on consumers —
  both CocoaPods and Swift Package Manager integration paths are unchanged.

## [5.0.0] - 2026-05-22

### Added

- iOS/macOS can initialize the SDK using a PList file
- Android can initialize SDK using a JSON file

### Changed

- Updated iOS/macOS native SDK to 5.0.0
- Updated Android native SDK to 5.0.0

## [4.3.0] - 2026-05-14

### Added

- `TrustPin.validateConnection(host, {port, timeout})` — atomic "is this
  connection allowed?" entry point. The platform composes the certificate
  fetch and pin verification inside a single channel call, so the certificate
  never enters the Dart isolate. The `timeout` argument bounds the entire
  operation, closing the gap where `verify` previously could not be
  time-limited.
- `TrustPinConfiguration.fromAssets` for loading the SDK configuration from a
  bundled `trustpin.json` asset (shares the JSON schema with the Android SDK)

### Changed

- `TrustPinHttpClient` and `TrustPinDioInterceptor` now route HTTPS requests
  through `validateConnection`. No source changes required for callers; every
  HTTPS request now takes one channel hop instead of two. The interceptors
  no longer hold any pinning-related Dart state (no caches, no in-flight
  tracking).
- Updated iOS/macOS native SDK to 4.3.1
- Updated Android native SDK to 4.3.2
- Aligned iOS/macOS Swift Package Manager manifests with the Swift 6.1
  toolchain requirement used by CocoaPods and documented in the README.
- iOS/macOS now reject malformed `configurationURL` values with
  `INVALID_PROJECT_CONFIG`, matching Android behavior.
- **Android minSdk bumped from 21 to 25** to match the requirement of the
  underlying `cloud.trustpin:kotlin-sdk:4.3.2`. Apps consuming this plugin
  must declare `minSdk >= 25` in their `android/app/build.gradle`.

### Deprecated

- `TrustPin.verify(domain, certificate)` and
  `TrustPin.fetchCertificate(host, {port, timeout})` are deprecated in favor
  of `TrustPin.validateConnection`. The deprecated methods still work and
  remain useful for diagnostic flows (for example, computing a SHA-256
  fingerprint from the raw PEM), but will be removed in a future major
  release. The same deprecations apply to the corresponding
  `TrustPinSDKPlatform` methods.

## [4.1.0] - 2026-05-02

### Changed

- Upgrade native SDKs to 4.1.0

## [4.0.0] - 2026-08-03

### Changed

- Improved CI/CD

## [3.3.0] - 2026-02-27

### Changed

- Updated SDKs to v3.3.0

## [3.0.1] - 2026-02-23

### Changed

- Added Swift Package Manager support for iOS and macOS
- Updated documentation

## [3.0.0] - 2026-02-19

### Added

- `fetchCertificate()` for OS-level TLS leaf certificate extraction
- `TrustPinConfiguration` class for SDK initialization
- `configurationURL` parameter for self-hosted configurations
- `TrustPinDioInterceptor` for Dio integration
- `TrustPinHttpClient` for http package integration
- `TrustPin.shared` and `TrustPin.instance('id')` for named instances

### Changed

- Renamed `TrustPinSDK` class to `TrustPin` with instance-based API
- Updated native SDKs

## [2.1.0] - 2026-02-09

### Changed

- Updated native SDKs
- Improved documentation

## [2.0.0] - 2026-01-26

### Added

- SPKI and AWS Certificate Manager support

### Changed

- Updated native SDKs

## [1.3.0] - 2026-01-23

### Changed

- Updated native SDKs

## [1.2.0] - 2025-08-14

### Changed

- Updated native SDKs

## [1.0.0] - 2025-08-05

### Added

- Initial release of TrustPin Flutter SDK
- SSL certificate pinning with SHA-256/SHA-512 public key pins
- Support for strict and permissive pinning modes
- Configurable logging levels
- iOS, Android, and macOS platform support
