import 'dart:async';

import 'package:flutter/foundation.dart';

import 'trustpin_attest_configuration.dart';
import 'trustpin_attest_event.dart';
import 'trustpin_attest_exception.dart';
import 'trustpin_attest_log.dart';
import 'trustpin_attest_platform_interface.dart';
import 'trustpin_attest_state.dart';

export 'trustpin_attest_configuration.dart';
export 'trustpin_attest_event.dart';
export 'trustpin_attest_exception.dart';
export 'trustpin_attest_log.dart';
export 'trustpin_attest_state.dart';

/// TrustPin app attestation for Flutter.
///
/// Proves to your API that a request comes from your genuine app on a
/// genuine device that meets your policy. The device attests once per device
/// key to **your** TrustPin verifier (Apple App Attest, Android Key
/// Attestation or Play Integrity), then renews a short-lived token cheaply.
/// The token travels in the `TrustPin-Attestation` header, and your API or
/// gateway verifies it.
///
/// ## Setup
///
/// Set up pinning first (`trustpin_sdk`): verifier calls are pinned through
/// the pinning instance with the same id. Then set up attestation once per
/// launch:
///
/// ```dart
/// await TrustPin.shared.setupWithNativeBundle();
/// await TrustPinAttest.shared.setupWithNativeBundle();
/// await TrustPinAttest.shared.bindToHeader('Authorization');
/// await TrustPinAttest.shared.prefetch();
/// ```
///
/// ## Sending the header
///
/// [TrustPinHttpClient] and [TrustPinDioInterceptor] from `trustpin_sdk` add
/// the header automatically to HTTPS requests for the attested hosts. For
/// other clients use [attestationHeaders], and [getToken] for non-HTTP
/// transports. For a sensitive operation, add [assertionHeaders] as well.
///
/// The SDK never fails a request: when no token is ready in a short, bounded
/// time, the request goes out without the header and your API decides.
class TrustPinAttest {
  /// The header that carries the token.
  static const String headerName = 'TrustPin-Attestation';

  /// The header that carries the assertion of a sensitive operation (see
  /// [assertionHeaders]).
  static const String assertionHeaderName = 'TrustPin-Assertion';

  static final Map<String, TrustPinAttest> _instances = {};

  /// The default instance, paired with `TrustPin.shared`.
  static final TrustPinAttest shared = TrustPinAttest._(null);

  /// Returns the named instance for [id], paired with `TrustPin.instance(id)`
  /// of `trustpin_sdk`, which must be set up first.
  static TrustPinAttest instance(String id) {
    assert(id != 'default',
        'Use TrustPinAttest.shared to access the default instance.');
    assert(id.trim().isNotEmpty, 'TrustPinAttest instance id cannot be empty.');
    return _instances.putIfAbsent(id, () => TrustPinAttest._(id));
  }

  /// The module's log output, from every instance, each message tagged with
  /// its [TrustPinAttestLogEvent.instanceId]. What is logged is set per
  /// instance with [setLogLevel]; logging is off by default. While no one
  /// listens, the native module logs to the platform default.
  static Stream<TrustPinAttestLogEvent> get logs =>
      TrustPinAttestPlatform.instance.logEvents
          .map(TrustPinAttestLogEvent.fromMap);

  final String? _instanceId;

  TrustPinAttest._(this._instanceId);

  String get _wireId => _instanceId ?? 'default';

  TrustPinAttestPlatform get _platform => TrustPinAttestPlatform.instance;

  /// Sets up this instance with [configuration]. One-shot: local validation
  /// only, no verifier call. It loads a device key from an earlier launch and
  /// registers the instance on the pinning instance with the same id, so
  /// `trustpin_sdk`'s HTTP integrations add the header.
  ///
  /// - Throws `INVALID_CONFIGURATION` if a value is rejected or the pinning
  ///   instance isn't usable.
  /// - Throws `ALREADY_INITIALIZED` if this instance is already set up.
  Future<void> setup(TrustPinAttestConfiguration configuration) =>
      _call(() => _platform.setup(
            verifierUrl: configuration.verifierUrl.toString(),
            attestedHosts: configuration.attestedHosts,
            googleCloudProjectNumber: configuration.googleCloudProjectNumber,
            debugToken: kReleaseMode ? null : configuration.debugToken,
            instanceId: _instanceId,
          ));

  /// Sets up this instance from the platform configuration file that the
  /// pinning setup reads:
  ///
  /// - **iOS, macOS:** `TrustPin-Info.plist` in the app bundle, keys
  ///   `AttestVerifierURL` (string) and `AttestedHosts` (array).
  /// - **Android:** `assets/trustpin.json`, keys `attest_verifier_url`,
  ///   `attested_hosts` and, for Play Integrity,
  ///   `google_cloud_project_number`.
  ///
  /// Pass a file name per platform to use another file. [debugToken] is
  /// passed as in [TrustPinAttestConfiguration.debugToken]; never in release
  /// builds.
  Future<void> setupWithNativeBundle({
    String? iosFileName,
    String? androidFileName,
    String? macosFileName,
    String? debugToken,
  }) =>
      _call(() => _platform.setupWithNativeBundle(
            iosFileName: iosFileName,
            androidFileName: androidFileName,
            macosFileName: macosFileName,
            debugToken: kReleaseMode ? null : debugToken,
            instanceId: _instanceId,
          ));

