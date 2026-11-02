import 'package:trustpin_attest/trustpin_attest.dart';

/// What the Attestation tab shows about the SDK's state: the SDK state once
/// attestation is set up, or "not configured" before.
class AttestationStatus {
  /// `null` until attestation is set up.
  final TrustPinAttestState? state;

  const AttestationStatus(this.state);

  static const notConfigured = AttestationStatus(null);

  bool get isReady => state is TrustPinAttestReady;

  String get label => switch (state) {
    null => 'Attestation not configured',
    TrustPinAttestUnavailable() => 'No token yet',
    TrustPinAttestAttesting() => 'Attesting…',
    TrustPinAttestReady(:final expiresAt) =>
      'Token ready until ${_time(expiresAt)}',
    TrustPinAttestFailed(:final error, retryAt: null) =>
      'Failed: ${errorLabel(error)} (no automatic retry)',
    TrustPinAttestFailed(:final error, :final retryAt?) =>
      'Failed: ${errorLabel(error)}, retry at ${_time(retryAt)}',
  };

  /// The error the way the native samples print it: `BindingRequired`,
  /// `AttestationFailed(app_not_allowed)`.
  static String errorLabel(TrustPinAttestException error) {
    final name = error.code
        .toLowerCase()
        .split('_')
        .map(
          (part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
        )
        .join();
    return error.reasons.isEmpty ? name : '$name(${error.reasons.join(', ')})';
  }

  static String _time(DateTime time) {
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

/// The result of a call to the sample API's protected endpoint.
class ProtectedCallOutcome {
  final int statusCode;

  /// Whether the request carried the `TrustPin-Attestation` header.
  final bool headerAttached;

  /// The API's echo of the token it verified (platform, environment, result,
  /// binding), when the response carried one.
  final String? attestationSummary;

  /// The response body, JSON pretty-printed; empty when there was none.
  final String body;

  const ProtectedCallOutcome({
    required this.statusCode,
    required this.headerAttached,
    this.attestationSummary,
    this.body = '',
  });

  /// `GET /home answered 200 (attestation header sent: true)`.
  String get headline =>
      'GET /home answered $statusCode '
      '(attestation header sent: $headerAttached)';
}
