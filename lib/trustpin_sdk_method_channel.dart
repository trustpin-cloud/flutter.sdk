import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'trustpin_sdk_platform_interface.dart';

/// Default platform implementation backed by a Flutter method channel.
///
/// Most apps should use [TrustPin] rather than this type directly.
class MethodChannelTrustPinSDK extends TrustPinSDKPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('cloud.trustpin.sdk.flutter');

  /// Event channel carrying pin-validation verdicts from the native SDK's
  /// global validation listener.
  @visibleForTesting
  final eventChannel =
      const EventChannel('cloud.trustpin.sdk.flutter/validation_events');

  /// Event channel carrying SDK log messages from the native SDK's global
  /// log sink.
  @visibleForTesting
  final logEventChannel =
      const EventChannel('cloud.trustpin.sdk.flutter/log_events');

  /// Memoized so every Dart listener shares one native subscription; the
  /// native listener is installed on the first listen and removed after the
  /// last cancel.
  Stream<Map<Object?, Object?>>? _validationEvents;
  Stream<Map<Object?, Object?>>? _logEvents;

  @override
  Stream<Map<Object?, Object?>> get validationEvents =>
      _validationEvents ??= eventChannel
          .receiveBroadcastStream()
          .map((event) => (event as Map).cast<Object?, Object?>());

  @override
  Stream<Map<Object?, Object?>> get logEvents => _logEvents ??= logEventChannel
      .receiveBroadcastStream()
      .map((event) => (event as Map).cast<Object?, Object?>());

  @override
  Future<void> setup(
    String organizationId,
    String projectId,
    String publicKey, {
    Uri? configurationURL,
    String mode = 'strict',
    String? instanceId,
    String? embeddedConfigurationFile,
  }) async {
    await methodChannel.invokeMethod('setup', {
      'organizationId': organizationId,
      'projectId': projectId,
      'publicKey': publicKey,
      'configurationURL': configurationURL?.toString(),
      'mode': mode,
      'instanceId': instanceId,
      'embeddedConfigurationFile': embeddedConfigurationFile,
    });
  }

  @override
  Future<void> setupWithNativeBundle({
    String? iosFileName,
    String? androidFileName,
    String? macosFileName,
    String? instanceId,
  }) async {
    await methodChannel.invokeMethod('setupWithNativeBundle', {
      'iosFileName': iosFileName,
      'androidFileName': androidFileName,
      'macosFileName': macosFileName,
      'instanceId': instanceId,
    });
  }

  @override
  Future<void> verify(String domain, String certificate,
      {String? instanceId}) async {
    await methodChannel.invokeMethod('verify', {
      'domain': domain,
      'certificate': certificate,
      'instanceId': instanceId,
    });
  }

  @override
  Future<void> setLogLevel(String logLevel, {String? instanceId}) async {
    await methodChannel.invokeMethod('setLogLevel', {
      'logLevel': logLevel,
      'instanceId': instanceId,
    });
  }

  @override
  Future<String> fetchCertificate(String host,
      {int port = 443, int? timeoutMs, String? instanceId}) async {
    final result = await methodChannel.invokeMethod<String>(
      'fetchCertificate',
      {
        'host': host,
        'port': port,
        'timeoutMs': timeoutMs,
        'instanceId': instanceId,
      },
    );
    return result!;
  }

  @override
  Future<void> awaitConfiguration({int? timeoutMs, String? instanceId}) async {
    await methodChannel.invokeMethod('awaitConfiguration', {
      'timeoutMs': timeoutMs,
      'instanceId': instanceId,
    });
  }

  @override
  Future<bool> isConfigurationLoaded({String? instanceId}) async {
    final result = await methodChannel.invokeMethod<bool>(
      'isConfigurationLoaded',
      {'instanceId': instanceId},
    );
    return result ?? false;
  }

  @override
  Future<void> validateConnection(
    String host, {
    int port = 443,
    int? timeoutMs,
    String? instanceId,
  }) async {
    await methodChannel.invokeMethod('validateConnection', {
      'host': host,
      'port': port,
      'timeoutMs': timeoutMs,
      'instanceId': instanceId,
    });
  }
}
