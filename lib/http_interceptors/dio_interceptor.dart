import 'package:dio/dio.dart';

import '../trustpin_sdk.dart';
import 'attestation_support.dart';

/// A certificate pinning interceptor for the Dio HTTP client.
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(TrustPinDioInterceptor(dio: dio));
/// final response = await dio.get('https://api.example.com/data');
/// ```
///
/// HTTPS requests are validated; non-HTTPS requests pass through unchanged.
/// [TrustPin.setup] must have been called on the underlying instance before
/// making requests.
///
/// When the app uses the `trustpin_attest` package, HTTPS requests to its
/// attested hosts also get the `TrustPin-Attestation` header (see
/// [TrustPin.attestationHeaders]). A header the request already carries is
/// never replaced. Dio never follows a redirect of such a request itself:
/// given the [Dio] instance, this interceptor follows `GET` and `HEAD`
/// redirects, pinning each hop and asking for its own attestation header;
/// without it, the redirect response reaches your code.
class TrustPinDioInterceptor extends Interceptor {
  static const Duration _validateTimeout = Duration(seconds: 10);

  /// `extra` key holding how many more redirects this interceptor follows
  /// for a request that carries an attestation header.
  static const String _redirectsLeftKey = 'trustpin.redirectsLeft';

  /// `extra` key marking a redirect hop this interceptor built: its
  /// attestation headers are already in place.
  static const String _hopKey = 'trustpin.redirectHop';

  final TrustPin _instance;
  final Dio? _dio;

  /// Validates HTTPS requests against [instance] (or [TrustPin.shared] when
  /// null). [TrustPin.setup] must have been called on that instance before
  /// making requests.
  ///
  /// Pass the [dio] this interceptor is added to, so it can follow the
  /// redirects of requests that carry an attestation header.
  TrustPinDioInterceptor({TrustPin? instance, Dio? dio})
      : _instance = instance ?? TrustPin.shared,
        _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final uri = options.uri;

    // Only validate HTTPS requests
    if (uri.scheme != 'https') {
      handler.next(options);
      return;
    }

    try {
      await _instance.validateConnection(
        uri.host,
        port: uri.port,
        timeout: _validateTimeout,
      );
    } catch (e) {
      // Certificate validation failed, reject the request
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.connectionError,
          message: 'Certificate pinning validation failed',
        ),
      );
      return;
    }

    if (options.extra[_hopKey] != true) {
      await _addAttestationHeaders(options);
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!_isRedirectToFollow(response)) {
      handler.next(response);
      return;
    }
    try {
      handler.resolve(await _follow(response));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response == null || !_isRedirectToFollow(response)) {
      handler.next(err);
      return;
    }
    try {
      handler.resolve(await _follow(response));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<void> _addAttestationHeaders(RequestOptions options) async {
    final headers = await _instance.attestationHeaders(
      options.uri,
      method: options.method,
      headers: _flatten(options.headers),
    );
    var added = false;
    for (final entry in headers.entries) {
      if (!hasHeader(options.headers, entry.key)) {
        options.headers[entry.key] = entry.value;
        added = true;
      }
    }
    if (!added) return;

    // Never let Dio follow a redirect with the attestation header.
    if (options.followRedirects &&
        isRedirectableMethod(options.method) &&
        _dio != null) {
      options.extra[_redirectsLeftKey] = options.maxRedirects;
    }
    options.followRedirects = false;
  }

  bool _isRedirectToFollow(Response<dynamic> response) =>
      _dio != null &&
      response.requestOptions.extra[_redirectsLeftKey] is int &&
      redirectStatuses.contains(response.statusCode) &&
      response.headers.value('location') != null;

  Future<Response<dynamic>> _follow(Response<dynamic> response) async {
    final options = response.requestOptions;
    final left = options.extra[_redirectsLeftKey] as int;
    if (left <= 0) {
      throw DioException(
        requestOptions: options,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Redirect limit exceeded',
      );
    }

    final next = options.uri.resolve(response.headers.value('location')!);
    final headers = await _instance.redirectedRequestHeaders(
      next,
      method: options.method,
      headers: headersForHop(_flatten(options.headers), options.uri, next),
    );
    // The hop goes through the whole interceptor chain again, so it is
    // pinned by onRequest; the marker keeps its headers as computed here.
    final hop = options.copyWith(
      baseUrl: '',
      path: next.toString(),
      queryParameters: <String, dynamic>{},
      headers: headers,
      followRedirects: false,
      extra: {
        ...options.extra,
        _hopKey: true,
        _redirectsLeftKey: left - 1,
      },
    );
    return _dio!.fetch<dynamic>(hop);
  }

  /// Dio header values can be lists; the platform call takes one string per
  /// header.
  static Map<String, String> _flatten(Map<String, dynamic> headers) => {
        for (final entry in headers.entries)
          if (entry.value != null)
            entry.key: entry.value is List
                ? (entry.value as List).join(', ')
                : entry.value.toString(),
      };
}
