import '../model/domain_error.dart';
import '../model/pinning_credentials.dart';
import '../repository/configuration_repository.dart';
import '../repository/logger.dart';

/// Configure TrustPin by loading the bundled `trustpin.json` asset — the
/// recommended setup path for SDK 4.3.+. Returns the loaded credentials so
/// the caller can render the non-sensitive fields.
class ConfigurePinningFromAssetsUseCase {
  final ConfigurationRepository _repository;
  final Logger _logger;

  const ConfigurePinningFromAssetsUseCase(this._repository, this._logger);

  Future<PinningCredentials> call() async {
    if (_repository.isConfigured()) {
      _logger.warning('Setup attempt ignored: TrustPin already configured');
      throw const ValidationError('TrustPin is already configured');
    }

    _logger.info('Loading TrustPin configuration from trustpin.json...');

    try {
      final credentials = await _repository.configureFromAssets();
      _logger.success('TrustPin configured from trustpin.json');
      return credentials;
    } on DomainError catch (e) {
      _logger.error('Failed to configure from trustpin.json: ${e.message}');
      rethrow;
    }
  }
}
