import 'trustpin_configuration.dart';
import 'trustpin_exception.dart';
import 'trustpin_log_level.dart';
import 'trustpin_sdk_platform_interface.dart';

export 'http_interceptors/dio_interceptor.dart';
export 'http_interceptors/http_client_interceptor.dart';
export 'trustpin_configuration.dart';
export 'trustpin_exception.dart';
export 'trustpin_log_level.dart';
export 'trustpin_mode.dart';

/// TrustPin SSL certificate pinning SDK for Flutter applications.
///
/// Validates server certificates against pinning configuration to mitigate
/// man-in-the-middle (MITM) attacks. Supports strict and permissive modes.
///
/// Use [shared] for a single-project app, or [instance] for libraries and
/// multi-tenant setups.
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:trustpin_sdk/trustpin_sdk.dart';
///
/// // Initialize the shared instance with your project credentials
/// const config = TrustPinConfiguration(
///   organizationId: 'your-org-id',
///   projectId: 'your-project-id',
///   publicKey: 'your-base64-public-key',
///   mode: TrustPinMode.strict, // Use strict mode in production
/// );
/// await TrustPin.shared.setup(config);
///
/// // Verify a certificate manually
/// final pemCertificate = '''
/// -----BEGIN CERTIFICATE-----
/// MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
/// -----END CERTIFICATE-----
/// ''';
///
/// try {
///   await TrustPin.shared.verify('api.example.com', pemCertificate);
///   print('Certificate is valid!');
/// } catch (e) {
///   print('Certificate validation failed: $e');
/// }
/// ```
///
/// ## Multiple Instances
///
/// Libraries or multi-tenant apps can use named instances to avoid conflicts:
///
/// ```dart
/// final pin = TrustPin.instance('com.mylib.networking');
/// await pin.setup(config);
/// await pin.verify('api.example.com', pem);
/// ```
///
/// ## Integration with HTTP Clients
///
/// For automatic certificate validation, use the built-in HTTP interceptors:
///
/// ```dart
/// // With Dio (uses TrustPin.shared by default)
/// final dio = Dio();
/// dio.interceptors.add(TrustPinDioInterceptor());
///
/// // With a named instance
/// dio.interceptors.add(TrustPinDioInterceptor(instance: pin));
///
/// // With http package
/// final client = TrustPinHttpClient.create();
/// final response = await client.get(Uri.parse('https://api.example.com'));
/// client.close();
/// ```
///
/// ## Pinning Modes
///
/// - [TrustPinMode.strict]: Throws errors for unregistered domains (recommended for production)
/// - [TrustPinMode.permissive]: Allows unregistered domains to bypass pinning (development/testing)
///
/// ## Error Handling
///
/// TrustPin provides detailed error information through [TrustPinException] for proper
/// error handling and security monitoring. All errors include specific error codes
/// that can be checked programmatically:
///
/// ```dart
/// try {
///   await TrustPin.shared.verify('api.example.com', certificate);
/// } on TrustPinException catch (e) {
///   if (e.isDomainNotRegistered) {
///     print('Domain not configured for pinning');
///   } else if (e.isPinsMismatch) {
///     print('Certificate doesn\'t match configured pins');
///   } else if (e.isAllPinsExpired) {
///     print('All pins for this domain have expired');
///   }
///   // Handle other error types...
/// }
/// ```
///
/// ## Security Considerations
///
/// - Use [TrustPinMode.strict] in production.
/// - Keep your public key out of source control as plain text.
///
/// - Note: Always call [setup] before performing certificate verification.
class TrustPin {
  /// Internal instance registry for named instances.
  static final Map<String, TrustPin> _instances = {};

  /// The shared (default) TrustPin instance.
  ///
  /// Use this for most applications that only need a single pinning configuration.
  ///
  /// ```dart
  /// await TrustPin.shared.setup(config);
  /// await TrustPin.shared.verify('api.example.com', pem);
  /// ```
  static final TrustPin shared = TrustPin._(null);

