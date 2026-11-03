# TrustPin App Attestation for Flutter

[![pub package](https://img.shields.io/pub/v/trustpin_attest.svg)](https://pub.dev/packages/trustpin_attest)

Prove to your API that a request comes from your genuine app on a genuine
device that meets your policy. The device attests once per device key to
**your own** TrustPin verifier, then renews a short-lived token cheaply. The
token travels in the `TrustPin-Attestation` header, and your API or gateway
verifies it.

| Platform | Minimum | Evidence |
|---|---|---|
| iOS | 15 | Apple App Attest |
| macOS | 13 | Apple App Attest |
| Android | API 25 | Android Key Attestation; Play Integrity where Google Play services exist |

This package wraps the native TrustPin attestation modules
(`TrustPinAttestKit` on iOS and macOS, `cloud.trustpin:kotlin-attest` on
Android) and works with the [`trustpin_sdk`](https://pub.dev/packages/trustpin_sdk)
pinning package, which it requires: the SDK pins its calls to your verifier.

Attestation is not runtime protection: it doesn't detect hooking, debugging,
tampering, root or jailbreak. Setup, the policy, deploying the verifier and
verifying tokens in your API are covered at
[docs.trustpin.cloud](https://docs.trustpin.cloud).

## Installation

```yaml
dependencies:
  trustpin_sdk: ^7.1.1
  trustpin_attest: ^7.1.1
```

Both packages must be on the same version. They wrap the native 7.1.x SDKs
(`TrustPinAttestKit`, `cloud.trustpin:kotlin-attest`).

> **Flutter 3.44.0 or later; iOS and macOS through Swift Package Manager
> only.** From 7.1.0 the plugin ships no podspec. Flutter 3.44 is the first
> stable release with Swift Package Manager on by default; if you turned it
> off, turn it back on:
> ```bash
> flutter config --enable-swift-package-manager
> ```

## Before you write code

- **The policy:** in the TrustPin console, list your app (Team ID and bundle
  ID, or package name and signing-certificate digests) and publish the policy.
- **Your verifier:** deployed and reachable from the app, and its host
  registered as a domain of your TrustPin project, because verifier calls are
  pinned. In strict mode an unregistered verifier host fails every call
  (`VERIFIER_UNAVAILABLE`) and no header is sent. It must speak contract
  version 2 or newer (verifier 1.0.0 or later); an older one is refused
  (`VERIFIER_INCOMPATIBLE`).
- **iOS and macOS:** add the **App Attest** capability to the Runner target.
  It adds the entitlement `com.apple.developer.devicecheck.appattest-environment`:
  `development` for builds run from Xcode, `production` for TestFlight and
  the App Store.
- **Android with Play Integrity:** the Google Cloud project number of the
  project linked in Play Console (see Configure).

## Configure

Add the attestation keys to the configuration files the pinning setup reads:

**iOS, macOS: `TrustPin-Info.plist`**

```xml
<key>AttestVerifierURL</key>
<string>https://attest.example.com</string>
<key>AttestedHosts</key>
<array>
    <string>api.example.com</string>
</array>
```

**Android: `android/app/src/main/assets/trustpin.json`**

```json
{
  "attest_verifier_url": "https://attest.example.com",
  "attested_hosts": ["api.example.com"]
}
```

Add `"google_cloud_project_number"` only when your policy uses Play Integrity:
with a number, the app contacts Google Play services from setup on.

- The verifier URL must be `https://` on a host name, without credentials,
  query or fragment. IP addresses are refused.
- Attested hosts: one to fifty host names, each exact or `*.example.com` for
  exactly one label. Only these hosts ever receive the header.

Or configure in code with `TrustPinAttestConfiguration` and `setup`.

## Set up

Once per launch, after pinning:

```dart
import 'package:trustpin_attest/trustpin_attest.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

await TrustPin.shared.setupWithNativeBundle();
await TrustPinAttest.shared.setupWithNativeBundle();
await TrustPinAttest.shared.bindToHeader('Authorization');
await TrustPinAttest.shared.prefetch();
```

`setup` makes no verifier call: it validates the configuration and loads a
device key from an earlier launch. A second call throws `ALREADY_INITIALIZED`.
`prefetch()` never throws.

Named instances pair with pinning instances of the same id:
`TrustPinAttest.instance('id')` with `TrustPin.instance('id')`, which must be
set up first.

## Bind tokens to the user's session

- `bindToHeader('Authorization')` binds each token to the value of that
  request header.
- `setTokenBinding(value)` binds to a fixed value, such as a session id.

Each clears the other. `setTokenBinding(null)` removes the fixed binding
only; `bindToHeader(null)` stops header binding and also clears a fixed
binding. Only a SHA-256 of the value leaves the device. A
binding change renews the token with the existing device key; it's not a new
attestation.

If your policy has **Require token binding** on, no token exists until a
binding is known: the state is failed with `BINDING_REQUIRED` and no retry
time. That's expected before sign-in, and attestation resumes as soon as a
binding is set.

## Send the header

`trustpin_sdk`'s HTTP integrations add the header automatically to HTTPS
requests for the attested hosts:

```dart
// package:http
final client = TrustPinHttpClient.create();

// Dio: pass the instance so redirects of attested requests are followed
final dio = Dio();
dio.interceptors.add(TrustPinDioInterceptor(dio: dio));
```

- Requests are never failed by the SDK: when no token is ready in a short,
  bounded time, the request goes out **without** the header, and your API
  decides.
- A header the request already carries is never replaced.
- A redirect never carries the header to another host: the integrations
  follow redirects of attested `GET` and `HEAD` requests themselves, pinning
  each hop and asking for its own header.

For other HTTP clients:

```dart
final headers = await TrustPin.shared.attestationHeaders(
  uri,
  headers: {'Authorization': 'Bearer $session'},
);
```

and `TrustPin.shared.redirectedRequestHeaders(...)` for each redirect hop.
For non-HTTP transports (gRPC, WebSockets), `await TrustPinAttest.shared.getToken()`
and send it in the `TrustPin-Attestation` header.

The interceptors check the server's certificate before each request; the
request itself goes out on Dart's own connection. Binding the token to the
session keeps a token useless outside it.

## Sensitive operations: assertions

For an operation that must come from this device, such as a payment, send an
assertion next to the token. It binds the device's attested key to a SHA-256
digest of your choice, typically the request body:

```dart
import 'package:crypto/crypto.dart';

final body = utf8.encode(jsonEncode({'amount': '1.00', 'to': 'demo'}));
final headers = {'Authorization': 'Bearer $session'};
// With header binding, ask for this request's token first, so it is bound to
// this Authorization value; then add the assertion.
headers.addAll(await TrustPinAttest.shared
    .attestationHeaders(url, method: 'POST', headers: headers));
headers.addAll(await TrustPinAttest.shared
    .assertionHeaders(Uint8List.fromList(sha256.convert(body).bytes)));
await client.post(url, headers: headers, body: body);
```

- `assertionHeaders` returns both headers, `TrustPinAttest.headerName` with
  the token and `TrustPinAttest.assertionHeaderName` (`TrustPin-Assertion`)
  with the assertion. Each call produces a new assertion: one per operation.
- Your backend passes both headers and its own digest of what it received to
  your verifier.
- It throws `INVALID_DIGEST` when the digest isn't 32 bytes, and the usual
  codes when no token is available.

## Verify the token in your API

Your API verifies the token against your verifier's JWKS: signature (`ES256`),
type `trustpin-attest+jwt`, issuer, audience and expiry, the project
(`tp.prj`), the binding, and that it isn't a debug token in production. In
monitor mode, a `fail` result is expected: log `tp.reasons` and allow. See
[docs.trustpin.cloud](https://docs.trustpin.cloud).

## Simulators, emulators and debug tokens

Simulators and emulators can't produce real evidence. Pass a debug token from
the build, never from a file:

```dart
const debugToken = String.fromEnvironment('TRUSTPIN_DEBUG_TOKEN');
await TrustPinAttest.shared.setupWithNativeBundle(
  debugToken: debugToken.isEmpty ? null : debugToken,
);
```

```bash
flutter run --dart-define=TRUSTPIN_DEBUG_TOKEN=<token>
```

- It's used on the iOS simulator and in debuggable Android builds
  (emulators and devices), never on iOS devices or macOS, and never sent in
  release builds.
- On Android, a debug token identifies the app by the package name it runs
  under, so a debug build with an `applicationIdSuffix` must be listed in the
  policy as its own package.
- Your policy (**Allow debug tokens**) and your verifier must both allow
  debug tokens. Their tokens carry `tp.env` `debug`, which production APIs
  refuse.

## State, errors and logging

```dart
TrustPinAttest.shared.stateChanges.listen((state) {
  final label = switch (state) {
    TrustPinAttestUnavailable() => 'No token yet',
    TrustPinAttestAttesting() => 'Attesting…',
    TrustPinAttestReady(:final expiresAt) => 'Token ready until $expiresAt',
    TrustPinAttestFailed(:final error, :final retryAt) =>
      'Failed: ${error.code}, next attempt after ${retryAt ?? 'restart'}',
  };
  print(label);
});
```

- `stateChanges` emits the current state first, then every change.
- `events` reports what the SDK did, for your monitoring: keys generated or
  replaced, attestations and renewals with their durations, refusals and
  waits with their end, unsupported devices, an unreachable verifier, and
  assertions. Events never contain a token, a key or a device identifier.
  New event types can appear in a minor release: keep a default case.

```dart
TrustPinAttest.shared.events.listen((event) {
  if (event case TrustPinAttestAttestationSucceeded(:final duration)) {
    metrics.record('attestation', duration);
  }
});
```

- After a failure no timer runs: nothing is tried before `retryAt`, and the
  next request, `getToken()` or `prefetch()` after it starts a new attempt. A
  `null` `retryAt` means no new attempt in this launch, until `reset()` or a
  restart, except `BINDING_REQUIRED`, which resumes once a binding is set.
- Errors are `TrustPinAttestException` with a stable `code`:

| Code | Meaning |
|---|---|
| `INVALID_CONFIGURATION` | A configuration value was rejected, or the file is missing |
| `ALREADY_INITIALIZED` | `setup` was called again |
| `NOT_SET_UP` | Called before `setup` |
| `UNSUPPORTED_DEVICE` | This device can't attest the app (for example, a Mac without App Attest), or new keys keep failing on it |
| `EVIDENCE_UNAVAILABLE` | The device can't produce the evidence the policy requires |
| `BINDING_REQUIRED` | The policy requires a binding and none is set yet |
| `ATTESTATION_FAILED` | The verifier refused; see `reasons` |
| `VERIFIER_UNAVAILABLE` | The verifier couldn't be reached, including when strict pinning refuses its host |
| `VERIFIER_INCOMPATIBLE` | The verifier is too old for this SDK; update it |
| `INVALID_DIGEST` | `assertionHeaders` got a digest that isn't 32 bytes |

  New codes can appear in a minor release: handle unknown ones.

- Logging is off by default: `setLogLevel(TrustPinAttestLogLevel.debug)` in
  development, and `TrustPinAttest.logs` to route messages. Logs never
  contain tokens, key certificates, bound values or debug tokens.
- `reset()` discards the device key, so the token's `sub` changes. It's for
  support flows, not routine use, and does nothing before setup.

## Backups and privacy

- Device keys and key certificates are never backed up or synced: a restored
  app attests again.
- Evidence and tokens go only to your verifier, nothing to TrustPin.
- iOS and macOS: the Swift package ships a privacy manifest (no tracking, no
  collected data).
- Android: with a Google Cloud project number configured, the app uses the
  Play Integrity API; declare it in Play Console's Data safety form.

## Example

The [sample app](https://github.com/trustpin-cloud/flutter.sdk/tree/main/sample_app)
has an **Attestation** tab: setup, a protected call with a token bound to the
`Authorization` header, a sensitive call with an assertion, sign-out and
reset, with the SDK's events in the tab's log.
