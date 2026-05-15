import 'dart:convert';

import 'package:flutter/services.dart';

import 'trustpin_exception.dart';
import 'trustpin_mode.dart';

/// Configuration for the TrustPin SDK.
///
/// Contains all credentials and settings needed to initialize TrustPin.
/// Create an instance and pass it to [TrustPin.setup] to configure the SDK.
///
/// ## Example
///
/// ```dart
/// const config = TrustPinConfiguration(
///   organizationId: 'your-org-id',
///   projectId: 'your-project-id',
///   publicKey: 'LS0tLS1CRUdJTi...',
/// );
///
/// await TrustPin.shared.setup(config);
/// ```
///
/// You can also load the configuration from a JSON asset bundled with your
/// app using [TrustPinConfiguration.fromAssets].
class TrustPinConfiguration {
  /// Your organization identifier from the TrustPin dashboard.
  final String organizationId;

  /// Your project identifier from the TrustPin dashboard.
  final String projectId;

  /// Base64-encoded public key issued by the TrustPin dashboard.
  final String publicKey;

  /// Optional override for the configuration source.
  ///
  /// Leave as `null` (the default) to use the TrustPin-hosted configuration.
  /// Only set this for self-hosted configurations.
  final Uri? configurationURL;

  /// The pinning mode controlling behavior for unregistered domains.
  ///
  /// Defaults to [TrustPinMode.strict].
  final TrustPinMode mode;

  /// Creates a TrustPin configuration.
  ///
  /// - Parameter [organizationId]: Your organization identifier from the TrustPin dashboard
  /// - Parameter [projectId]: Your project identifier from the TrustPin dashboard
  /// - Parameter [publicKey]: Base64-encoded public key issued by the TrustPin dashboard
  /// - Parameter [configurationURL]: Optional override for the configuration source. Defaults to `null` for the TrustPin-hosted configuration
  /// - Parameter [mode]: The pinning mode (default: [TrustPinMode.strict])
  const TrustPinConfiguration({
    required this.organizationId,
    required this.projectId,
    required this.publicKey,
    this.configurationURL,
    this.mode = TrustPinMode.strict,
  });

  /// Loads a configuration from a JSON asset bundled with the Flutter app.
  ///
  /// Reads the asset at [assetPath] using the Flutter [bundle] (defaults to
  /// [rootBundle]) and parses it according to the same schema used by the
  /// Android native SDK's `TrustPinConfiguration.fromAssets`.
  ///
  /// ## Asset Declaration
  ///
  /// Declare the asset in your `pubspec.yaml`:
  ///
  /// ```yaml
  /// flutter:
  ///   assets:
  ///     - trustpin.json
  /// ```
  ///
  /// ## JSON Schema
  ///
  /// ```json
  /// {
  ///   "organization_id": "your-org-id",
  ///   "project_id": "your-project-id",
  ///   "public_key": "MFkwEwYH...",
  ///   "mode": "strict",
  ///   "configuration_url": "https://custom.example.com/config/signed.b64"
  /// }
  /// ```
  ///
  /// | Field               | Required | Notes                                                     |
  /// | ------------------- | -------- | --------------------------------------------------------- |
  /// | `organization_id`   | yes      | Non-empty string                                          |
  /// | `project_id`        | yes      | Non-empty string                                          |
  /// | `public_key`        | yes      | Base64-encoded verification key                           |
  /// | `mode`              | no       | `"strict"` (default) or `"permissive"`                    |
  /// | `configuration_url` | no       | HTTPS URL for self-hosted configs; empty treated as unset |
  ///
  /// Unknown top-level keys are ignored for forward compatibility.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final config = await TrustPinConfiguration.fromAssets();
  /// await TrustPin.shared.setup(config);
  /// ```
  ///
  /// Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if the
  /// asset is missing, malformed, or fails schema validation.
  static Future<TrustPinConfiguration> fromAssets({
    String assetPath = 'trustpin.json',
    AssetBundle? bundle,
  }) async {
    final loader = bundle ?? rootBundle;

    final String raw;
    try {
      raw = await loader.loadString(assetPath, cache: false);
    } catch (e) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'Failed to load TrustPin configuration asset "$assetPath": $e',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" is not valid JSON: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" must be a JSON object.',
      );
    }

    final organizationId =
        _requireNonEmptyString(decoded, 'organization_id', assetPath);
    final projectId = _requireNonEmptyString(decoded, 'project_id', assetPath);
    final publicKey = _requireNonEmptyString(decoded, 'public_key', assetPath);
    final mode = _parseMode(decoded['mode'], assetPath);
    final configurationURL =
        _parseConfigurationUrl(decoded['configuration_url'], assetPath);

    return TrustPinConfiguration(
      organizationId: organizationId,
      projectId: projectId,
      publicKey: publicKey,
      mode: mode,
      configurationURL: configurationURL,
    );
  }

  static String _requireNonEmptyString(
    Map<String, dynamic> json,
    String key,
    String assetPath,
  ) {
    final value = json[key];
    if (value == null) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" is missing required field "$key".',
      );
    }
    if (value is! String) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" field "$key" must be a string.',
      );
    }
    if (value.isEmpty) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" field "$key" must not be empty.',
      );
    }
    return value;
  }

  static TrustPinMode _parseMode(dynamic raw, String assetPath) {
    if (raw == null) return TrustPinMode.strict;
    if (raw is! String) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" field "mode" must be a string.',
      );
    }
    if (raw.isEmpty) return TrustPinMode.strict;
    for (final mode in TrustPinMode.values) {
      if (mode.value == raw) return mode;
    }
    throw TrustPinException(
      'INVALID_PROJECT_CONFIG',
      'TrustPin configuration at "$assetPath" has invalid "mode": "$raw". '
          'Expected "strict" or "permissive".',
    );
  }

  static Uri? _parseConfigurationUrl(dynamic raw, String assetPath) {
    if (raw == null) return null;
    if (raw is! String) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" field "configuration_url" must be a string.',
      );
    }
    if (raw.isEmpty) return null;
    final Uri parsed;
    try {
      parsed = Uri.parse(raw);
    } on FormatException catch (e) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" has invalid "configuration_url": ${e.message}',
      );
    }
    if (parsed.scheme != 'https') {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" field "configuration_url" must use the "https" scheme.',
      );
    }
    if (!parsed.hasAuthority || parsed.host.isEmpty) {
      throw TrustPinException(
        'INVALID_PROJECT_CONFIG',
        'TrustPin configuration at "$assetPath" field "configuration_url" must include a host.',
      );
    }
    return parsed;
  }
}
