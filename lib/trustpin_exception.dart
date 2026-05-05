import 'package:flutter/services.dart';

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
    if (error is PlatformException) {
      return TrustPinException(
        error.code,
        error.message ?? '',
        error.details,
      );
    }
    return TrustPinException('UNKNOWN_ERROR', error.toString());
  }

  @override
  String toString() => 'TrustPinException($code): $message';

  /// Returns true for an invalid project configuration error.
  bool get isInvalidProjectConfig => code == 'INVALID_PROJECT_CONFIG';

  /// Returns true if pinning information could not be retrieved.
  bool get isErrorFetchingPinningInfo => code == 'ERROR_FETCHING_PINNING_INFO';

  /// Returns true if the supplied certificate could not be parsed.
  bool get isInvalidServerCert => code == 'INVALID_SERVER_CERT';

  /// Returns true if the certificate was rejected for the given domain.
  bool get isPinsMismatch => code == 'PINS_MISMATCH';

  /// Returns true if no usable pins remain for the given domain.
  bool get isAllPinsExpired => code == 'ALL_PINS_EXPIRED';

  /// Returns true if the domain is not configured (strict mode only).
  bool get isDomainNotRegistered => code == 'DOMAIN_NOT_REGISTERED';

  /// Returns true if the configuration was rejected.
  bool get isConfigurationValidationFailed =>
      code == 'CONFIGURATION_VALIDATION_FAILED';

  /// Returns true if a certificate fetch exceeded its timeout.
  bool get isFetchCertificateTimeout => code == 'FETCH_CERTIFICATE_TIMEOUT';
}
