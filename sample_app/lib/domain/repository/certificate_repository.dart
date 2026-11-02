/// A server's leaf certificate, as fetched for display.
class CertificateInfo {
  final String pem;

  /// SHA-256 of the DER certificate, colon-separated hex.
  final String sha256Fingerprint;

  const CertificateInfo({required this.pem, required this.sha256Fingerprint});
}

/// Fetches the certificate a server presents, for the Pinning tab's
/// **Fetch Certificate** diagnostic. Implementations translate SDK exceptions
/// into DomainError.
abstract interface class CertificateRepository {
  Future<CertificateInfo> fetch(String host, int port);
}
