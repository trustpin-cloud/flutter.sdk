import 'package:http/http.dart' as http;

import '../trustpin_sdk.dart';

/// A certificate pinning client for the `http` package.
///
/// Wraps any [http.Client] and validates HTTPS requests through TrustPin.
/// Non-HTTPS requests pass through unchanged. [TrustPin.setup] must have
/// been called on the underlying instance before making requests.
class TrustPinHttpClient extends http.BaseClient {
  static const Duration _fetchCertificateTimeout = Duration(seconds: 10);

  final http.Client _inner;
  final TrustPin _instance;

  /// Wraps [_inner] so HTTPS requests are validated by [instance] (or
  /// [TrustPin.shared] when null). [TrustPin.setup] must have been called
  /// on that instance before making requests.
  TrustPinHttpClient(
    this._inner, {
    TrustPin? instance,
  }) : _instance = instance ?? TrustPin.shared;

  /// Convenience factory using a default `http.Client` as inner.
  factory TrustPinHttpClient.create({TrustPin? instance}) {
    return TrustPinHttpClient(http.Client(), instance: instance);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;

    // Only validate HTTPS requests
    if (uri.scheme == 'https') {
      await _validateCertificate(uri.host, uri.port);
    }

    return _inner.send(request);
  }

  Future<void> _validateCertificate(String host, int port) async {
    final pem = await _instance.fetchCertificate(
      host,
      port: port,
      timeout: _fetchCertificateTimeout,
    );
    await _instance.verify(host, pem);
  }

  @override
  void close() {
    _inner.close();
  }
}
