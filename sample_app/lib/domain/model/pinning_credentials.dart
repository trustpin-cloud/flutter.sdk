import 'package:trustpin_sdk/trustpin_sdk.dart';

/// Inputs needed to configure TrustPin for a project. Mirrors what the SDK's
/// [TrustPinConfiguration] takes, but kept as a domain-owned type so the
/// use-case layer does not depend on SDK types directly.
class PinningCredentials {
  final String organizationId;
  final String projectId;
  final String publicKey;
  final TrustPinMode mode;

  const PinningCredentials({
    required this.organizationId,
    required this.projectId,
    required this.publicKey,
    this.mode = TrustPinMode.strict,
  });
}
