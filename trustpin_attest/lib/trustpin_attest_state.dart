import 'trustpin_attest_exception.dart';

/// The attestation state of a [TrustPinAttest] instance, for apps that show
/// status or decide their own behaviour. Observing it is optional: requests
/// get the header whenever a token is ready.
///
/// ```dart
/// switch (await TrustPinAttest.shared.state) {
///   case TrustPinAttestUnavailable():
///     print('No token yet');
///   case TrustPinAttestAttesting():
///     print('Attesting…');
///   case TrustPinAttestReady(:final expiresAt):
///     print('Token ready until $expiresAt');
///   case TrustPinAttestFailed(:final error, :final retryAt):
///     print('Failed: ${error.code}, next attempt after ${retryAt ?? 'restart'}');
/// }
/// ```
sealed class TrustPinAttestState {
  const TrustPinAttestState();

  /// Decodes a state map received from the platform.
  factory TrustPinAttestState.fromMap(Map<Object?, Object?> map) {
    switch (map['state']) {
      case 'attesting':
        return const TrustPinAttestAttesting();
      case 'ready':
        return TrustPinAttestReady(_time(map['expiresAtMs']) ?? DateTime.now());
      case 'failed':
        return TrustPinAttestFailed(
          TrustPinAttestException.fromMap(map),
          _time(map['retryAtMs']),
        );
      default:
        return const TrustPinAttestUnavailable();
    }
  }

  static DateTime? _time(Object? millis) => millis is int
      ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
      : null;
}

/// No token yet: before the first attestation, after a reset, or after a
/// token expired.
final class TrustPinAttestUnavailable extends TrustPinAttestState {
  /// Creates the state.
  const TrustPinAttestUnavailable();

  @override
  bool operator ==(Object other) => other is TrustPinAttestUnavailable;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'TrustPinAttestUnavailable';
}

/// An attestation or a token renewal is in progress.
final class TrustPinAttestAttesting extends TrustPinAttestState {
  /// Creates the state.
  const TrustPinAttestAttesting();

  @override
  bool operator ==(Object other) => other is TrustPinAttestAttesting;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'TrustPinAttestAttesting';
}

/// A token is ready until [expiresAt]; it is renewed before then.
final class TrustPinAttestReady extends TrustPinAttestState {
  /// When the current token expires, in UTC.
  final DateTime expiresAt;

  /// Creates the state.
  const TrustPinAttestReady(this.expiresAt);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestReady && other.expiresAt == expiresAt;

  @override
  int get hashCode => expiresAt.hashCode;

  @override
  String toString() => 'TrustPinAttestReady(expiresAt: $expiresAt)';
}

/// The last attempt failed with [error].
///
/// No timer runs after a failure: nothing is tried before [retryAt], and the
/// next request, [TrustPinAttest.getToken] or [TrustPinAttest.prefetch] after
/// it starts a new attempt. A `null` [retryAt] means no new attempt in this
/// launch, until [TrustPinAttest.reset] or a restart. The exception is
/// `BINDING_REQUIRED`, which resumes as soon as a binding is set.
final class TrustPinAttestFailed extends TrustPinAttestState {
  /// Why the attempt failed.
  final TrustPinAttestException error;

  /// The earliest time of the next attempt, in UTC, or `null` for none in
  /// this launch.
  final DateTime? retryAt;

  /// Creates the state.
  const TrustPinAttestFailed(this.error, this.retryAt);

  @override
  bool operator ==(Object other) =>
      other is TrustPinAttestFailed &&
      other.error.code == error.code &&
      other.retryAt == retryAt;

  @override
  int get hashCode => Object.hash(error.code, retryAt);

  @override
  String toString() =>
      'TrustPinAttestFailed(${error.code}, retryAt: ${retryAt ?? 'none'})';
}
