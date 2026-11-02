import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'trustpin_attest_method_channel.dart';

/// The platform interface of the TrustPin attestation plugin.
///
/// Every method takes the instance id; `null` selects the default instance.
/// The default implementation is [MethodChannelTrustPinAttest].
abstract class TrustPinAttestPlatform extends PlatformInterface {
  /// Constructs a TrustPinAttestPlatform.
  TrustPinAttestPlatform() : super(token: _token);

  static final Object _token = Object();

  static TrustPinAttestPlatform _instance = MethodChannelTrustPinAttest();

  /// The default instance of [TrustPinAttestPlatform] to use.
  static TrustPinAttestPlatform get instance => _instance;

  /// Platform implementations set this with their own class.
  static set instance(TrustPinAttestPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Sets up attestation with a configuration given in code.
  Future<void> setup({
    required String verifierUrl,
    required List<String> attestedHosts,
    int? googleCloudProjectNumber,
    String? debugToken,
    String? instanceId,
  }) {
    throw UnimplementedError('setup() has not been implemented.');
  }

  /// Sets up attestation from the platform configuration file. A null file
  /// name selects the native default.
  Future<void> setupWithNativeBundle({
    String? iosFileName,
    String? androidFileName,
    String? macosFileName,
    String? debugToken,
    String? instanceId,
  }) {
    throw UnimplementedError(
        'setupWithNativeBundle() has not been implemented.');
  }

  /// Starts attestation or renewal in the background.
  Future<void> prefetch({String? instanceId}) {
    throw UnimplementedError('prefetch() has not been implemented.');
  }

  /// The current token, attesting or renewing first if needed.
  Future<String> getToken({String? instanceId}) {
    throw UnimplementedError('getToken() has not been implemented.');
  }

  /// The attestation headers for a request.
  Future<Map<String, String>> attestationHeaders(
    String url, {
    String method = 'GET',
    Map<String, String> headers = const {},
    String? instanceId,
  }) {
    throw UnimplementedError('attestationHeaders() has not been implemented.');
  }

  /// The token and assertion headers for one sensitive operation.
  Future<Map<String, String>> assertionHeaders(
    Uint8List payloadDigest, {
    String? instanceId,
  }) {
    throw UnimplementedError('assertionHeaders() has not been implemented.');
  }

  /// Binds tokens to a fixed value, or removes the fixed binding.
  Future<void> setTokenBinding(String? value, {String? instanceId}) {
    throw UnimplementedError('setTokenBinding() has not been implemented.');
  }

  /// Binds tokens to a request header, or stops header binding.
  Future<void> bindToHeader(String? name, {String? instanceId}) {
    throw UnimplementedError('bindToHeader() has not been implemented.');
  }

  /// The current state as a map (see `TrustPinAttestState.fromMap`).
  Future<Map<Object?, Object?>> state({String? instanceId}) {
    throw UnimplementedError('state() has not been implemented.');
  }

  /// Discards the device key and key certificate.
  Future<void> reset({String? instanceId}) {
    throw UnimplementedError('reset() has not been implemented.');
  }

  /// Sets the log level of an instance.
  Future<void> setLogLevel(String level, {String? instanceId}) {
    throw UnimplementedError('setLogLevel() has not been implemented.');
  }

  /// State changes of every instance the plugin set up, each map carrying
  /// `instanceId`.
  Stream<Map<Object?, Object?>> get stateEvents {
    throw UnimplementedError('stateEvents has not been implemented.');
  }

  /// Events of every instance the plugin set up, each map carrying
  /// `instanceId`.
  Stream<Map<Object?, Object?>> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// The module's log messages, from every instance.
  Stream<Map<Object?, Object?>> get logEvents {
    throw UnimplementedError('logEvents has not been implemented.');
  }
}
