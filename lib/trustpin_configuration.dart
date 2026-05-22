import 'trustpin_mode.dart';

/// Configuration for the TrustPin SDK.
///
/// Contains all credentials and settings needed to initialize TrustPin.
/// Create an instance and pass it to [TrustPin.setup] to configure the SDK.
///
/// To load credentials from a platform bundle file (Plist on iOS/macOS, JSON
/// in Android assets) without writing them into Dart source, use
/// [TrustPin.setupWithNativeBundle] instead.
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
}
