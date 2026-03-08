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
- **JWS-based Configuration**: Securely fetch signed pinning configurations from TrustPin CDN
- **Cross-platform Support**: Native implementations for iOS (Swift), Android (Kotlin), and macOS (Swift)
- **Flexible Pinning Modes**: Support for strict (production) and permissive (development) validation modes
- **Certificate Fetching**: Built-in `fetchCertificate` for OS-level TLS validation and leaf certificate extraction
- **HTTP Client Integration**: Built-in interceptors for Dio and the http package
- **Multiple Instances**: Use `TrustPin.shared` for single-project apps, or `TrustPin.instance('id')` for libraries and multi-tenant setups
- **Comprehensive Error Handling**: Detailed error types with programmatic checking capabilities
- **Configurable Logging**: Multiple log levels for debugging, monitoring, and production use
- **Thread Safety**: Built with Flutter's async/await pattern and native concurrency models
- **Intelligent Caching**: 10-minute configuration caching with stale fallback for performance
- **ECDSA P-256 Signature Verification**: Cryptographic validation of configuration integrity

## Installation

Add TrustPin SDK to your `pubspec.yaml`:

```yaml
dependencies:
  trustpin_sdk: ^3.0.0
```

Then install the package:

```bash
flutter pub get
```

## Platform Setup

### iOS Requirements

- **Minimum iOS Version**: 13.0+
- **Xcode**: 15.0+
- **Swift**: 5.0+
- **Native Dependencies**: TrustPin Swift SDK (automatically configured via Swift Package Manager or CocoaPods)

### macOS Requirements

- **Minimum macOS Version**: 13.0+
- **Xcode**: 15.0+
- **Swift**: 5.0+
- **Native Dependencies**: TrustPin Swift SDK (automatically configured via Swift Package Manager or CocoaPods)

For sandboxed macOS apps, add the network client entitlement:

```xml
<!-- In DebugProfile.entitlements and Release.entitlements -->
<key>com.apple.security.network.client</key>
<true/>
```

### Android Requirements

- **Minimum SDK**: API 21 (Android 5.0)+
- **Target SDK**: API 34+ (recommended)
- **Kotlin**: 2.3.0+
- **Native Dependencies**: TrustPin Kotlin SDK (automatically configured via Gradle)

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
- Public Key (ECDSA P-256, Base64-encoded)

### 2. Initialize the SDK

```dart
import 'package:trustpin_sdk/trustpin_sdk.dart';

Future<void> initializeTrustPin() async {
  // Optional: enable debug logging during development
  await TrustPin.shared.setLogLevel(TrustPinLogLevel.debug);

  // Create a configuration with your credentials
  const config = TrustPinConfiguration(
    organizationId: 'your-org-id',
    projectId: 'your-project-id',
    publicKey: 'LS0tLS1CRUdJTi...', // Your Base64 public key
    mode: TrustPinMode.strict, // Use strict mode for production
  );

  // Initialize the shared instance
  await TrustPin.shared.setup(config);
}
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

### 3. Fetch and Verify Certificates

The recommended workflow is to fetch the leaf certificate from the server, then verify it against your configured pins:

```dart
Future<void> verifyServer(String host) async {
  try {
    // Fetch the leaf certificate (performs OS-level TLS validation)
    final pem = await TrustPin.shared.fetchCertificate(host);

    // Verify the certificate against configured pins
    await TrustPin.shared.verify(host, pem);
    print('Certificate is valid and matches configured pins!');
  } on TrustPinException catch (e) {
    print('Verification failed: ${e.code} - ${e.message}');
  }
}
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
1. Fetches the leaf certificate via OS-level TLS validation
2. Verifies the certificate against configured TrustPin pins
3. Caches certificates for performance
4. Blocks requests with invalid certificates

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
| `setup(configuration)` | Initialize the instance with a [TrustPinConfiguration] |
| `verify(domain, certificate)` | Verify a PEM certificate against configured pins |
| `fetchCertificate(host, {port?})` | Fetch the TLS leaf certificate from a host as PEM |
| `setLogLevel(level)` | Set logging verbosity |

### TrustPinConfiguration

| Property | Type | Description |
|----------|------|-------------|
| `organizationId` | `String` | Your organization identifier (required) |
| `projectId` | `String` | Your project identifier (required) |
| `publicKey` | `String` | Base64-encoded ECDSA P-256 public key (required) |
| `configurationURL` | `Uri?` | Custom URL for self-hosted JWS payload (optional) |
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
