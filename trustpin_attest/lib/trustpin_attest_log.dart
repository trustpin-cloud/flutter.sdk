/// Log levels of the attestation module. Logging is off by default.
enum TrustPinAttestLogLevel {
  /// No logging output.
  none('none'),

  /// Errors only.
  error('error'),

  /// Errors and warnings.
  warning('warning'),

  /// Errors, warnings and informational messages.
  info('info'),

  /// Everything, including whether each request got the header. For
  /// development only.
  debug('debug');

  /// The string value representation of this log level.
  final String value;

  const TrustPinAttestLogLevel(this.value);

  /// The level for [value], or [info] when unknown.
  static TrustPinAttestLogLevel fromValue(String? value) =>
      TrustPinAttestLogLevel.values.firstWhere(
        (level) => level.value == value,
        orElse: () => TrustPinAttestLogLevel.info,
      );
}

/// One log message from the native attestation module, delivered through
/// [TrustPinAttest.logs]. Messages never contain tokens, key certificates,
/// bound values or debug tokens.
class TrustPinAttestLogEvent {
  /// Severity of this message; never [TrustPinAttestLogLevel.none].
  final TrustPinAttestLogLevel level;

  /// The instance that produced the message: `'default'` for
  /// [TrustPinAttest.shared].
  final String instanceId;

  /// The log message.
  final String message;

  /// Creates a log event. Exposed for testing.
  const TrustPinAttestLogEvent({
    required this.level,
    required this.instanceId,
    required this.message,
  });

  /// Decodes an event map received from the platform.
  factory TrustPinAttestLogEvent.fromMap(Map<Object?, Object?> map) =>
      TrustPinAttestLogEvent(
        level: TrustPinAttestLogLevel.fromValue(map['level'] as String?),
        instanceId: map['instanceId'] as String? ?? 'default',
        message: map['message'] as String? ?? '',
      );

  @override
  String toString() =>
      'TrustPinAttestLogEvent(${level.value}, instance: $instanceId): $message';
}
