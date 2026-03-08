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
/// TrustPin provides SSL certificate pinning functionality to prevent man-in-the-middle (MITM) attacks
/// by validating server certificates against pre-configured public key pins. The library supports
/// both strict and permissive validation modes to accommodate different security requirements.
///
/// ## Overview
///
/// TrustPin uses JSON Web Signature (JWS) based configuration to securely deliver pinning
/// configurations to your Flutter application. The SDK fetches signed pinning configuration
/// from the TrustPin CDN and validates certificates against SHA-256 or SHA-512 hashes.
///
/// ## Key Features
/// - **JWS-based Configuration**: Fetches signed pinning configuration from TrustPin CDN
/// - **Certificate Validation**: Supports SHA-256 and SHA-512 certificate hashing
/// - **Signature Verification**: Validates JWS signatures using ECDSA P-256
/// - **Intelligent Caching**: Caches configuration for 10 minutes with stale fallback
/// - **Thread Safety**: All operations are thread-safe and work with Flutter's async model
/// - **Configurable Logging**: Multiple log levels for debugging and monitoring
/// - **Cross-Platform**: Works on iOS, Android, and macOS with native implementations
/// - **Multiple Instances**: Use [shared] for a single-project app, or [instance] for libraries and multi-tenant setups
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
/// - **Production**: Always use [TrustPinMode.strict] mode to ensure all connections are validated
/// - **Development**: Use [TrustPinMode.permissive] mode to allow connections to unregistered domains
/// - **Credentials**: Keep your public key secure and never commit it to version control in plain text
/// - **Network**: Ensure your app can reach `https://cdn.trustpin.cloud` for configuration updates
///
/// ## Thread Safety
///
/// All TrustPin operations are thread-safe and can be called from any isolate.
/// Internal operations are performed on appropriate background threads through
/// the native platform implementations.
///
/// - Note: Always call [setup] before performing certificate verification.
/// - Important: Use [TrustPinMode.strict] mode in production environments for maximum security.
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
    assert(id != 'default',
        'Use TrustPin.shared to access the default instance.');
    assert(id.trim().isNotEmpty, 'TrustPin instance id cannot be empty.');
    return _instances.putIfAbsent(id, () => TrustPin._(id));
  }

  /// The instance identifier passed to the native platform layer.
  /// `null` for the shared (default) instance.
  final String? _instanceId;

  /// Private named constructor.
  TrustPin._(this._instanceId);

  /// Initializes this TrustPin instance with the specified configuration.
  ///
  /// This method configures TrustPin with your organization credentials and fetches
  /// the pinning configuration from the TrustPin service. The configuration is cached
  /// for 10 minutes to optimize performance and reduce network requests.
  ///
  /// ## Example Usage
  ///
  /// ```dart
  /// // Production setup with strict mode
  /// const config = TrustPinConfiguration(
  ///   organizationId: 'prod-org-123',
  ///   projectId: 'mobile-app-v2',
  ///   publicKey: 'LS0tLS1CRUdJTi...',
  ///   mode: TrustPinMode.strict,
  /// );
  /// await TrustPin.shared.setup(config);
  ///
  /// // Development setup with permissive mode
  /// const devConfig = TrustPinConfiguration(
  ///   organizationId: 'dev-org-456',
  ///   projectId: 'mobile-app-staging',
  ///   publicKey: 'LS0tLS1CRUdJTk...',
  ///   mode: TrustPinMode.permissive,
  /// );
  /// await TrustPin.shared.setup(devConfig);
  /// ```
  ///
  /// ## Security Considerations
  ///
  /// - **Production**: Always use [TrustPinMode.strict] mode to ensure all connections are validated
  /// - **Development**: Use [TrustPinMode.permissive] mode to allow connections to unregistered domains
  /// - **Credentials**: Keep your public key secure and never commit it to version control in plain text
  ///
  /// ## Network Requirements
  ///
  /// This method requires network access to fetch the pinning configuration from
  /// `https://cdn.trustpin.cloud`. Ensure your app has appropriate network permissions
  /// and can reach this endpoint.
  ///
  /// - Parameter [configuration]: A [TrustPinConfiguration] containing your organization credentials, project info, and pinning settings
  ///
  /// - Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if credentials are invalid or empty
  /// - Throws [TrustPinException] with code `ERROR_FETCHING_PINNING_INFO` if network request fails
  /// - Throws [TrustPinException] with code `CONFIGURATION_VALIDATION_FAILED` if configuration validation fails
  ///
  /// - Important: This method must be called before any certificate verification operations.
  /// - Note: Configuration is automatically cached for 10 minutes to improve performance.
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

  /// Verifies a certificate against the specified domain using public key pinning.
  ///
  /// This method performs certificate validation by comparing the certificate's public key
  /// against the configured pins for the specified domain. It supports both SHA-256 and
  /// SHA-512 hash algorithms for pin matching.
  ///
  /// ## Example Usage
  ///
  /// ```dart
  /// final pemCertificate = '''
  /// -----BEGIN CERTIFICATE-----
  /// MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
  /// -----END CERTIFICATE-----
  /// ''';
  ///
  /// try {
  ///   await TrustPin.shared.verify('api.example.com', pemCertificate);
  ///   print('Certificate is valid!');
  /// } on TrustPinException catch (e) {
  ///   if (e.isDomainNotRegistered) {
  ///     print('Domain not configured for pinning');
  ///   } else if (e.isPinsMismatch) {
  ///     print('Certificate doesn\'t match configured pins');
  ///   }
  ///   // Handle other error types...
  /// }
  /// ```
  ///
  /// ## Security Behavior
  ///
  /// - **Registered domains**: Certificate validation is performed against configured pins
  /// - **Unregistered domains**: Behavior depends on the configured [TrustPinMode]:
  ///   - [TrustPinMode.strict]: Throws [TrustPinException] with code `DOMAIN_NOT_REGISTERED`
  ///   - [TrustPinMode.permissive]: Allows connection to proceed with info log
  ///
  /// ## Certificate Format
  ///
  /// The certificate must be in PEM format, including the BEGIN and END markers.
  /// Both single and multiple certificate chains are supported. The leaf certificate
  /// (first certificate in the chain) is used for validation.
  ///
  /// - Parameter [domain]: The domain name to validate (e.g., "api.example.com", will be sanitized)
  /// - Parameter [certificate]: PEM-encoded certificate string with BEGIN/END markers
  ///
  /// - Throws [TrustPinException] with code `DOMAIN_NOT_REGISTERED` if domain is not configured (strict mode only)
  /// - Throws [TrustPinException] with code `PINS_MISMATCH` if certificate doesn't match any configured pins
  /// - Throws [TrustPinException] with code `ALL_PINS_EXPIRED` if all pins for the domain have expired
  /// - Throws [TrustPinException] with code `INVALID_SERVER_CERT` if certificate format is invalid
  /// - Throws [TrustPinException] with code `INVALID_PROJECT_CONFIG` if [setup] has not been called
  ///
  /// - Important: Call [setup] before using this method.
  /// - Note: This method is thread-safe and can be called from any isolate.
  Future<void> verify(String domain, String certificate) async {
    try {
      await TrustPinSDKPlatform.instance
          .verify(domain, certificate, instanceId: _instanceId);
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Sets the current log level for this TrustPin instance's logging system.
  ///
  /// Logging helps with debugging certificate pinning issues and monitoring
  /// security events. Different log levels provide varying amounts of detail.
  ///
  /// ## Log Levels
  ///
  /// - [TrustPinLogLevel.none]: No logging output
  /// - [TrustPinLogLevel.error]: Only error messages
  /// - [TrustPinLogLevel.info]: Errors and informational messages
  /// - [TrustPinLogLevel.debug]: All messages including detailed debug information
  ///
  /// ## Example Usage
  ///
  /// ```dart
  /// // Enable debug logging for development
  /// await TrustPin.shared.setLogLevel(TrustPinLogLevel.debug);
  ///
  /// // Minimal logging for production
  /// await TrustPin.shared.setLogLevel(TrustPinLogLevel.error);
  ///
  /// // Disable all logging
  /// await TrustPin.shared.setLogLevel(TrustPinLogLevel.none);
  /// ```
  ///
  /// ## Performance Considerations
  ///
  /// - **Production**: Use [TrustPinLogLevel.error] or [TrustPinLogLevel.none] to minimize performance impact
  /// - **Development**: Use [TrustPinLogLevel.debug] for detailed troubleshooting information
  /// - **Staging**: Use [TrustPinLogLevel.info] for balanced logging without excessive detail
  ///
  /// - Parameter [level]: The [TrustPinLogLevel] to use for filtering log messages
  ///
  /// - Note: This setting affects logging for this instance only.
  /// - Important: Set the log level before calling [setup] for complete logging coverage.
  Future<void> setLogLevel(TrustPinLogLevel level) async {
    try {
      await TrustPinSDKPlatform.instance
          .setLogLevel(level.value, instanceId: _instanceId);
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }

  /// Fetches the TLS leaf certificate from a host as a PEM string.
  ///
  /// Opens an ephemeral side-channel TLS connection, performs OS-level chain
  /// validation, extracts the leaf certificate, and immediately cancels the
  /// connection without sending any HTTP data.
  ///
  /// ## Example Usage
  ///
  /// ```dart
  /// try {
  ///   final pem = await TrustPin.shared.fetchCertificate('api.example.com');
  ///   await TrustPin.shared.verify('api.example.com', pem);
  ///   print('Certificate is valid!');
  /// } on TrustPinException catch (e) {
  ///   print('Failed: $e');
  /// }
  /// ```
  ///
  /// - Parameter [host]: Hostname to connect to (e.g. "api.example.com").
  /// - Parameter [port]: TCP port (default: 443).
  ///
  /// - Returns: PEM-encoded leaf certificate string.
  ///
  /// - Throws [TrustPinException] with code `INVALID_SERVER_CERT` if the TLS handshake fails.
  Future<String> fetchCertificate(String host, {int port = 443}) async {
    try {
      return await TrustPinSDKPlatform.instance
          .fetchCertificate(host, port: port, instanceId: _instanceId);
    } catch (e) {
      throw TrustPinException.fromPlatformException(e);
    }
  }
}
