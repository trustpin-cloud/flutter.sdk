import '../model/domain_error.dart';
import '../repository/certificate_repository.dart';
import '../repository/logger.dart';

/// Fetch the certificate the server at [call]'s URL presents and log its
/// SHA-256 fingerprint, redacted: to configure pins, read it from a
/// copy-friendly UI, not the log.
class FetchCertificateUseCase {
  final CertificateRepository _repository;
  final Logger _logger;

  const FetchCertificateUseCase(this._repository, this._logger);

  Future<CertificateInfo> call(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _logger.warning('Fetch certificate failed: enter an https:// URL');
      throw const ValidationError('Enter an https:// URL');
    }

    _logger.info('🔐 Fetching certificate from: ${uri.host}:${uri.port}');
    try {
      final info = await _repository.fetch(uri.host, uri.port);
      _logger.success('Certificate fetched successfully!');
      _logger.info(
        '🔑 Certificate SHA256: ${_redacted(info.sha256Fingerprint)}',
      );
      _logger.debug(
        '📜 Certificate body: ${info.pem.length} characters of PEM',
      );
      return info;
    } on DomainError catch (e) {
      _logger.error('Failed to fetch certificate: ${e.message}');
      rethrow;
    }
  }

  static String _redacted(String fingerprint) =>
      fingerprint.length > 8 ? '${fingerprint.substring(0, 8)}…' : fingerprint;
}
