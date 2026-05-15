import '../model/connection_outcome.dart';
import '../model/domain_error.dart';
import '../repository/configuration_repository.dart';
import '../repository/logger.dart';
import '../repository/network_repository.dart';

/// Perform a TrustPin-pinned HTTPS GET against [url].
///
/// Logs the high-level milestones at info/success/error and the request
/// details at debug. The body preview is whatever the [NetworkRepository]
/// returns — truncation lives at the data boundary.
class TestPinnedConnectionUseCase {
  final ConfigurationRepository _configurationRepository;
  final NetworkRepository _networkRepository;
  final Logger _logger;

  const TestPinnedConnectionUseCase(
    this._configurationRepository,
    this._networkRepository,
    this._logger,
  );

  Future<ConnectionOutcome> call(String url) async {
    if (!_configurationRepository.isConfigured()) {
      _logger.warning('Test connection failed: TrustPin not configured');
      throw const ValidationError('TrustPin is not configured');
    }

    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _logger.warning('Test connection failed: No URL provided');
      throw const ValidationError('No URL provided');
    }

    _logger.info('Testing connection to: $trimmed');
    _logger.info('Using TrustPin SSL certificate validation');
    _logger.debug('Method: GET');
    _logger.debug('URL: $trimmed');
    _logger.debug('User-Agent: TrustPin-Flutter-Sample/1.0.0');

    try {
      final outcome = await _networkRepository.get(trimmed);
      _logger.success('Connection test successful!');
      _logger.debug('Status: ${outcome.statusCode} ${outcome.message}');
      _logger.debug('Headers: ${outcome.headerCount}');
      _logger.debug('Response preview: ${outcome.bodyPreview}');
      return outcome;
    } on DomainError catch (e) {
      _logger.error('Connection failed: ${e.message}');
      rethrow;
    }
  }
}