  /// Returns a named TrustPin instance for the given [id].
  ///
  /// Named instances allow libraries or multi-tenant apps to maintain
  /// independent pinning configurations without conflicts. Calling this
  /// method multiple times with the same [id] returns the same instance.
  ///
  /// ```dart
  /// final pin = TrustPin.instance('com.mylib.networking');
  /// await pin.setup(config);
  /// await pin.verify('api.example.com', pem);
  /// ```
  static TrustPin instance(String id) {
    assert(
        id != 'default', 'Use TrustPin.shared to access the default instance.');
    assert(id.trim().isNotEmpty, 'TrustPin instance id cannot be empty.');
    return _instances.putIfAbsent(id, () => TrustPin._(id));
  }

  /// The instance identifier passed to the native platform layer.
  /// `null` for the shared (default) instance.
  final String? _instanceId;

  /// Private named constructor.
  TrustPin._(this._instanceId);

  /// Initializes this instance with the given [configuration]. Must be
  /// called before [verify] or [validateConnection].
  ///
  /// ```dart
  /// const config = TrustPinConfiguration(
  ///   organizationId: 'your-org-id',
  ///   projectId: 'your-project-id',
  ///   publicKey: 'your-base64-public-key',
  ///   mode: TrustPinMode.strict,
  /// );
  /// await TrustPin.shared.setup(config);
  /// ```
  ///
  /// `setup` performs **local validation only**: it checks the credential
  /// shapes, stores them, and starts a *background* preload of the pinning
  /// configuration. It does not wait for the network, so it no longer throws
  /// fetch or validation errors. Those surface later — fail-closed — from
  /// [validateConnection] / [verify], or eagerly from [awaitConfiguration].
  ///
  /// Setup is **one-shot**: once an instance is configured, a second call
  /// throws `ALREADY_INITIALIZED`. To use different credentials, create a new
  /// named instance via [instance].
  ///
  /// - Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if credentials are invalid or empty.
  /// - Throws [TrustPinException] with code `ALREADY_INITIALIZED` if this instance has already completed setup.
  Future<void> setup(TrustPinConfiguration configuration) async {
    try {
      await TrustPinSDKPlatform.instance.setup(
        configuration.organizationId,
        configuration.projectId,
        configuration.publicKey,
        configurationURL: configuration.configurationURL,
        mode: configuration.mode.value,
        instanceId: _instanceId,
      );
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Initializes this instance by loading credentials from a platform bundle
  /// file at the native layer. Must be called before [validateConnection].
  ///
  /// The Dart side never reads, parses, or validates the file. Each native
  /// platform owns the loader and its schema:
  ///
  /// - **iOS / macOS** — `TrustPinConfiguration.fromPlist(.main, fileName:)`
  ///   reads a Plist from the host app's main bundle. Default filename
  ///   `TrustPin-Info.plist`. Keys: `OrganizationId`, `ProjectId`,
  ///   `PublicKey`, optional `Mode` (`"strict"` / `"permissive"`), optional
  ///   `ConfigurationURL` (must be HTTPS).
  /// - **Android** — `TrustPinConfiguration.fromAssets(context, fileName)`
  ///   reads a JSON asset from `android/app/src/main/assets/`. Default
  ///   filename `trustpin.json`. Keys: `organization_id`, `project_id`,
  ///   `public_key`, optional `mode`, optional `configuration_url`. The
  ///   native loader chains `withAndroidStorage(context)` internally.
  ///
  /// Override the per-platform filename to support multi-environment setups
  /// (staging / production). Pass `null` (the default) to use the SDK
  /// default for that platform.
  ///
  /// ```dart
  /// // Default filenames on each platform.
  /// await TrustPin.shared.setupWithNativeBundle();
  ///
  /// // Custom filenames per platform.
  /// await TrustPin.shared.setupWithNativeBundle(
  ///   iosFileName: 'TrustPin-Staging.plist',
  ///   macosFileName: 'TrustPin-Staging.plist',
  ///   androidFileName: 'trustpin-staging.json',
  /// );
  /// ```
  ///
  /// - Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if the
  ///   bundle file is missing, malformed, or fails schema validation on the
  ///   native side.
  /// - Throws [TrustPinException] with code `ERROR_FETCHING_PINNING_INFO` if
  ///   the pinning configuration cannot be retrieved after loading the file.
  /// - Throws [TrustPinException] with code `CONFIGURATION_VALIDATION_FAILED`
  ///   if the configuration is rejected.
  Future<void> setupWithNativeBundle({
    String? iosFileName,
    String? androidFileName,
    String? macosFileName,
  }) async {
    try {
      await TrustPinSDKPlatform.instance.setupWithNativeBundle(
        iosFileName: iosFileName,
        androidFileName: androidFileName,
        macosFileName: macosFileName,
        instanceId: _instanceId,
      );
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Waits until this instance's pinning configuration has been fetched,
  /// signature-verified, and accepted by the SDK's integrity check — the
  /// explicit fail-closed gate that complements the now non-blocking [setup].
  ///
  /// [setup] validates credentials locally and refreshes the configuration in
  /// the *background*; it deliberately does not block on the network. Call
  /// this when your integration must not proceed without a validated
  /// configuration (for example, gating app start). Returns immediately when
  /// a configuration is already available.
  ///
  /// ```dart
  /// await TrustPin.shared.setup(config); // local validation only
  /// try {
  ///   await TrustPin.shared.awaitConfiguration(
  ///     timeout: const Duration(seconds: 10),
  ///   );
  /// } on TrustPinException catch (e) {
  ///   // Hard stop — do not build an unpinned HTTP client.
  /// }
  /// ```
  ///
  /// [timeout] bounds the wait; when `null`, the native SDK's default applies.
  /// The native side clamps it to its supported range (currently 10–120s).
  /// For a synchronous, non-fetching state read use [isConfigurationLoaded].
  ///
  /// - Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if [setup] has not been called.
  /// - Throws [TrustPinException] with code `ERROR_FETCHING_PINNING_INFO` if the configuration cannot be retrieved.
  /// - Throws [TrustPinException] with code `CONFIGURATION_VALIDATION_FAILED` if the payload signature does not validate.
  /// - Throws [TrustPinException] with code `CONFIG_INTEGRITY_FAILED` if the configuration fails the SDK's integrity check.
  /// - Throws [TrustPinException] with code `FETCH_CERTIFICATE_TIMEOUT` if [timeout] is exceeded.
  Future<void> awaitConfiguration({Duration? timeout}) async {
    try {
      await TrustPinSDKPlatform.instance.awaitConfiguration(
        timeoutMs: timeout?.inMilliseconds,
        instanceId: _instanceId,
      );
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Whether a validated pinning payload is currently cached and usable by
  /// [verify] / [validateConnection] without a new fetch.
  ///
  /// Pure state read — never triggers a fetch and never blocks. Use
  /// [awaitConfiguration] to actively wait for a configuration. A `true`
  /// result reflects the moment of the read; a previously loaded
  /// configuration can expire if it cannot be refreshed for an extended
  /// period.
  ///
  /// ```dart
  /// if (await TrustPin.shared.isConfigurationLoaded) {
  ///   // Safe to make pinned requests without an initial network wait.
  /// }
  /// ```
  Future<bool> get isConfigurationLoaded async {
    try {
      return await TrustPinSDKPlatform.instance
          .isConfigurationLoaded(instanceId: _instanceId);
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Verifies that [certificate] is valid for [domain] under this instance's
  /// pinning configuration. Returns normally on success.
  ///
  /// **Deprecated.** Prefer [validateConnection], which composes the
  /// certificate fetch and pin verification inside a single channel call.
  /// `verify` remains supported for diagnostic flows where the caller
  /// already holds a PEM certificate obtained out of band.
  ///
  /// ```dart
  /// try {
  ///   await TrustPin.shared.verify('api.example.com', pemCertificate);
  /// } on TrustPinException catch (e) {
  ///   if (e.isPinsMismatch) {
  ///     // ...
  ///   }
  /// }
  /// ```
  ///
  /// [certificate] must be a PEM string including the BEGIN/END markers.
  /// Behavior on unregistered domains depends on [TrustPinMode].
  ///
  /// - Throws [TrustPinException] with code `DOMAIN_NOT_REGISTERED` if domain is not configured (strict mode only).
  /// - Throws [TrustPinException] with code `PINS_MISMATCH` if the certificate is rejected.
  /// - Throws [TrustPinException] with code `ALL_PINS_EXPIRED` if no usable pins remain for the domain.
  /// - Throws [TrustPinException] with code `INVALID_SERVER_CERT` if the certificate cannot be parsed.
  /// - Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if [setup] has not been called.
  @Deprecated(
    'Use validateConnection() instead — it composes fetchCertificate + verify '
    'in a single channel call and bounds the whole operation with one timeout. '
    'verify() will be removed in a future major release.',
  )
  Future<void> verify(String domain, String certificate) async {
    try {
      await TrustPinSDKPlatform.instance
          .verify(domain, certificate, instanceId: _instanceId);
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Sets the log level for this instance.
  ///
  /// Use [TrustPinLogLevel.error] or [TrustPinLogLevel.none] in production.
  /// Set the level before [setup] for complete coverage.
  Future<void> setLogLevel(TrustPinLogLevel level) async {
    try {
      await TrustPinSDKPlatform.instance
          .setLogLevel(level.value, instanceId: _instanceId);
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Returns the TLS leaf certificate served by [host]:[port] as a PEM
  /// string.
  ///
  /// **Deprecated.** Prefer [validateConnection], which keeps the certificate
  /// inside the platform layer instead of marshalling it through the Dart
  /// isolate. `fetchCertificate` remains supported for diagnostic flows
  /// where the caller needs the PEM bytes (for example, to display the
  /// SHA-256 fingerprint).
  ///
  /// [timeout] is an optional upper bound on the call; when `null`, the
  /// platform default is used.
  ///
  /// - Throws [TrustPinException] with code `INVALID_SERVER_CERT` on connection failure.
  /// - Throws [TrustPinException] with code `FETCH_CERTIFICATE_TIMEOUT` if [timeout] is exceeded.
  @Deprecated(
    'Use validateConnection() instead — it keeps the certificate inside the '
    'platform layer instead of marshalling it through the Dart isolate. '
    'fetchCertificate() will be removed in a future major release.',
  )
  Future<String> fetchCertificate(
    String host, {
    int port = 443,
    Duration? timeout,
  }) async {
    try {
      return await TrustPinSDKPlatform.instance.fetchCertificate(
        host,
        port: port,
        timeoutMs: timeout?.inMilliseconds,
        instanceId: _instanceId,
      );
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Validates that [host]:[port] is allowed under this instance's pinning
  /// configuration. Returns normally on success.
  ///
  /// The platform composes the leaf-certificate fetch and pin verification
  /// inside a single channel call, so the certificate never enters the Dart
  /// isolate. This is the recommended entry point for cert-pinned HTTPS;
  /// [fetchCertificate] and [verify] remain available for diagnostic or
  /// custom-flow use cases.
  ///
  /// ```dart
  /// try {
  ///   await TrustPin.shared.validateConnection('api.example.com');
  /// } on TrustPinException catch (e) {
  ///   if (e.isPinsMismatch) {
  ///     // Certificate didn't match any configured pin.
  ///   }
  /// }
  /// ```
  ///
  /// [timeout] is an optional upper bound on the entire operation (TLS
  /// handshake, chain validation, configuration refresh if any, and pin
  /// comparison). When `null`, the platform default is used.
  ///
  /// - Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if [setup] has not been called.
  /// - Throws [TrustPinException] with code `INVALID_SERVER_CERT` on connection failure.
  /// - Throws [TrustPinException] with code `DOMAIN_NOT_REGISTERED` if domain is not configured (strict mode only).
  /// - Throws [TrustPinException] with code `PINS_MISMATCH` if the certificate is rejected.
  /// - Throws [TrustPinException] with code `ALL_PINS_EXPIRED` if no usable pins remain for the domain.
  /// - Throws [TrustPinException] with code `ERROR_FETCHING_PINNING_INFO` if pinning information cannot be retrieved.
  /// - Throws [TrustPinException] with code `FETCH_CERTIFICATE_TIMEOUT` if [timeout] is exceeded.
  Future<void> validateConnection(
    String host, {
    int port = 443,
    Duration? timeout,
  }) async {
    try {
      await TrustPinSDKPlatform.instance.validateConnection(
        host,
        port: port,
        timeoutMs: timeout?.inMilliseconds,
        instanceId: _instanceId,
      );
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }
}
