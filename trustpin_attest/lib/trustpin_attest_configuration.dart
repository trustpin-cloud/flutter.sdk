/// Configuration for [TrustPinAttest.setup], given in code. To read it from
/// the platform configuration files instead, use
/// [TrustPinAttest.setupWithNativeBundle].
///
/// ```dart
/// final configuration = TrustPinAttestConfiguration(
///   verifierUrl: Uri.parse('https://attest.example.com'),
///   attestedHosts: ['api.example.com'],
/// );
/// await TrustPinAttest.shared.setup(configuration);
/// ```
///
/// The native SDK validates the values when [TrustPinAttest.setup] runs and
/// throws `INVALID_CONFIGURATION` when one is rejected.
class TrustPinAttestConfiguration {
  /// The base URL of your TrustPin verifier: `https://` on a host name,
  /// without credentials, query or fragment. Its host must be a registered
  /// domain of the TrustPin project when pinning runs in strict mode.
  final Uri verifierUrl;

  /// The hosts that receive the `TrustPin-Attestation` header: one to fifty
  /// host names, each exact or `*.example.com` for exactly one label. No IP
  /// addresses. No other host ever receives the header.
  final List<String> attestedHosts;

  /// Android only: the number of the Google Cloud project linked to the app
  /// in Play Console, needed when the policy uses Play Integrity. Leave it
  /// out otherwise: with a number, the app contacts Google Play services from
  /// setup on. Ignored on iOS and macOS.
  final int? googleCloudProjectNumber;

  /// A debug token for development builds on simulators and emulators. Pass
  /// it from the build, for example
  /// `String.fromEnvironment('TRUSTPIN_DEBUG_TOKEN')` with
  /// `--dart-define=TRUSTPIN_DEBUG_TOKEN=…`; never bundle it in a file.
  ///
  /// It is used only where the native SDK has a debug path, and only when
  /// both the policy and the verifier allow debug tokens:
  /// - **Android:** in debuggable builds (emulators and devices).
  /// - **iOS:** on the simulator.
  /// - **macOS, iOS devices:** never.
  ///
  /// Release builds never send it to the platform.
  final String? debugToken;

  /// Creates a configuration.
  const TrustPinAttestConfiguration({
    required this.verifierUrl,
    required this.attestedHosts,
    this.googleCloudProjectNumber,
    this.debugToken,
  });

  @override
  String toString() => 'TrustPinAttestConfiguration(verifierUrl: $verifierUrl, '
      'attestedHosts: $attestedHosts, '
      'googleCloudProjectNumber: $googleCloudProjectNumber, '
      'debugToken: ${debugToken == null ? 'null' : 'set'})';
}
