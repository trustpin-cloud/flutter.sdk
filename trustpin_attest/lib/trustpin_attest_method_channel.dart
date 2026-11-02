import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'trustpin_attest_platform_interface.dart';

/// Default platform implementation backed by a Flutter method channel.
///
/// Most apps should use [TrustPinAttest] rather than this type directly.
class MethodChannelTrustPinAttest extends TrustPinAttestPlatform {
  /// The method channel.
  @visibleForTesting
  final methodChannel = const MethodChannel('cloud.trustpin.attest.flutter');

  /// Event channel carrying the state changes of every instance.
  @visibleForTesting
  final stateEventChannel =
      const EventChannel('cloud.trustpin.attest.flutter/state_events');

  /// Event channel carrying the events of every instance.
  @visibleForTesting
  final eventChannel =
      const EventChannel('cloud.trustpin.attest.flutter/events');

  /// Event channel carrying the module's log messages.
  @visibleForTesting
  final logEventChannel =
      const EventChannel('cloud.trustpin.attest.flutter/log_events');

  /// Memoized so every Dart listener shares one native subscription.
  Stream<Map<Object?, Object?>>? _stateEvents;
  Stream<Map<Object?, Object?>>? _events;
  Stream<Map<Object?, Object?>>? _logEvents;

  @override
  Stream<Map<Object?, Object?>> get stateEvents =>
      _stateEvents ??= stateEventChannel
          .receiveBroadcastStream()
          .map((event) => (event as Map).cast<Object?, Object?>());

  @override
  Stream<Map<Object?, Object?>> get events => _events ??= eventChannel
      .receiveBroadcastStream()
      .map((event) => (event as Map).cast<Object?, Object?>());

  @override
  Stream<Map<Object?, Object?>> get logEvents => _logEvents ??= logEventChannel
      .receiveBroadcastStream()
      .map((event) => (event as Map).cast<Object?, Object?>());

  @override
  Future<void> setup({
    required String verifierUrl,
    required List<String> attestedHosts,
    int? googleCloudProjectNumber,
    String? debugToken,
    String? instanceId,
  }) async {
    await methodChannel.invokeMethod('setup', {
      'verifierUrl': verifierUrl,
      'attestedHosts': attestedHosts,
      'googleCloudProjectNumber': googleCloudProjectNumber,
      'debugToken': debugToken,
      'instanceId': instanceId,
    });
  }

  @override
  Future<void> setupWithNativeBundle({
    String? iosFileName,
    String? androidFileName,
    String? macosFileName,
    String? debugToken,
    String? instanceId,
  }) async {
    await methodChannel.invokeMethod('setupWithNativeBundle', {
      'iosFileName': iosFileName,
      'androidFileName': androidFileName,
      'macosFileName': macosFileName,
      'debugToken': debugToken,
      'instanceId': instanceId,
    });
  }

  @override
  Future<void> prefetch({String? instanceId}) async {
    await methodChannel.invokeMethod('prefetch', {'instanceId': instanceId});
  }

  @override
  Future<String> getToken({String? instanceId}) async {
    final token = await methodChannel
        .invokeMethod<String>('getToken', {'instanceId': instanceId});
    return token!;
  }

  @override
  Future<Map<String, String>> attestationHeaders(
    String url, {
    String method = 'GET',
    Map<String, String> headers = const {},
    String? instanceId,
  }) async {
    final result = await methodChannel
        .invokeMapMethod<String, String>('attestationHeaders', {
      'url': url,
      'method': method,
      'headers': headers,
      'instanceId': instanceId,
    });
    return result ?? const {};
  }

  @override
  Future<Map<String, String>> assertionHeaders(
    Uint8List payloadDigest, {
    String? instanceId,
  }) async {
    final result = await methodChannel
        .invokeMapMethod<String, String>('assertionHeaders', {
      'payloadDigest': payloadDigest,
      'instanceId': instanceId,
    });
    return result ?? const {};
  }

  @override
  Future<void> setTokenBinding(String? value, {String? instanceId}) async {
    await methodChannel.invokeMethod('setTokenBinding', {
      'value': value,
      'instanceId': instanceId,
    });
  }

  @override
  Future<void> bindToHeader(String? name, {String? instanceId}) async {
    await methodChannel.invokeMethod('bindToHeader', {
      'name': name,
      'instanceId': instanceId,
    });
  }

  @override
  Future<Map<Object?, Object?>> state({String? instanceId}) async {
    final result = await methodChannel
        .invokeMapMethod<Object?, Object?>('state', {'instanceId': instanceId});
    return result ?? const {'state': 'unavailable'};
  }

  @override
  Future<void> reset({String? instanceId}) async {
    await methodChannel.invokeMethod('reset', {'instanceId': instanceId});
  }

  @override
  Future<void> setLogLevel(String level, {String? instanceId}) async {
    await methodChannel.invokeMethod('setLogLevel', {
      'logLevel': level,
      'instanceId': instanceId,
    });
  }
}
