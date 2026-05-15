import '../model/domain_error.dart';
import '../model/pinning_credentials.dart';
import '../repository/configuration_repository.dart';
import '../repository/logger.dart';

/// Configure TrustPin from caller-supplied credentials. Input validation
/// happens up front; SDK exceptions are surfaced as [DomainError] by the
/// repository.
class ConfigurePinningUseCase {
  final ConfigurationRepository _repository;
  final Logger _logger;

  const ConfigurePinningUseCase(this._repository, this._logger);

  Future<void> call(PinningCredentials credentials) async {
    if (_repository.isConfigured()) {
      _logger.warning('Setup attempt ignored: TrustPin already configured');
      throw const ValidationError('TrustPin is already configured');
    }

    if (credentials.organizationId.trim().isEmpty ||
        credentials.projectId.trim().isEmpty ||
        credentials.publicKey.trim().isEmpty) {
      _logger.error('Configuration failed: Missing required fields');
      throw const ValidationError('Missing required fields');
    }

    _logger.info('Configuring TrustPin...');
    _logger.info('Mode: ${credentials.mode.value}');

    try {
      await _repository.configure(credentials);
      _logger.success('TrustPin configuration successful');
    } on DomainError catch (e) {
      _logger.error('TrustPin configuration failed: ${e.message}');
      rethrow;
    }
  }
}
