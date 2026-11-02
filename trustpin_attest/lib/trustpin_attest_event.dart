import 'trustpin_attest_exception.dart';

/// A structured event of a [TrustPinAttest] instance, delivered through
/// [TrustPinAttest.events], for monitoring: durations, waits, counts and
/// reasons. Events never contain a token, a key or a device identifier.
///
/// ```dart
/// TrustPinAttest.shared.events.listen((event) {
///   switch (event) {
///     case TrustPinAttestAttestationSucceeded(:final duration):
///       metrics.record('attest', duration);
///     case TrustPinAttestRefused(:final retryAt):
///       log('Refused, next attempt after ${retryAt ?? 'restart'}');
///     default:
///       log('$event');
///   }
/// });
/// ```
///
/// New event types can appear in a minor release: keep a default case.
sealed class TrustPinAttestEvent {
  const TrustPinAttestEvent();

  /// Decodes an event map received from the platform, or returns `null` for
  /// an event this version doesn't know.
  static TrustPinAttestEvent? fromMap(Map<Object?, Object?> map) {
    switch (map['event']) {
      case 'keyGenerated':
        return const TrustPinAttestKeyGenerated();
      case 'keyReplaced':
        return TrustPinAttestKeyReplaced(_int(map['count']));
      case 'attestationSucceeded':
        return TrustPinAttestAttestationSucceeded(_duration(map));
      case 'refused':
        return TrustPinAttestRefused(_time(map['retryAtMs']));
      case 'attestationFailed':
        return TrustPinAttestAttestationFailed(
          _reasons(map['reasons']),
          _time(map['retryAtMs']),
        );
      case 'refreshSucceeded':
        return TrustPinAttestRefreshSucceeded(_duration(map));
      case 'refreshFailed':
        return TrustPinAttestRefreshFailed(
            TrustPinAttestException.fromMap(map));
      case 'waitEntered':
        return TrustPinAttestWaitEntered(
            _time(map['untilMs']) ?? DateTime.now().toUtc());
      case 'waitCleared':
        return const TrustPinAttestWaitCleared();
      case 'deviceUnsupported':
        return const TrustPinAttestDeviceUnsupported();
      case 'verifierUnavailable':
        return const TrustPinAttestVerifierUnavailable();
      case 'assertionSucceeded':
        return TrustPinAttestAssertionSucceeded(_duration(map));
      case 'assertionFailed':
        return TrustPinAttestAssertionFailed(
            TrustPinAttestException.fromMap(map));
      default:
        return null;
    }
  }

  static int _int(Object? value) => value is int ? value : 0;

  static Duration _duration(Map<Object?, Object?> map) =>
      Duration(milliseconds: _int(map['durationMs']));

  static DateTime? _time(Object? millis) => millis is int
      ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
      : null;

  static List<String> _reasons(Object? value) =>
      value is List ? List.unmodifiable(value.whereType<String>()) : const [];
}

/// A new device key was generated.
final class TrustPinAttestKeyGenerated extends TrustPinAttestEvent {
  /// Creates the event.
  const TrustPinAttestKeyGenerated();

  @override
  bool operator ==(Object other) => other is TrustPinAttestKeyGenerated;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'TrustPinAttestKeyGenerated';
}

/// The device key was replaced; [count] is how many replacements happened
/// recently.
final class TrustPinAttestKeyReplaced extends TrustPinAttestEvent {
  /// How many times a key was replaced.
  final int count;

  /// Creates the event.
  const TrustPinAttestKeyReplaced(this.count);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestKeyReplaced && other.count == count;

  @override
  int get hashCode => count;

  @override
  String toString() => 'TrustPinAttestKeyReplaced(count: $count)';
}

/// A new device key was attested; the attestation took [duration].
final class TrustPinAttestAttestationSucceeded extends TrustPinAttestEvent {
  /// How long the attestation took.
  final Duration duration;

  /// Creates the event.
  const TrustPinAttestAttestationSucceeded(this.duration);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestAttestationSucceeded && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'TrustPinAttestAttestationSucceeded($duration)';
}

/// Your verifier refused the attestation. Nothing is tried before [retryAt],
/// in UTC; `null` means no new attempt in this launch.
final class TrustPinAttestRefused extends TrustPinAttestEvent {
  /// The earliest time of the next attempt, or `null` for none in this
  /// launch.
  final DateTime? retryAt;

