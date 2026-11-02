import 'package:trustpin_attest/trustpin_attest.dart';

import '../model/attestation_status.dart';

/// Boundary between the use cases and TrustPinAttest plus the sample API.
///
/// The contract the sample demonstrates:
/// - setup reads `TrustPin-Info.plist` / `trustpin.json`, binds tokens to the
///   `Authorization` header and prefetches a token;
/// - the protected call signs in to the sample API once (`POST /login`), then
///   calls `GET /home` with the bearer token, through `TrustPinHttpClient`,
///   which adds the attestation header for the attested hosts;
/// - the sensitive call posts `POST /transfer` with the token and an
///   assertion over the body's SHA-256, which the API checks with the
///   verifier;
/// - signing out drops the session, so the next call signs in again and the
///   token is renewed for the new `Authorization` value with the same key;
/// - reset discards the device key, so the next call attests a new one.
abstract interface class AttestationRepository {
  /// Whether [setUp] has completed for this process.
  bool isConfigured();

  /// The SDK state: the current one first, then every change.
  Stream<TrustPinAttestState> get states;

  /// The SDK's structured events, from now on.
  Stream<TrustPinAttestEvent> get events;

  Future<void> setUp();

  Future<ProtectedCallOutcome> callProtectedEndpoint();

  Future<ProtectedCallOutcome> callSensitiveEndpoint();

  void signOut();

  Future<void> reset();
}
