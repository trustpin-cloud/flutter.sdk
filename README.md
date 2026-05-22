# TrustPin SDK for Flutter

[![pub package](https://img.shields.io/pub/v/trustpin_sdk.svg)](https://pub.dev/packages/trustpin_sdk)
[![documentation](https://img.shields.io/badge/documentation-GitHub%20Pages-blue)](https://trustpin-cloud.github.io/flutter.sdk/)
[![platform](https://img.shields.io/badge/platform-flutter-blue)](https://flutter.dev)
[![platform](https://img.shields.io/badge/platform-dart-blue)](https://dart.dev)

A comprehensive Flutter plugin for **[TrustPin](https://trustpin.cloud)** SSL certificate pinning that provides robust security against man-in-the-middle (MITM) attacks by validating server certificates against pre-configured public key pins.

> Get started at [TrustPin.cloud](https://trustpin.cloud) | Manage your certificates in the [Cloud Console](https://app.trustpin.cloud)

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Platform Setup](#platform-setup)
- [Quick Start](#quick-start)
- [Advanced Usage](#advanced-usage)
- [API Reference](#api-reference)
- [Error Handling](#error-handling)
- [Example App](#example-app)

## Features

- **SSL Certificate Pinning**: Advanced certificate validation using SHA-256/SHA-512 public key pins
- **Signed Configuration**: Cryptographically signed pinning configurations
- **Cross-platform Support**: Native implementations for iOS (Swift), Android (Kotlin), and macOS (Swift)
- **Flexible Pinning Modes**: Support for strict (production) and permissive (development) validation modes
- **Certificate Fetching**: Built-in `fetchCertificate` for OS-level TLS validation and leaf certificate extraction
- **HTTP Client Integration**: Built-in interceptors for Dio and the http package
- **Multiple Instances**: Use `TrustPin.shared` for single-project apps, or `TrustPin.instance('id')` for libraries and multi-tenant setups
- **Comprehensive Error Handling**: Detailed error types with programmatic checking capabilities
- **Configurable Logging**: Multiple log levels for debugging, monitoring, and production use
- **Thread Safety**: Built with Flutter's async/await pattern and native concurrency models

## Installation

Add TrustPin SDK to your `pubspec.yaml`:

```yaml
dependencies:
  trustpin_sdk: ^5.0.0
```

Then install the package:

```bash
flutter pub get
```

## Platform Setup

### iOS Requirements

- **Minimum iOS Version**: 13.0+
- **Xcode**: 16.3+
- **Swift**: 6.1+
- **Native Dependencies**: TrustPinKit 5.0.0 (automatically configured via Swift Package Manager or CocoaPods)

### macOS Requirements

- **Minimum macOS Version**: 13.0+
- **Xcode**: 16.3+
- **Swift**: 6.1+
- **Native Dependencies**: TrustPinKit 5.0.0 (automatically configured via Swift Package Manager or CocoaPods)

> Set `MACOSX_DEPLOYMENT_TARGET = 13.0` (or higher) in your Xcode project's
> build settings. Flutter uses this value to align the generated Swift Package
> Manager wrapper with TrustPin's minimum platform.

For sandboxed macOS apps, add the network client entitlement:

```xml
<!-- In DebugProfile.entitlements and Release.entitlements -->
<key>com.apple.security.network.client</key>
<true/>
```

### Android Requirements

- **Minimum SDK**: API 25 (Android 7.1)+
- **Compile SDK**: API 36
- **Kotlin**: 2.3.0+
- **Native Dependencies**: TrustPin Kotlin SDK 5.0.0 (automatically configured via Gradle)

> The Flutter plugin declares `minSdk = 25` because the underlying TrustPin
> Kotlin SDK 4.3.2+ requires it. Apps consuming the plugin must therefore
> declare `minSdk >= 25` in their `android/app/build.gradle`.

### Network Permissions

The SDK requires network access to fetch pinning configurations from `https://cdn.trustpin.cloud`.

#### Android
The plugin automatically includes the required network permission in its AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS / macOS
Network access is enabled by default. No additional configuration required.

## Quick Start

### 1. Get Your Credentials

Sign up at [TrustPin Cloud Console](https://app.trustpin.cloud) and create a project to get your:
- Organization ID
- Project ID
- Public Key (Base64-encoded)

### 2. Initialize the SDK

The **recommended** way to initialize TrustPin is to ship a platform-native
configuration file with your app and let the native TrustPin SDK load it.
The Dart side never reads, parses, or validates the file — each native
platform owns its loader — which keeps credentials out of your Dart code
and aligns the Flutter SDK with the iOS, macOS, and Android SDKs.

```dart
import 'package:trustpin_sdk/trustpin_sdk.dart';

Future<void> initializeTrustPin() async {
  // Optional: enable debug logging during development
  await TrustPin.shared.setLogLevel(TrustPinLogLevel.debug);

  // Load credentials from the native bundle on each platform
  await TrustPin.shared.setupWithNativeBundle();
}
```

#### iOS / macOS — `TrustPin-Info.plist`

Drop a Plist into your Xcode `Runner` target so it ends up inside the host
app's main bundle (`ios/Runner/TrustPin-Info.plist`,
`macos/Runner/TrustPin-Info.plist`). Make sure the file is added to **Target
Membership** in Xcode.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                       "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>OrganizationId</key>
  <string>your-org-id</string>
  <key>ProjectId</key>
  <string>your-project-id</string>
  <key>PublicKey</key>
  <string>LS0tLS1CRUdJTi...</string>
  <key>Mode</key>
  <string>strict</string>
</dict>
</plist>
```

| Plist key          | Required | Notes                                                     |
| ------------------ | -------- | --------------------------------------------------------- |
| `OrganizationId`   | yes      | Non-empty string                                          |
| `ProjectId`        | yes      | Non-empty string                                          |
| `PublicKey`        | yes      | Base64-encoded verification key                           |
| `Mode`             | no       | `"strict"` (default) or `"permissive"` (lowercase)        |
| `ConfigurationURL` | no       | HTTPS URL for self-hosted configs; empty treated as unset |

#### Android — `trustpin.json`

Drop a JSON file into Android's standard assets directory:
`android/app/src/main/assets/trustpin.json`. Gradle includes it in the APK
automatically — no `pubspec.yaml` declaration needed.

```json
{
  "organization_id": "your-org-id",
  "project_id": "your-project-id",
  "public_key": "LS0tLS1CRUdJTi...",
  "mode": "strict",
  "configuration_url": "https://your-server.com/pins.jws"
}
```

| JSON field          | Required | Notes                                                     |
| ------------------- | -------- | --------------------------------------------------------- |
| `organization_id`   | yes      | Non-empty string                                          |
| `project_id`        | yes      | Non-empty string                                          |
| `public_key`        | yes      | Base64-encoded verification key                           |
| `mode`              | no       | `"strict"` (default) or `"permissive"`                    |
| `configuration_url` | no       | HTTPS URL for self-hosted configs; empty treated as unset |

#### Custom filenames

Override the per-platform filename for multi-environment setups (staging,
production, etc.):

```dart
await TrustPin.shared.setupWithNativeBundle(
  iosFileName: 'TrustPin-Staging.plist',
  macosFileName: 'TrustPin-Staging.plist',
  androidFileName: 'trustpin-staging.json',
);
```

A `null` value (the default) tells each native SDK to use its own default
(`TrustPin-Info.plist` / `trustpin.json`).

Missing, malformed, or schema-invalid files throw [`TrustPinException`] with
code `INVALID_PROJECT_CONFIG`.

#### Alternative: inline Dart configuration

If you cannot ship a bundled configuration file (for example, when
credentials must be resolved at runtime from a secret manager), pass a
`TrustPinConfiguration` to `setup` instead:

```dart
const config = TrustPinConfiguration(
  organizationId: 'your-org-id',
  projectId: 'your-project-id',
  publicKey: 'LS0tLS1CRUdJTi...', // Your Base64 public key
  mode: TrustPinMode.strict, // Use strict mode for production
);

await TrustPin.shared.setup(config);
```

For self-hosted configurations, pass a custom URL:

```dart
final config = TrustPinConfiguration(
  organizationId: 'your-org-id',
  projectId: 'your-project-id',
  publicKey: 'LS0tLS1CRUdJTi...',
  configurationURL: Uri.parse('https://your-server.com/pins.jws'),
);
await TrustPin.shared.setup(config);
```

### 3. Validate a Connection

The recommended workflow is a single call to `validateConnection`. The
platform composes the certificate fetch and pin verification inside one
channel call, so the certificate never enters the Dart isolate and the
`timeout` bounds the whole operation:

```dart
Future<void> checkServer(String host) async {
  try {
    await TrustPin.shared.validateConnection(
      host,
      timeout: const Duration(seconds: 5),
    );
    print('Connection is allowed by the configured pins.');
  } on TrustPinException catch (e) {
    print('Validation failed: ${e.code} - ${e.message}');
  }
}
```

If you need the leaf certificate for diagnostics or a custom flow, the
two-step `fetchCertificate` / `verify` pair is still available, but both are
**deprecated** in favor of `validateConnection` and will be removed in a
future major release:

```dart
// ignore: deprecated_member_use
final pem = await TrustPin.shared.fetchCertificate(host);
// ignore: deprecated_member_use
await TrustPin.shared.verify(host, pem);
```

## Advanced Usage

### Integration with Dio

The SDK provides a built-in `TrustPinDioInterceptor` for seamless Dio integration:

```dart
import 'package:dio/dio.dart';
import 'package:trustpin_sdk/trustpin_sdk.dart';

final dio = Dio();
dio.interceptors.add(TrustPinDioInterceptor());

// All HTTPS requests now have automatic certificate pinning
try {
  final response = await dio.get('https://api.example.com/data');
  print('Request successful: ${response.statusCode}');
} on DioException catch (e) {
  if (e.error is TrustPinException) {
    final trustPinError = e.error as TrustPinException;
    print('Pinning failed: ${trustPinError.code}');
  }
}
```

The interceptor automatically:
1. Calls `validateConnection` on the platform, which fetches the leaf
   certificate and verifies it against configured pins in a single hop.
2. Blocks requests when the connection does not match a configured pin.

### Integration with http package

The SDK provides `TrustPinHttpClient` that wraps the standard `http.Client`:

```dart
import 'package:http/http.dart' as http;
import 'package:trustpin_sdk/trustpin_sdk.dart';

// Create a TrustPin-enabled HTTP client
final client = TrustPinHttpClient.create();

// Or wrap an existing client
final client = TrustPinHttpClient(http.Client());

// Use it like a normal http.Client
final response = await client.get(Uri.parse('https://api.example.com/data'));

// Clean up when done
client.close();
```

### Multiple Instances

Libraries or multi-tenant apps can use named instances to maintain independent
pinning configurations without conflicts:

```dart
// Create a named instance for your library
final pin = TrustPin.instance('com.mylib.networking');
await pin.setup(myLibConfig);

// Use the named instance with interceptors
dio.interceptors.add(TrustPinDioInterceptor(instance: pin));
final client = TrustPinHttpClient.create(instance: pin);
```

Calling `TrustPin.instance('id')` multiple times with the same ID returns
the same instance.

### Manual Certificate Verification

If you already have the PEM certificate (e.g., from your own TLS implementation):

```dart
const pemCertificate = '''
-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END CERTIFICATE-----
''';

try {
  await TrustPin.shared.verify('api.example.com', pemCertificate);
  print('Certificate is valid!');
} on TrustPinException catch (e) {
  print('Verification failed: ${e.code}');
}
```

### Logging

```dart
// Debug logging for development
await TrustPin.shared.setLogLevel(TrustPinLogLevel.debug);

// Minimal logging for production
await TrustPin.shared.setLogLevel(TrustPinLogLevel.error);

// Disable all logging
await TrustPin.shared.setLogLevel(TrustPinLogLevel.none);
```

## API Reference

### TrustPin

| Member | Description |
|--------|-------------|
| `TrustPin.shared` | The shared (default) instance for most apps |
| `TrustPin.instance(id)` | Returns a named instance (for libraries / multi-tenant) |
| `setupWithNativeBundle({iosFileName?, macosFileName?, androidFileName?})` | **Recommended initializer.** Loads credentials from a platform-native bundle file (Plist on iOS/macOS, JSON asset on Android). |
| `setup(configuration)` | Alternative initializer that takes an inline [TrustPinConfiguration]. Use when credentials are resolved at runtime. |
| `validateConnection(host, {port?, timeout?})` | Atomic fetch-and-verify. **Recommended entry point** for cert-pinned HTTPS. |
| `setLogLevel(level)` | Set logging verbosity |

### TrustPinConfiguration

| Property | Type | Description |
|----------|------|-------------|
| `organizationId` | `String` | Your organization identifier (required) |
| `projectId` | `String` | Your project identifier (required) |
| `publicKey` | `String` | Base64-encoded public key issued by the TrustPin dashboard (required) |
| `configurationURL` | `Uri?` | Optional override for the configuration source (self-hosted setups only) |
| `mode` | `TrustPinMode` | Pinning mode (default: `strict`) |

### TrustPinMode

| Value | Description |
|-------|-------------|
| `strict` | Throws errors for unregistered domains (recommended for production) |
| `permissive` | Allows unregistered domains to bypass pinning (development/testing) |

### TrustPinLogLevel

| Value | Description |
|-------|-------------|
| `none` | No logging output |
| `error` | Only error messages |
| `info` | Errors and informational messages |
| `debug` | All messages including detailed debug information |

### HTTP Interceptors

| Class | Description |
|-------|-------------|
| `TrustPinDioInterceptor({instance?})` | Certificate pinning interceptor for Dio |
| `TrustPinHttpClient({instance?})` | Certificate pinning wrapper for http.Client |

Full API documentation: [trustpin-cloud.github.io/flutter.sdk](https://trustpin-cloud.github.io/flutter.sdk/)

## Error Handling

All TrustPin operations throw `TrustPinException` on failure. Use the convenience getters to check for specific error types:

```dart
try {
  await TrustPin.shared.verify('api.example.com', certificate);
} on TrustPinException catch (e) {
  if (e.isDomainNotRegistered) {
    // Domain not configured for pinning (strict mode only)
  } else if (e.isPinsMismatch) {
    // Certificate doesn't match any configured pins
  } else if (e.isAllPinsExpired) {
    // All pins for this domain have expired
  } else if (e.isInvalidServerCert) {
    // Certificate format is invalid
  }
}
```

| Error Code | Getter | Description |
|------------|--------|-------------|
| `INVALID_PROJECT_CONFIG` | `isInvalidProjectConfig` | Invalid or missing credentials |
| `ERROR_FETCHING_PINNING_INFO` | `isErrorFetchingPinningInfo` | Failed to fetch pinning configuration |
| `INVALID_SERVER_CERT` | `isInvalidServerCert` | Invalid certificate format |
| `PINS_MISMATCH` | `isPinsMismatch` | Certificate doesn't match configured pins |
| `ALL_PINS_EXPIRED` | `isAllPinsExpired` | All pins for the domain have expired |
| `DOMAIN_NOT_REGISTERED` | `isDomainNotRegistered` | Domain not configured (strict mode) |
| `CONFIGURATION_VALIDATION_FAILED` | `isConfigurationValidationFailed` | Configuration validation failed |
| `FETCH_CERTIFICATE_TIMEOUT` | `isFetchCertificateTimeout` | `fetchCertificate` exceeded its `timeout` |

## Example App

The `sample_app/` directory contains a complete example application demonstrating:
- SDK initialization with `TrustPin.shared.setup()`
- Certificate fetching with `TrustPin.shared.fetchCertificate()`
- Connection testing with `TrustPinHttpClient`
- Error handling and logging

Run the example:

```bash
cd sample_app
flutter run
```

---

<div align="center">

**Secure your Flutter apps with TrustPin SSL Certificate Pinning**

[Get Started](https://app.trustpin.cloud) | [Documentation](https://trustpin-cloud.github.io/flutter.sdk/) | [Support](mailto:support@trustpin.cloud)

</div>

---
