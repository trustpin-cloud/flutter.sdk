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

  /// Initializes the TrustPin SDK by loading credentials from a platform
  /// bundle file at the native layer. The Dart side never reads or parses the
  /// file; iOS/macOS read a Plist via `TrustPinConfiguration.fromPlist`,
  /// Android reads a JSON asset via `TrustPinConfiguration.fromAssets`.
  ///
  /// Per-platform filename arguments are forwarded verbatim to the matching
  /// native loader. A null value tells the native side to use its own default
  /// (`TrustPin-Info.plist` on iOS/macOS, `trustpin.json` on Android).
  Future<void> setupWithNativeBundle({
    String? iosFileName,
    String? androidFileName,
    String? macosFileName,
    String? instanceId,
  }) {
    throw UnimplementedError('setupWithNativeBundle() has not been implemented.');
  }

  /// Verifies a PEM certificate against configured pins for [domain].
  ///
  /// When [instanceId] is null, the global default instance is used.
  ///
  /// **Deprecated.** Implementations and callers should prefer
  /// [validateConnection], which composes fetch + verify on the platform
  /// side in a single channel call.
  @Deprecated('Use validateConnection() instead.')
  Future<void> verify(String domain, String certificate, {String? instanceId}) {
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
  /// When [timeoutMs] is non-null and positive, the platform throws
  /// `FETCH_CERTIFICATE_TIMEOUT` if exceeded. When [instanceId] is null, the
  /// global default instance is used.
  ///
  /// **Deprecated.** Implementations and callers should prefer
  /// [validateConnection], which keeps the certificate inside the platform
  /// layer instead of marshalling it through the Dart isolate.
  @Deprecated('Use validateConnection() instead.')
  Future<String> fetchCertificate(String host,
      {int port = 443, int? timeoutMs, String? instanceId}) {
    throw UnimplementedError('fetchCertificate() has not been implemented.');
  }

  /// Waits until the pinning configuration has been fetched, signature-
  /// verified, and accepted by the SDK's integrity check — the explicit
  /// fail-closed gate that complements the now non-blocking [setup].
  ///
  /// When [timeoutMs] is non-null and positive, it bounds the wait; otherwise
  /// the native SDK's default timeout applies. When [instanceId] is null, the
  /// global default instance is used.
  Future<void> awaitConfiguration({int? timeoutMs, String? instanceId}) {
    throw UnimplementedError('awaitConfiguration() has not been implemented.');
  }

  /// Returns `true` when a validated pinning payload is cached and usable
  /// without a new fetch. Pure state read — never triggers a fetch or blocks.
  ///
  /// When [instanceId] is null, the global default instance is used.
  Future<bool> isConfigurationLoaded({String? instanceId}) {
    throw UnimplementedError('isConfigurationLoaded() has not been implemented.');
  }

  /// Atomically validates that [host]:[port] presents a certificate matching
  /// the configured pins. The platform composes `fetchCertificate` and
  /// `verify` inside a single channel call, so the certificate never enters
  /// the Dart isolate.
  ///
  /// When [timeoutMs] is non-null and positive, the platform throws
  /// `FETCH_CERTIFICATE_TIMEOUT` if the combined operation exceeds it.
  /// When [instanceId] is null, the global default instance is used.
  Future<void> validateConnection(
    String host, {
    int port = 443,
    int? timeoutMs,
    String? instanceId,
  }) {
    throw UnimplementedError('validateConnection() has not been implemented.');
  }
}
