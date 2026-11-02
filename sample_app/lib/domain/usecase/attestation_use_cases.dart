import '../model/attestation_status.dart';
import '../model/domain_error.dart';
import '../repository/attestation_repository.dart';
import '../repository/logger.dart';

/// Set up TrustPinAttest from the native configuration file and prefetch a
/// token.
class SetUpAttestationUseCase {
  final AttestationRepository _repository;
  final Logger _logger;

  const SetUpAttestationUseCase(this._repository, this._logger);

  Future<void> call() async {
    _logger.info('🛡 Setting up TrustPinAttest from the native bundle file...');
    try {
      await _repository.setUp();
      _logger.success('TrustPinAttest configured; prefetching a token');
    } on DomainError catch (e) {
      _logger.error('TrustPinAttest setup failed: ${e.message}');
      rethrow;
    }
  }
}

/// Call the sample API's protected endpoint and report whether the request
/// carried the attestation header and what the API verified.
class CallProtectedEndpointUseCase {
  final AttestationRepository _repository;
  final Logger _logger;

  const CallProtectedEndpointUseCase(this._repository, this._logger);

  Future<ProtectedCallOutcome> call() async {
    _logger.info('🛡 Calling the protected sample endpoint...');
    try {
      final outcome = await _repository.callProtectedEndpoint();
      final ok = outcome.statusCode >= 200 && outcome.statusCode < 300;
      final answered = outcome.headline;
      if (ok && outcome.headerAttached) {
        _logger.success(answered);
      } else {
        _logger.warning(answered);
      }
      final summary = outcome.attestationSummary;
      if (summary != null) {
        _logger.info('   API attestation: $summary');
      }
      if (outcome.body.isNotEmpty) {
        _logger.info('   Reply:\n${outcome.body}');
      }
      return outcome;
    } on DomainError catch (e) {
      _logger.error('Protected call failed: ${e.message}');
      rethrow;
    }
  }
}

/// Call the sample API's sensitive endpoint with the token and an assertion
/// over the request body, and report what the API verified.
class CallSensitiveEndpointUseCase {
  final AttestationRepository _repository;
  final Logger _logger;

  const CallSensitiveEndpointUseCase(this._repository, this._logger);

  Future<ProtectedCallOutcome> call() async {
    _logger.info('🛡 Sensitive call: token + assertion over the body...');
    try {
      final outcome = await _repository.callSensitiveEndpoint();
      final ok = outcome.statusCode >= 200 && outcome.statusCode < 300;
      if (ok) {
        _logger.success('Sensitive call answered HTTP ${outcome.statusCode}');
      } else {
        _logger.warning('Sensitive call answered HTTP ${outcome.statusCode}');
      }
      final summary = outcome.attestationSummary;
      if (summary != null) {
        _logger.info('   API attestation: $summary');
      }
      if (outcome.body.isNotEmpty) {
        _logger.info('   Reply:\n${outcome.body}');
      }
      return outcome;
    } on DomainError catch (e) {
      _logger.error('Sensitive call failed: ${e.message}');
      rethrow;
    }
  }
}

/// Drop the sample API session. The next protected call signs in again, and
/// the new `Authorization` value re-binds the token.
class SignOutSessionUseCase {
  final AttestationRepository _repository;
  final Logger _logger;

  const SignOutSessionUseCase(this._repository, this._logger);

  void call() {
    _repository.signOut();
    _logger.info(
      '🔑 Session discarded: the next protected call signs in again; the new '
      'session value re-binds the token (expect a token refresh, not a new key)',
    );
  }
}

/// Discard the device key: the next call attests a new one.
class ResetAttestationUseCase {
  final AttestationRepository _repository;
  final Logger _logger;

  const ResetAttestationUseCase(this._repository, this._logger);

  Future<void> call() async {
    try {
      await _repository.reset();
      _logger.info('🛡 Attestation reset: the next call attests a new key');
    } on DomainError catch (e) {
      _logger.error('Attestation reset failed: ${e.message}');
      rethrow;
    }
  }
}
