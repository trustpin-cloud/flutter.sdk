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
class TrustPinConfiguration {
  /// Your organization identifier from the TrustPin dashboard.
  final String organizationId;

  /// Your project identifier from the TrustPin dashboard.
  final String projectId;

  /// Base64-encoded ECDSA P-256 public key for JWS signature verification.
  final String publicKey;

  /// Custom URL for the signed payload (JWS).
  ///
  /// CDN-managed projects should leave this as `null` (the default).
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
  /// - Parameter [publicKey]: Base64-encoded ECDSA P-256 public key for JWS signature verification
  /// - Parameter [configurationURL]: Custom URL for the signed payload (JWS). Defaults to `null` for CDN-managed projects
  /// - Parameter [mode]: The pinning mode (default: [TrustPinMode.strict])
  const TrustPinConfiguration({
    required this.organizationId,
    required this.projectId,
    required this.publicKey,
    this.configurationURL,
    this.mode = TrustPinMode.strict,
  });
}
