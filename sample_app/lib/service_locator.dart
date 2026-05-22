import 'data/repository/http_network_repository.dart';
import 'data/repository/trustpin_configuration_repository.dart';
import 'domain/repository/configuration_repository.dart';
import 'domain/repository/logger.dart';
import 'domain/repository/network_repository.dart';
import 'domain/usecase/configure_pinning_from_bundle_use_case.dart';
import 'domain/usecase/configure_pinning_use_case.dart';
import 'domain/usecase/test_pinned_connection_use_case.dart';

/// Process-wide singletons + use-case factories. Sample-grade DI — one place
/// to wire concrete repositories, one factory per use case so each invocation
/// can take a request-scoped [Logger]. A real app would replace this with
/// `get_it`, `injectable`, Riverpod, etc.
class ServiceLocator {
  final ConfigurationRepository configurationRepository =
      TrustPinConfigurationRepository();
  final NetworkRepository networkRepository = HttpNetworkRepository();

  ConfigurePinningUseCase configurePinningUseCase(Logger logger) =>
      ConfigurePinningUseCase(configurationRepository, logger);

  ConfigurePinningFromBundleUseCase configurePinningFromBundleUseCase(
    Logger logger,
  ) => ConfigurePinningFromBundleUseCase(configurationRepository, logger);

  TestPinnedConnectionUseCase testPinnedConnectionUseCase(Logger logger) =>
      TestPinnedConnectionUseCase(
        configurationRepository,
        networkRepository,
        logger,
      );

  void dispose() {
    final network = networkRepository;
    if (network is HttpNetworkRepository) {
      network.close();
    }
  }
}
