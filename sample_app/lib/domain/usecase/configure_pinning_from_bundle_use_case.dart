import '../model/domain_error.dart';
import '../repository/configuration_repository.dart';
import '../repository/logger.dart';

/// Configure TrustPin by loading credentials from the platform's native
/// bundle file — `TrustPin-Info.plist` on iOS/macOS, `trustpin.json` in
/// Android assets. The native SDK owns the parsing and the credentials never
/// enter the Dart isolate.
class ConfigurePinningFromBundleUseCase {
  final ConfigurationRepository _repository;
  final Logger _logger;

  const ConfigurePinningFromBundleUseCase(this._repository, this._logger);

  Future<void> call() async {
    if (_repository.isConfigured()) {
      _logger.warning('Setup attempt ignored: TrustPin already configured');
      throw const ValidationError('TrustPin is already configured');
    }

    _logger.info('Loading TrustPin configuration from native bundle file...');

    try {
      await _repository.configureFromBundle();
      _logger.success('TrustPin configured from native bundle');
    } on DomainError catch (e) {
      _logger.error('Failed to configure from native bundle: ${e.message}');
      rethrow;
    }
  }
}
