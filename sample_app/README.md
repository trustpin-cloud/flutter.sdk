# TrustPin Flutter Sample App

A sample Flutter application for the TrustPin SDKs: certificate pinning
(`trustpin_sdk`) and app attestation (`trustpin_attest`). It has the same two
tabs as the native SDKs' sample apps.

## Features

**Pinning tab**
- **TrustPin Configuration**: set up pinning with inline credentials, or from
  the native bundle file (`TrustPin-Info.plist`, `trustpin.json`).
- **Connection Testing**: a pinned HTTPS GET through `TrustPinHttpClient`, and
  **Fetch Certificate** to see the certificate a server presents.
- **Pinning Log**: the sample's steps, pin-validation events
  (`TrustPin.validationEvents`) and the SDK's own log (`TrustPin.logs`).

**Attestation tab**
- **Set Up Attestation**: `TrustPinAttest.shared.setupWithNativeBundle()`,
  tokens bound to the `Authorization` header, and a prefetch.
- **Call Protected Endpoint**: signs in to the sample API (`POST /login`), then
  calls `GET /home` with the bearer token. `TrustPinHttpClient` adds the
  `TrustPin-Attestation` header; the card shows the HTTP status, whether the
  header was attached, and what the API verified.
- **Sensitive Call (Token + Assertion)**: posts `POST /transfer` with the
  token and `TrustPinAttest.shared.assertionHeaders(...)` over the SHA-256 of
  the body; the API checks the assertion with the verifier.
- **Sign Out (New Session)**: drops the session. The next call signs in again,
  and the new `Authorization` value re-binds the token: a token renewal, not a
  new device key.
- **Reset Attestation**: discards the device key; the next call attests a new
  one.
- The attestation state, and an **Attestation Log** with the module's own log
  (`TrustPinAttest.logs`) and its events (`TrustPinAttest.shared.events`, one
  `[Event]` line each).

## Running the Sample

> **Flutter 3.44.0 or later; iOS / macOS use Swift Package Manager only.**
> From 7.1.0 the TrustPin plugins ship no podspec, and this app has no
> `Podfile`. Flutter 3.44 has Swift Package Manager on by default; if you
> turned it off, turn it back on:
> ```bash
> flutter config --enable-swift-package-manager
> ```

1. Create the configuration files (below).
2. Install dependencies and run:
   ```bash
   cd sample_app
   flutter pub get
   flutter run
   ```

## Configuration

These files contain real credentials and are git-ignored; a `.example`
template is committed at each path. Copy each template to the real filename
and fill it in:

```bash
cp android/app/src/main/assets/trustpin.json.example  android/app/src/main/assets/trustpin.json
cp ios/Runner/TrustPin-Info.plist.example             ios/Runner/TrustPin-Info.plist
cp macos/Runner/TrustPin-Info.plist.example           macos/Runner/TrustPin-Info.plist
cp assets/api-test.json.example                       assets/api-test.json
```

- **Pinning:** your project's organization ID, project ID and public key, from
  [app.trustpin.cloud](https://app.trustpin.cloud).
- **Attestation:** your verifier's URL (`AttestVerifierURL`,
  `attest_verifier_url`) and the hosts that receive the header
  (`AttestedHosts`, `attested_hosts`). On Android, add
  `google_cloud_project_number` only if your policy uses Play Integrity.
- **Sample API** (`assets/api-test.json`): the API that verifies the tokens,
  and its demo credentials.

On iOS/macOS, the copied `TrustPin-Info.plist` must be in the Runner target so
it lands inside the `.app` bundle (it already is in this project).

### App IDs and the attestation policy

The verifier only attests apps its policy lists. This sample uses the IDs of
TrustPin's own native sample apps:

| Platform | App ID |
|---|---|
| iOS, macOS | Team `Z24JQDN8PT`, bundle ID `cloud.trustpin.swift.testapp`, with the App Attest capability (`Runner.entitlements`, `development`) |
| Android | Package `cloud.trustpin.android.sample`, signed with the debug key |

To run it against your own project, change them to your own (the Runner's
bundle ID and team in Xcode, `applicationId` in
`android/app/build.gradle.kts`) and list them in your policy.

The sample replaces the native sample app with the same ID on a device, and a
device key that app made is lost.

### Simulators and emulators: debug tokens

Simulators and emulators can't produce real attestation evidence. Pass a debug
token from the build; it's used only in debug builds, and only when your
policy (**Allow debug tokens**) and your verifier allow debug tokens:

```bash
flutter run --dart-define=TRUSTPIN_DEBUG_TOKEN=<token>
```

Never put the token in a configuration file.

## Checking the attestation bridge

`integration_test/attestation_bridge_test.dart` runs every attestation call
through the platform channel on a device or emulator and prints the states and
logs:

```bash
flutter test integration_test/attestation_bridge_test.dart -d <device>
```

Without a debug token, an emulator ends in a failed state (its key attestation
isn't trusted); the test checks that the failure arrives as a state.

## Building from Xcode

`flutter run` and `flutter build` work as is. Before building from Xcode after
a `flutter pub get` or `flutter clean`, run:

```bash
flutter build macos --config-only    # and/or: flutter build ios --config-only
```

Otherwise Xcode fails with a Swift Package Manager platform error:

```
The package product 'trustpin-sdk-product' requires minimum platform version 13.0
for the macOS platform, but this target supports 12.0
```

The TrustPin plugins need macOS 13 and iOS 15. Flutter raises the generated
`FlutterGeneratedPluginSwiftPackage` wrapper to the Xcode project's deployment
target (`MACOSX_DEPLOYMENT_TARGET` 13.0, `IPHONEOS_DEPLOYMENT_TARGET` 15.0 in
this sample) only when it builds, `--config-only` included; `flutter pub get`
resets it to Flutter's default.

The macOS Runner signs with your Apple Development certificate (the App Attest
entitlement requires it).

## Note

This sample app is independent of the main SDK's CI/CD pipeline and is intended for development and testing purposes only.
