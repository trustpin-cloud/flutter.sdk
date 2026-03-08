/// Exception thrown by TrustPin operations.
///
/// This exception provides detailed error information for certificate
/// validation failures and configuration issues. Use the convenience
/// getters to check for specific error types programmatically.
class TrustPinException implements Exception {
  /// The error code identifying the type of error.
  final String code;

  /// Human-readable error message.
  final String message;

  /// Additional error details (may be null).
  final dynamic details;

  /// Creates a new TrustPinException with the specified code and message.
  const TrustPinException(this.code, this.message, [this.details]);

  /// Creates a TrustPinException from a platform exception.
  ///
  /// This factory constructor is used internally to convert platform-specific
  /// exceptions into TrustPinException instances.
  factory TrustPinException.fromPlatformException(dynamic error) {
    if (error.toString().contains('PlatformException')) {
      // Extract error information from PlatformException string representation
      final errorString = error.toString();
      final codeMatch = RegExp(r'code: ([^,]+)').firstMatch(errorString);
      final messageMatch = RegExp(r'message: ([^,]+)').firstMatch(errorString);

      final code = codeMatch?.group(1) ?? 'UNKNOWN_ERROR';
      final message = messageMatch?.group(1) ?? error.toString();

      return TrustPinException(code, message);
    }

    return TrustPinException('UNKNOWN_ERROR', error.toString());
  }

  @override
  String toString() => 'TrustPinException($code): $message';

  /// Returns true if this is an invalid project configuration error.
  ///
  /// This error occurs when the organization ID, project ID, or public key
  /// are invalid or missing.
  bool get isInvalidProjectConfig => code == 'INVALID_PROJECT_CONFIG';

  /// Returns true if this is a network/CDN fetch error.
  ///
  /// This error occurs when the SDK cannot fetch the pinning configuration
  /// from the TrustPin CDN due to network issues.
  bool get isErrorFetchingPinningInfo => code == 'ERROR_FETCHING_PINNING_INFO';

  /// Returns true if this is an invalid certificate format error.
  ///
  /// This error occurs when the provided certificate is not in valid PEM format
  /// or cannot be parsed.
  bool get isInvalidServerCert => code == 'INVALID_SERVER_CERT';

  /// Returns true if certificate doesn't match any configured pins.
  ///
  /// This error occurs when the certificate's public key doesn't match any
  /// of the configured pins for the domain.
  bool get isPinsMismatch => code == 'PINS_MISMATCH';

  /// Returns true if all pins for the domain have expired.
  ///
  /// This error occurs when all configured pins for a domain have passed
  /// their expiration date.
  bool get isAllPinsExpired => code == 'ALL_PINS_EXPIRED';

  /// Returns true if domain is not registered (strict mode only).
  ///
  /// This error occurs in strict mode when attempting to validate a certificate
  /// for a domain that is not configured in your TrustPin configuration.
  bool get isDomainNotRegistered => code == 'DOMAIN_NOT_REGISTERED';

  /// Returns true if configuration validation failed.
  ///
  /// This error occurs when the fetched configuration is malformed or
  /// doesn't meet the expected format requirements.
  bool get isConfigurationValidationFailed =>
      code == 'CONFIGURATION_VALIDATION_FAILED';

}
