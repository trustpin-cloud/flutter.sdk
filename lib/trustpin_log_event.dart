import 'trustpin_log_level.dart';

/// One log message emitted by the native TrustPin SDK, delivered through
/// [TrustPin.logs].
///
/// The native log sink is global: one stream carries the output of every
/// TrustPin instance, distinguished by [instanceId]. What is logged — and at
/// which verbosity — is still controlled per instance via
/// [TrustPin.setLogLevel]; the stream only chooses where already-filtered
/// messages go.
class TrustPinLogEvent {
  /// Severity of this message — always [TrustPinLogLevel.error],
  /// [TrustPinLogLevel.info], or [TrustPinLogLevel.debug]; never
  /// [TrustPinLogLevel.none] (that value only configures filtering).
  final TrustPinLogLevel level;

  /// Identifier of the TrustPin instance that produced the message.
  /// `'default'` for [TrustPin.shared].
  final String instanceId;

  /// The log message.
  final String message;

  /// Creates a log event. Exposed for testing; production events are
  /// constructed from the platform stream.
  const TrustPinLogEvent({
    required this.level,
    required this.instanceId,
    required this.message,
  });

  /// Decodes an event map received from the platform event channel.
  factory TrustPinLogEvent.fromMap(Map<Object?, Object?> map) {
    final level = switch (map['level'] as String?) {
      'error' => TrustPinLogLevel.error,
      'debug' => TrustPinLogLevel.debug,
      _ => TrustPinLogLevel.info,
    };
    return TrustPinLogEvent(
      level: level,
      instanceId: map['instanceId'] as String? ?? 'default',
      message: map['message'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'TrustPinLogEvent(${level.value}, instance: $instanceId): $message';
}
