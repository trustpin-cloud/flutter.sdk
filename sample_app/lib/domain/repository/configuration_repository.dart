import '../model/pinning_credentials.dart';

/// Boundary between the use-case layer and the TrustPin SDK's configuration
/// surface. Implementations translate SDK exceptions into [DomainError].
abstract interface class ConfigurationRepository {
  /// Whether [configure] (or [configureFromBundle]) has completed for this
  /// process.
  bool isConfigured();

  /// Configure the SDK from caller-supplied credentials.
  Future<void> configure(PinningCredentials credentials);

  /// Configure the SDK by loading credentials from the platform's native
  /// bundle file (Plist on iOS/macOS, JSON in Android assets). The native SDK
  /// owns the parsing; credentials never enter the Dart isolate, so there is
  /// no return value.
  Future<void> configureFromBundle();
}
