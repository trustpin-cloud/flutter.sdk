import '../model/pinning_credentials.dart';

/// Boundary between the use-case layer and the TrustPin SDK's configuration
/// surface. Implementations translate SDK exceptions into [DomainError].
abstract interface class ConfigurationRepository {
  /// Whether [configure] (or [configureFromAssets]) has completed for this
  /// process.
  bool isConfigured();

  /// Configure the SDK from caller-supplied credentials.
  Future<void> configure(PinningCredentials credentials);

  /// Load credentials from the bundled `trustpin.json` asset and configure.
  /// Returns the loaded credentials so the caller can echo non-sensitive
  /// fields into the log feed.
  Future<PinningCredentials> configureFromAssets();
}
