import 'package:http/http.dart' as http;

import '../trustpin_sdk.dart';

/// A certificate pinning interceptor for the http package.
///
/// This interceptor wraps any http.Client and adds TrustPin certificate
/// validation to all HTTPS requests. It first ensures the certificate passes
/// standard TLS validation (via [TrustPin.fetchCertificate]), then performs
/// additional TrustPin verification.
///
/// Certificates are cached to avoid repeated TLS connections to the same
/// host. The cache stores PEM strings but not validation results, so TrustPin
/// verification is performed on every request.
class TrustPinHttpClient extends http.BaseClient {
  final http.Client _inner;
  final TrustPin _instance;
  final Map<String, String> _certificateCache = {};

  /// Creates a new TrustPinHttpClient that wraps the provided client.
  ///
  /// The provided client will be used for making actual HTTP requests after
  /// certificate validation passes. When [instance] is provided, the client
  /// uses that TrustPin instance. When null, [TrustPin.shared] is used.
  ///
  /// The TrustPin instance must be properly configured with [TrustPin.setup]
  /// before making requests.
  TrustPinHttpClient(this._inner, {TrustPin? instance})
      : _instance = instance ?? TrustPin.shared;

  /// Creates a TrustPinHttpClient with a default http.Client.
  ///
  /// When [instance] is provided, the client uses that TrustPin instance.
  /// When null, [TrustPin.shared] is used.
  ///
  /// The TrustPin instance must be properly configured with [TrustPin.setup]
  /// before making requests.
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

  @override
  void close() {
    _certificateCache.clear();
    _inner.close();
  }
}
