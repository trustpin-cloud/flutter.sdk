import 'package:dio/dio.dart';

import '../trustpin_sdk.dart';

/// A certificate pinning interceptor for the Dio HTTP client.
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(TrustPinDioInterceptor());
/// final response = await dio.get('https://api.example.com/data');
/// ```
///
/// HTTPS requests are validated; non-HTTPS requests pass through unchanged.
/// [TrustPin.setup] must have been called on the underlying instance before
/// making requests.
class TrustPinDioInterceptor extends Interceptor {
  static const Duration _fetchCertificateTimeout = Duration(seconds: 10);

  final TrustPin _instance;

  /// Validates HTTPS requests against [instance] (or [TrustPin.shared] when
  /// null). [TrustPin.setup] must have been called on that instance before
  /// making requests.
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
    final pem = await _instance.fetchCertificate(
      host,
      port: port,
      timeout: _fetchCertificateTimeout,
    );
    await _instance.verify(host, pem);
  }
}