  /// Creates the event.
  const TrustPinAttestRefused(this.retryAt);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestRefused && other.retryAt == retryAt;

  @override
  int get hashCode => retryAt.hashCode;

  @override
  String toString() => 'TrustPinAttestRefused(retryAt: ${retryAt ?? 'none'})';
}

/// An attestation failed for [reasons]. Nothing is tried before [retryAt],
/// in UTC; `null` means no new attempt in this launch.
final class TrustPinAttestAttestationFailed extends TrustPinAttestEvent {
  /// The reason codes.
  final List<String> reasons;

  /// The earliest time of the next attempt, or `null` for none in this
  /// launch.
  final DateTime? retryAt;

  /// Creates the event.
  const TrustPinAttestAttestationFailed(this.reasons, this.retryAt);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestAttestationFailed &&
      other.retryAt == retryAt &&
      _sameList(other.reasons, reasons);

  @override
  int get hashCode => Object.hash(Object.hashAll(reasons), retryAt);

  @override
  String toString() =>
      'TrustPinAttestAttestationFailed(${reasons.join(', ')}, retryAt: ${retryAt ?? 'none'})';
}

/// The token was renewed; the renewal took [duration].
final class TrustPinAttestRefreshSucceeded extends TrustPinAttestEvent {
  /// How long the renewal took.
  final Duration duration;

  /// Creates the event.
  const TrustPinAttestRefreshSucceeded(this.duration);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestRefreshSucceeded && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'TrustPinAttestRefreshSucceeded($duration)';
}

/// A token renewal failed with [error].
final class TrustPinAttestRefreshFailed extends TrustPinAttestEvent {
  /// Why the renewal failed.
  final TrustPinAttestException error;

  /// Creates the event.
  const TrustPinAttestRefreshFailed(this.error);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestRefreshFailed && other.error.code == error.code;

  @override
  int get hashCode => error.code.hashCode;

  @override
  String toString() => 'TrustPinAttestRefreshFailed(${error.code})';
}

/// No attempt will be made before [until], in UTC.
final class TrustPinAttestWaitEntered extends TrustPinAttestEvent {
  /// When the wait ends.
  final DateTime until;

  /// Creates the event.
  const TrustPinAttestWaitEntered(this.until);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestWaitEntered && other.until == until;

  @override
  int get hashCode => until.hashCode;

  @override
  String toString() => 'TrustPinAttestWaitEntered(until: $until)';
}

/// A wait ended.
final class TrustPinAttestWaitCleared extends TrustPinAttestEvent {
  /// Creates the event.
  const TrustPinAttestWaitCleared();

  @override
  bool operator ==(Object other) => other is TrustPinAttestWaitCleared;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'TrustPinAttestWaitCleared';
}

/// This device can't attest the app.
final class TrustPinAttestDeviceUnsupported extends TrustPinAttestEvent {
  /// Creates the event.
  const TrustPinAttestDeviceUnsupported();

  @override
  bool operator ==(Object other) => other is TrustPinAttestDeviceUnsupported;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'TrustPinAttestDeviceUnsupported';
}

/// Your verifier couldn't be reached securely.
final class TrustPinAttestVerifierUnavailable extends TrustPinAttestEvent {
  /// Creates the event.
  const TrustPinAttestVerifierUnavailable();

  @override
  bool operator ==(Object other) => other is TrustPinAttestVerifierUnavailable;

  @override
  int get hashCode => 3;

  @override
  String toString() => 'TrustPinAttestVerifierUnavailable';
}

/// [TrustPinAttest.assertionHeaders] produced an assertion in [duration].
final class TrustPinAttestAssertionSucceeded extends TrustPinAttestEvent {
  /// How long producing the assertion took.
  final Duration duration;

  /// Creates the event.
  const TrustPinAttestAssertionSucceeded(this.duration);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestAssertionSucceeded && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'TrustPinAttestAssertionSucceeded($duration)';
}

/// [TrustPinAttest.assertionHeaders] failed with [error].
final class TrustPinAttestAssertionFailed extends TrustPinAttestEvent {
  /// Why no assertion was produced.
  final TrustPinAttestException error;

  /// Creates the event.
  const TrustPinAttestAssertionFailed(this.error);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestAssertionFailed && other.error.code == error.code;

  @override
  int get hashCode => error.code.hashCode;

  @override
  String toString() => 'TrustPinAttestAssertionFailed(${error.code})';
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
