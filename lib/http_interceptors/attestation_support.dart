// Helpers the HTTP integrations share for app attestation headers and the
// redirects they follow themselves. Not exported.

/// The statuses whose `Location` the integrations follow.
const Set<int> redirectStatuses = {301, 302, 303, 307, 308};

/// Whether a request with [method] is followed on redirect. `dart:io` follows
/// only `GET` and `HEAD`; the integrations do the same.
bool isRedirectableMethod(String method) {
  final upper = method.toUpperCase();
  return upper == 'GET' || upper == 'HEAD';
}

/// Whether [headers] already holds [name], compared case-insensitively.
bool hasHeader(Map<String, dynamic> headers, String name) {
  final lower = name.toLowerCase();
  return headers.keys.any((key) => key.toLowerCase() == lower);
}

/// The headers to carry to a redirect hop from [from] to [to], before the
/// attestation headers are re-requested: as `dart:io` does, credentials and
/// cookies are dropped unless [to] is the same origin or a subdomain of it.
Map<String, String> headersForHop(
  Map<String, String> headers,
  Uri from,
  Uri to,
) {
  if (_isSubdomain(to, from)) return Map.of(headers);
  const dropped = {'authorization', 'www-authenticate', 'cookie', 'cookie2'};
  return {
    for (final entry in headers.entries)
      if (!dropped.contains(entry.key.toLowerCase())) entry.key: entry.value,
  };
}

bool _isSubdomain(Uri subdomain, Uri domain) =>
    subdomain.scheme == domain.scheme &&
    subdomain.port == domain.port &&
    (subdomain.host == domain.host ||
        subdomain.host.endsWith('.${domain.host}'));
