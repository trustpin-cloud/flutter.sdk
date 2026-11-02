import 'package:http/http.dart' as http;

import '../trustpin_sdk.dart';
import 'attestation_support.dart';

/// A certificate pinning client for the `http` package.
///
/// Wraps any [http.Client] and validates HTTPS requests through TrustPin.
/// Non-HTTPS requests pass through unchanged. [TrustPin.setup] must have
/// been called on the underlying instance before making requests.
///
/// When the app uses the `trustpin_attest` package, HTTPS requests to its
/// attested hosts also get the `TrustPin-Attestation` header (see
/// [TrustPin.attestationHeaders]). A header the request already carries is
/// never replaced. Redirects of such a request are followed by this client,
/// so each hop is pinned and gets its own attestation header: the header
/// meant for one host never reaches another.
class TrustPinHttpClient extends http.BaseClient {
  static const Duration _validateTimeout = Duration(seconds: 10);

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
    if (uri.scheme != 'https') {
      return _inner.send(request);
    }

    await _validate(uri);

    final attestation = await _instance.attestationHeaders(
      uri,
      method: request.method,
      headers: request.headers,
    );
    var added = false;
    for (final entry in attestation.entries) {
      if (!hasHeader(request.headers, entry.key)) {
        request.headers[entry.key] = entry.value;
        added = true;
      }
    }
    if (!added) {
      return _inner.send(request);
    }

    // The request carries an attestation header: never let the inner
    // client follow a redirect with it.
    final follow =
        request.followRedirects && isRedirectableMethod(request.method);
    request.followRedirects = false;
    final response = await _inner.send(request);
    if (!follow) return response;
    return _followRedirects(request, response);
  }

  Future<http.StreamedResponse> _followRedirects(
    http.BaseRequest original,
    http.StreamedResponse first,
  ) async {
    var response = first;
    var current = original;
    var redirects = 0;
    while (redirectStatuses.contains(response.statusCode)) {
      final location = response.headers['location'];
      if (location == null) break;
      await response.stream.drain<void>();
      if (redirects >= original.maxRedirects) {
        throw http.ClientException('Redirect limit exceeded', current.url);
      }

      final next = current.url.resolve(location);
      if (next.scheme == 'https') {
        await _validate(next);
      }
      final headers = await _instance.redirectedRequestHeaders(
        next,
        method: current.method,
        headers: headersForHop(current.headers, current.url, next),
      );
      final request = http.Request(current.method, next)
        ..followRedirects = false
        ..persistentConnection = original.persistentConnection
        ..headers.addAll(headers);

      redirects++;
      current = request;
      response = await _inner.send(request);
    }
    return response;
  }

  Future<void> _validate(Uri uri) => _instance.validateConnection(
        uri.host,
        port: uri.port,
        timeout: _validateTimeout,
      );

  @override
  void close() {
    _inner.close();
  }
}
