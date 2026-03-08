import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'trustpin_sdk_platform_interface.dart';

/// An implementation of [TrustPinSDKPlatform] that uses method channels
/// to communicate with native platform code.
class MethodChannelTrustPinSDK extends TrustPinSDKPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('cloud.trustpin.sdk.flutter');

  /// Initializes the TrustPin SDK with the given credentials via the method channel.
  ///
  /// Sends `setup` to the native platform with the organization credentials,
  /// optional [configurationURL], pinning [mode], and optional [instanceId].
  @override
  Future<void> setup(
    String organizationId,
    String projectId,
    String publicKey, {
    Uri? configurationURL,
    String mode = 'strict',
    String? instanceId,
  }) async {
    await methodChannel.invokeMethod('setup', {
      'organizationId': organizationId,
      'projectId': projectId,
      'publicKey': publicKey,
      'configurationURL': configurationURL?.toString(),
      'mode': mode,
      'instanceId': instanceId,
    });
  }

  /// Verifies a PEM certificate against configured pins via the method channel.
  ///
  /// Sends `verify` to the native platform with the [domain], [certificate],
  /// and optional [instanceId].
  @override
  Future<void> verify(String domain, String certificate,
      {String? instanceId}) async {
    await methodChannel.invokeMethod('verify', {
      'domain': domain,
      'certificate': certificate,
      'instanceId': instanceId,
    });
  }

  /// Sets the logging verbosity level via the method channel.
  ///
  /// Sends `setLogLevel` to the native platform with [logLevel]
  /// and optional [instanceId].
  @override
  Future<void> setLogLevel(String logLevel, {String? instanceId}) async {
    await methodChannel.invokeMethod('setLogLevel', {
      'logLevel': logLevel,
      'instanceId': instanceId,
    });
  }

  /// Fetches the TLS leaf certificate from [host] via the method channel.
  ///
  /// Sends `fetchCertificate` to the native platform with [host], [port],
  /// and optional [instanceId]. Returns the PEM-encoded certificate string.
  @override
  Future<String> fetchCertificate(String host,
      {int port = 443, String? instanceId}) async {
    final result = await methodChannel.invokeMethod<String>(
      'fetchCertificate',
      {'host': host, 'port': port, 'instanceId': instanceId},
    );
    return result!;
  }
}
