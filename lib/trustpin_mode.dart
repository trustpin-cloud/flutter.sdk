/// Pinning modes that control behavior for unregistered domains.
enum TrustPinMode {
  /// Throws errors for unregistered domains (recommended for production).
  ///
  /// In strict mode, any domain that is not explicitly configured in your
  /// TrustPin configuration will cause certificate validation to fail.
  /// This is the recommended mode for production environments.
  strict('strict'),

  /// Allows unregistered domains to bypass pinning (development/testing).
  ///
  /// In permissive mode, domains not configured in your TrustPin configuration
  /// will bypass certificate pinning and only undergo standard TLS validation.
  /// This mode is useful for development and testing environments.
  permissive('permissive');

  /// The string value representation of this mode.
  final String value;

  const TrustPinMode(this.value);
}
