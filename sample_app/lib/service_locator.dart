import 'data/repository/http_network_repository.dart';
import 'data/repository/trustpin_attest_repository.dart';
import 'data/repository/trustpin_certificate_repository.dart';
import 'data/repository/trustpin_configuration_repository.dart';
import 'domain/repository/attestation_repository.dart';
import 'domain/repository/certificate_repository.dart';
import 'domain/repository/configuration_repository.dart';
import 'domain/repository/logger.dart';
import 'domain/repository/network_repository.dart';
import 'domain/usecase/attestation_use_cases.dart';
import 'domain/usecase/configure_pinning_from_bundle_use_case.dart';
import 'domain/usecase/configure_pinning_use_case.dart';
import 'domain/usecase/fetch_certificate_use_case.dart';
import 'domain/usecase/test_pinned_connection_use_case.dart';

/// Process-wide singletons + use-case factories. Sample-grade DI — one place
/// to wire concrete repositories, one factory per use case so each invocation
/// can take a request-scoped [Logger]. A real app would replace this with
/// `get_it`, `injectable`, Riverpod, etc.
class ServiceLocator {
  final ConfigurationRepository configurationRepository =
      TrustPinConfigurationRepository();
  final NetworkRepository networkRepository = HttpNetworkRepository();
  final CertificateRepository certificateRepository =
      TrustPinCertificateRepository();
  final AttestationRepository attestationRepository =
      TrustPinAttestRepository();

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

  FetchCertificateUseCase fetchCertificateUseCase(Logger logger) =>
      FetchCertificateUseCase(certificateRepository, logger);

  SetUpAttestationUseCase setUpAttestationUseCase(Logger logger) =>
      SetUpAttestationUseCase(attestationRepository, logger);

  CallProtectedEndpointUseCase callProtectedEndpointUseCase(Logger logger) =>
      CallProtectedEndpointUseCase(attestationRepository, logger);

  CallSensitiveEndpointUseCase callSensitiveEndpointUseCase(Logger logger) =>
      CallSensitiveEndpointUseCase(attestationRepository, logger);

  SignOutSessionUseCase signOutSessionUseCase(Logger logger) =>
      SignOutSessionUseCase(attestationRepository, logger);

  ResetAttestationUseCase resetAttestationUseCase(Logger logger) =>
      ResetAttestationUseCase(attestationRepository, logger);

  void dispose() {
    final network = networkRepository;
    if (network is HttpNetworkRepository) {
      network.close();
    }
    final attestation = attestationRepository;
    if (attestation is TrustPinAttestRepository) {
      attestation.close();
    }
  }
}
