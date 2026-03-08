import 'package:dio/dio.dart';

import '../trustpin_sdk.dart';

/// A certificate pinning interceptor for the Dio HTTP client.
///
/// This interceptor adds TrustPin certificate validation to all HTTPS requests
/// made through Dio. It validates certificates in two phases:
/// 1. Standard TLS validation (handled by the OS via [TrustPin.fetchCertificate])
/// 2. TrustPin certificate pinning validation
///
/// Certificates are cached to avoid repeated TLS connections to the same
/// host. The cache stores PEM strings but not validation results, so TrustPin
/// verification is performed on every request.
///
/// ## Usage
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(TrustPinDioInterceptor());
///
/// // Now all HTTPS requests will have certificate pinning
/// final response = await dio.get('https://api.example.com/data');
/// ```
///
/// ## Important Notes
///
/// - The TrustPin instance must be initialized with [TrustPin.setup] before using this interceptor
/// - Only HTTPS requests are validated; HTTP requests pass through unchanged
/// - Certificate validation happens before the actual HTTP request is sent
/// - Failed validation prevents the request from being sent
class TrustPinDioInterceptor extends Interceptor {
  final Map<String, String> _certificateCache = {};
  final TrustPin _instance;

  /// Creates a new TrustPinDioInterceptor.
  ///
  /// When [instance] is provided, the interceptor uses that TrustPin instance
  /// for certificate validation. When null, [TrustPin.shared] is used.
  ///
  /// The TrustPin instance must be properly configured with [TrustPin.setup]
  /// before making requests with this interceptor.
  TrustPinDioInterceptor({TrustPin? instance})
      : _instance = instance ?? TrustPin.shared;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final uri = options.uri;

    // Only validate HTTPS requests
    if (uri.scheme == 'https') {
      try {
        await _validateCertificate(uri.host, uri.port);
        // Certificate validation passed, proceed with request
        handler.next(options);
      } on TrustPinException catch (e) {
        // Certificate validation failed, reject the request
        handler.reject(
          DioException(
            requestOptions: options,
            error: e,
            type: DioExceptionType.connectionError,
            message: 'Certificate pinning validation failed',
          ),
        );
      } catch (e) {
        // Other errors during validation
        handler.reject(
          DioException(
            requestOptions: options,
            error: e,
            type: DioExceptionType.connectionError,
            message: 'Certificate pinning validation failed',
          ),
        );
      }
    } else {
      // Not HTTPS, proceed without validation
      handler.next(options);
    }
  }

  Future<void> _validateCertificate(String host, int port) async {
    final cacheKey = '$host:$port';

    // Check if we have a cached certificate for this host
    var pemCert = _certificateCache[cacheKey];
    if (pemCert == null) {
      // Fetch the leaf certificate via native OS-level TLS validation
      pemCert = await _instance.fetchCertificate(host, port: port);
      _certificateCache[cacheKey] = pemCert;
    }

    await _instance.verify(host, pemCert);
  }

  /// Clears the certificate cache.
  ///
  /// Call this method if you want to force fetching fresh certificates
  /// for all hosts on the next request.
  void clearCertificateCache() {
    _certificateCache.clear();
  }
}
