import 'trustpin_mode.dart';

/// Configuration for the TrustPin SDK.
///
/// Contains all credentials and settings needed to initialize TrustPin.
/// Create an instance and pass it to [TrustPin.setup] to configure the SDK.
///
/// To load credentials from a platform bundle file (Plist on iOS/macOS, JSON
/// in Android assets) without writing them into Dart source, use
/// [TrustPin.setupWithNativeBundle] instead.
///
/// ## Example
///
/// ```dart
/// const config = TrustPinConfiguration(
///   organizationId: 'your-org-id',
///   projectId: 'your-project-id',
///   publicKey: 'LS0tLS1CRUdJTi...',
/// );
///
/// await TrustPin.shared.setup(config);
/// ```
class TrustPinConfiguration {
  /// Your organization identifier from the TrustPin dashboard.
  final String organizationId;

  /// Your project identifier from the TrustPin dashboard.
  final String projectId;

  /// Base64-encoded public key issued by the TrustPin dashboard.
  final String publicKey;

  /// Optional override for the configuration source.
  ///
  /// Leave as `null` (the default) to use the TrustPin-hosted configuration.
  /// Only set this for self-hosted configurations.
  final Uri? configurationURL;

  /// The pinning mode controlling behavior for unregistered domains.
  ///
  /// Defaults to [TrustPinMode.strict].
  final TrustPinMode mode;

  /// Name of a signed configuration bundled with the app, used as a
  /// **last-resort fallback** when no online source and no previously fetched
  /// configuration is available, typically the app's very first start during
  /// an outage.
  ///
  /// The same file name is resolved on each platform:
  ///
  /// - **iOS / macOS**: a resource of the app's main bundle. Add the file to
  ///   the app target's *Copy Bundle Resources*.
  /// - **Android**: an asset, i.e. `android/app/src/main/assets/<name>`.
  ///
  /// Note this is **not** a Flutter asset declared in `pubspec.yaml`: Flutter
  /// assets live inside `flutter_assets/` and are not visible to the native
  /// bundle/asset loaders. Ship the file per platform, exactly like
  /// `TrustPin-Info.plist` / `trustpin.json`.
  ///
  /// Use it only in applications protected by runtime application
  /// self-protection (RASP) that guards bundled resources against
  /// modification. The file must be the unmodified signed payload downloaded
  /// from the TrustPin dashboard for this project; it is verified against
  /// [publicKey] during setup, and regenerating it in CI on every release
  /// keeps it from going stale.
  ///
  /// Leave `null` (the default) to ship no fallback.
  final String? embeddedConfigurationFile;

  /// Creates a TrustPin configuration.
  ///
  /// - Parameter [organizationId]: Your organization identifier from the TrustPin dashboard
  /// - Parameter [projectId]: Your project identifier from the TrustPin dashboard
  /// - Parameter [publicKey]: Base64-encoded public key issued by the TrustPin dashboard
  /// - Parameter [configurationURL]: Optional override for the configuration source. Defaults to `null` for the TrustPin-hosted configuration
  /// - Parameter [mode]: The pinning mode (default: [TrustPinMode.strict])
  /// - Parameter [embeddedConfigurationFile]: Optional bundled signed configuration used only when every online source is unreachable. Defaults to `null`
  const TrustPinConfiguration({
    required this.organizationId,
    required this.projectId,
    required this.publicKey,
    this.configurationURL,
    this.mode = TrustPinMode.strict,
    this.embeddedConfigurationFile,
  });
}
