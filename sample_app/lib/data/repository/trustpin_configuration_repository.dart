import 'package:trustpin_sdk/trustpin_sdk.dart';

import '../../domain/model/domain_error.dart';
import '../../domain/model/pinning_credentials.dart';
import '../../domain/repository/configuration_repository.dart';

/// Adapts [TrustPin] to the [ConfigurationRepository] contract. The mutable
/// [_configured] flag mirrors what a real app might persist across launches.
class TrustPinConfigurationRepository implements ConfigurationRepository {
  bool _configured = false;

  @override
  bool isConfigured() => _configured;

  @override
  Future<void> configure(PinningCredentials credentials) async {
    try {
      await TrustPin.shared.setup(
        TrustPinConfiguration(
          organizationId: credentials.organizationId,
          projectId: credentials.projectId,
          publicKey: credentials.publicKey,
          mode: credentials.mode,
        ),
      );
      _configured = true;
    } on TrustPinException catch (e) {
      _configured = false;
      throw PinningError(e.code, e.message);
    } catch (e) {
      _configured = false;
      throw UnknownError(e.toString());
    }
  }

  @override
  Future<void> configureFromBundle() async {
    try {
      await TrustPin.shared.setupWithNativeBundle();
      _configured = true;
    } on TrustPinException catch (e) {
      _configured = false;
      throw PinningError(e.code, e.message);
    } catch (e) {
      _configured = false;
      throw UnknownError(e.toString());
    }
  }
}
