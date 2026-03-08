import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'trustpin_sdk_method_channel.dart';

/// The platform interface for the TrustPin SDK plugin.
///
/// Platform-specific implementations should extend this class and override
/// all methods. The default implementation uses [MethodChannelTrustPinSDK].
abstract class TrustPinSDKPlatform extends PlatformInterface {
  /// Constructs a TrustPinSDKPlatform.
  TrustPinSDKPlatform() : super(token: _token);

  static final Object _token = Object();

  static TrustPinSDKPlatform _instance = MethodChannelTrustPinSDK();

  /// The default instance of [TrustPinSDKPlatform] to use.
  ///
  /// Defaults to [MethodChannelTrustPinSDK].
  static TrustPinSDKPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TrustPinSDKPlatform] when
  /// they register themselves.
  static set instance(TrustPinSDKPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes the TrustPin SDK with the given credentials.
  ///
  /// When [instanceId] is null, the global default instance is used.
  /// When provided, a named instance is created or retrieved.
  Future<void> setup(
    String organizationId,
    String projectId,
    String publicKey, {
    Uri? configurationURL,
    String mode = 'strict',
    String? instanceId,
  }) {
    throw UnimplementedError('setup() has not been implemented.');
  }

  /// Verifies a PEM certificate against configured pins for [domain].
  ///
  /// When [instanceId] is null, the global default instance is used.
  Future<void> verify(String domain, String certificate,
      {String? instanceId}) {
    throw UnimplementedError('verify() has not been implemented.');
  }

  /// Sets the logging verbosity level.
  ///
  /// When [instanceId] is null, the global default instance is used.
  Future<void> setLogLevel(String logLevel, {String? instanceId}) {
    throw UnimplementedError('setLogLevel() has not been implemented.');
  }

  /// Fetches the TLS leaf certificate from [host] as a PEM string.
  ///
  /// When [instanceId] is null, the global default instance is used.
  Future<String> fetchCertificate(String host,
      {int port = 443, String? instanceId}) {
    throw UnimplementedError('fetchCertificate() has not been implemented.');
  }
}
