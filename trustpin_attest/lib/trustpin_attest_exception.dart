import 'package:flutter/services.dart';

/// Exception thrown by [TrustPinAttest] operations, and the error carried by
/// a [TrustPinAttestFailed] state.
///
/// Check [code] with the convenience getters. New codes can appear in a
/// minor release: handle unknown ones.
class TrustPinAttestException implements Exception {
  /// The error code identifying the type of error.
  final String code;

  /// Human-readable error message.
  final String message;

  /// For `ATTESTATION_FAILED`: the reasons the verifier gave (its reason
  /// codes, for example `app_not_allowed`), or a short description of the
  /// failure (`http_503`, the verifier's error code). Empty otherwise.
  final List<String> reasons;

  /// Creates an exception with the given [code] and [message].
  const TrustPinAttestException(
    this.code,
    this.message, {
    this.reasons = const [],
  });

  /// Converts a platform exception into a [TrustPinAttestException].
  factory TrustPinAttestException.fromPlatformException(Object error) {
    if (error is TrustPinAttestException) return error;
    if (error is PlatformException) {
      return TrustPinAttestException(
        error.code,
        error.message ?? '',
        reasons: _reasons(error.details),
      );
    }
    return TrustPinAttestException('ATTEST_ERROR', error.toString());
  }

  /// Decodes the error of a `failed` state map.
  factory TrustPinAttestException.fromMap(Map<Object?, Object?> map) =>
      TrustPinAttestException(
        map['code'] as String? ?? 'ATTEST_ERROR',
        map['message'] as String? ?? '',
        reasons: _reasons(map['reasons']),
      );

  static List<String> _reasons(Object? value) =>
      value is List ? List.unmodifiable(value.whereType<String>()) : const [];

  @override
  String toString() => reasons.isEmpty
      ? 'TrustPinAttestException($code): $message'
      : 'TrustPinAttestException($code): $message ${reasons.join(', ')}';

  /// The configuration was rejected: an invalid verifier URL or host list,
  /// a missing configuration file, or an invalid instance id.
  bool get isInvalidConfiguration => code == 'INVALID_CONFIGURATION';

  /// `setup` was called again on an instance that is already set up.
  bool get isAlreadyInitialized => code == 'ALREADY_INITIALIZED';

  /// An operation was called before `setup`.
  bool get isNotSetUp => code == 'NOT_SET_UP';

  /// The device can't attest: App Attest is unsupported (some Macs, older
  /// hardware) and no debug token applies. iOS and macOS only.
  bool get isUnsupportedDevice => code == 'UNSUPPORTED_DEVICE';

  /// The device can't produce the evidence the policy requires, for example
  /// Play Integrity without Google Play or without a Cloud project number.
  bool get isEvidenceUnavailable => code == 'EVIDENCE_UNAVAILABLE';

  /// The policy requires token binding and no binding is set yet. Expected
  /// before sign-in: attestation resumes as soon as a binding is set.
  bool get isBindingRequired => code == 'BINDING_REQUIRED';

  /// The verifier refused the attestation; see [reasons].
  bool get isAttestationFailed => code == 'ATTESTATION_FAILED';

  /// The verifier couldn't be reached, including when strict pinning refuses
  /// its host because it isn't a registered domain of the project.
  bool get isVerifierUnavailable => code == 'VERIFIER_UNAVAILABLE';

  /// The verifier is too old for this SDK: update it. No header is sent
  /// until it is.
  bool get isVerifierIncompatible => code == 'VERIFIER_INCOMPATIBLE';

  /// The digest given to [TrustPinAttest.assertionHeaders] isn't 32 bytes
  /// (a SHA-256 digest).
  bool get isInvalidDigest => code == 'INVALID_DIGEST';
}
