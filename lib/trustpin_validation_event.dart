import 'trustpin_exception.dart';

/// A definitive pin-validation verdict reported by the native TrustPin SDK.
///
/// Delivered through [TrustPin.validationEvents]. Events exist for field
/// telemetry — recording suspected machine-in-the-middle incidents and
/// monitoring a pinning rollout — and are strictly observational: by the time
/// an event reaches Dart the connection has already been allowed or rejected,
/// and nothing done with the event can change that verdict.
///
/// Failure events fire only for *definitive* pin verdicts — `PINS_MISMATCH`,
/// `ALL_PINS_EXPIRED`, and `DOMAIN_NOT_REGISTERED` (strict mode). Transient
/// conditions (configuration fetch failures, timeouts, lifecycle errors) fail
/// verification per the documented error contract but are operational noise,
/// not pin verdicts, and produce no event. Success events fire when a
/// registered domain's certificate matches a pin; permissive-mode connections
/// to unregistered domains produce no event.
class TrustPinValidationEvent {
  /// Identifier of the TrustPin instance that evaluated the connection.
  /// `'default'` for [TrustPin.shared].
  final String instanceId;

  /// The domain the certificate was evaluated against, as evaluated
  /// (canonicalized when canonicalization succeeded).
  final String domain;

  /// The verdict for a failure event, carrying the stable error code
  /// (`PINS_MISMATCH`, `ALL_PINS_EXPIRED`, or `DOMAIN_NOT_REGISTERED`).
  /// `null` for a success event.
  final TrustPinException? error;

  /// The PEM-encoded leaf certificate the server presented. Set only on
  /// failure events.
  ///
  /// **Attacker-supplied data** — the certificate came from the rejected
  /// peer. Sanitize before rendering or forwarding it anywhere.
  final String? certificatePem;

  /// Creates a validation event. Exposed for testing; production events are
  /// constructed from the platform stream.
  const TrustPinValidationEvent({
    required this.instanceId,
    required this.domain,
    this.error,
    this.certificatePem,
  });

  /// Whether a registered domain's certificate matched a configured pin.
  bool get isSuccess => error == null;

  /// Whether pin validation reached a definitive failure verdict.
  bool get isFailure => error != null;

  /// Decodes an event map received from the platform event channel.
  factory TrustPinValidationEvent.fromMap(Map<Object?, Object?> map) {
    final code = map['code'] as String?;
    return TrustPinValidationEvent(
      instanceId: map['instanceId'] as String? ?? 'default',
      domain: map['domain'] as String? ?? '',
      error: code == null
          ? null
          : TrustPinException(code, map['message'] as String? ?? ''),
      certificatePem: map['certificatePem'] as String?,
    );
  }

  @override
  String toString() => isSuccess
      ? 'TrustPinValidationEvent(success, instance: $instanceId, '
          'domain: $domain)'
      : 'TrustPinValidationEvent(failure, instance: $instanceId, '
          'domain: $domain, code: ${error!.code})';
}