  /// Starts attestation or renewal in the background, typically right after
  /// setup, so the first request doesn't wait. Never throws.
  Future<void> prefetch() async {
    try {
      await _platform.prefetch(instanceId: _instanceId);
    } catch (_) {
      // Fire and forget: a failure shows in [state].
    }
  }

  /// The current token, attesting or renewing first if needed. For
  /// transports the HTTP integrations don't cover (gRPC, WebSockets); send it
  /// in the [headerName] header.
  ///
  /// Throws a [TrustPinAttestException] when no token can be obtained.
  Future<String> getToken() =>
      _call(() => _platform.getToken(instanceId: _instanceId));

  /// The headers to add to a request for [url]: [headerName] with the token
  /// when [url] is HTTPS on an attested host and a token is ready in time,
  /// otherwise none. [headers] are the request's own headers, used for
  /// header binding. Never throws.
  Future<Map<String, String>> attestationHeaders(
    Uri url, {
    String method = 'GET',
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _platform.attestationHeaders(
        url.toString(),
        method: method,
        headers: headers,
        instanceId: _instanceId,
      );
    } catch (_) {
      return const {};
    }
  }

  /// The headers for one sensitive operation: [headerName] with the token
  /// and [assertionHeaderName] with an assertion that binds this device's
  /// attested key to [payloadDigest], the SHA-256 digest of whatever your
  /// backend verifies (for example the request body). Send both with that
  /// request; your backend passes them and its own digest to your verifier.
  /// Each call produces a new assertion.
  ///
  /// ```dart
  /// final body = utf8.encode(jsonEncode({'amount': '1.00'}));
  /// final headers = await TrustPinAttest.shared
  ///     .assertionHeaders(Uint8List.fromList(sha256.convert(body).bytes));
  /// ```
  ///
  /// Throws a [TrustPinAttestException] when no token is available, or
  /// `INVALID_DIGEST` when [payloadDigest] isn't 32 bytes.
  Future<Map<String, String>> assertionHeaders(Uint8List payloadDigest) =>
      _call(() =>
          _platform.assertionHeaders(payloadDigest, instanceId: _instanceId));

  /// Binds tokens to a fixed [value], such as a session id: only its SHA-256
  /// travels. `null` removes the fixed binding. Clears header binding. A
  /// change renews the token with the existing device key.
  Future<void> setTokenBinding(String? value) =>
      _call(() => _platform.setTokenBinding(value, instanceId: _instanceId));

  /// Binds each token to the value of the request header [name], usually
  /// `Authorization`: only its SHA-256 travels. `null` stops header binding.
  /// Clears a fixed binding.
  Future<void> bindToHeader(String? name) =>
      _call(() => _platform.bindToHeader(name, instanceId: _instanceId));

  /// The current attestation state.
  Future<TrustPinAttestState> get state async {
    final map = await _call(() => _platform.state(instanceId: _instanceId));
    return TrustPinAttestState.fromMap(map);
  }

  /// The state of this instance: the current one first, then every change.
  Stream<TrustPinAttestState> get stateChanges {
    late final StreamController<TrustPinAttestState> controller;
    StreamSubscription<Map<Object?, Object?>>? subscription;
    var changed = false;
    controller = StreamController<TrustPinAttestState>(
      onListen: () {
        subscription = _ofThisInstance(_platform.stateEvents).listen(
          (event) {
            changed = true;
            controller.add(TrustPinAttestState.fromMap(event));
          },
          onError: controller.addError,
        );
        state.then((current) {
          // A change that arrived first is newer than this read.
          if (!changed && !controller.isClosed) controller.add(current);
        }, onError: (Object error) {
          if (!controller.isClosed) controller.addError(error);
        });
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// The events of this instance from now on, for monitoring (see
  /// [TrustPinAttestEvent]). Events before the first listener, or while no
  /// one listens, are not kept.
  Stream<TrustPinAttestEvent> get events => _ofThisInstance(_platform.events)
      .map(TrustPinAttestEvent.fromMap)
      .where((event) => event != null)
      .cast<TrustPinAttestEvent>();

  /// Discards the device key and key certificate; the next request attests a
  /// new key, so the token's `sub` changes. For support flows, not routine
  /// use. Does nothing before setup.
  Future<void> reset() => _call(() => _platform.reset(instanceId: _instanceId));

  /// Sets this instance's log level. Logging is off by default; use
  /// [TrustPinAttestLogLevel.debug] only in development.
  Future<void> setLogLevel(TrustPinAttestLogLevel level) =>
      _call(() => _platform.setLogLevel(level.value, instanceId: _instanceId));

  Stream<Map<Object?, Object?>> _ofThisInstance(
          Stream<Map<Object?, Object?>> stream) =>
      stream.where((event) => event['instanceId'] == _wireId);

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw TrustPinAttestException.fromPlatformException(e);
    }
  }
}
