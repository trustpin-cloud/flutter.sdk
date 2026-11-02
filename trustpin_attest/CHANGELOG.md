# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [7.1.0] - 2026-11-02

### Added

- First release: TrustPin app attestation for Flutter on iOS, macOS and
  Android, a thin wrapper of the native attestation modules 7.1.x
  (`TrustPinAttestKit`, `cloud.trustpin:kotlin-attest`). Requires Flutter
  3.44.0 or later, and a verifier at contract version 2 or newer (verifier
  0.2.2 or later); iOS and macOS use Swift Package Manager only.
- `TrustPinAttest.shared` and `TrustPinAttest.instance(id)`, paired with the
  `trustpin_sdk` pinning instances: `setup`, `setupWithNativeBundle`,
  `prefetch`, `getToken`, `attestationHeaders`, `bindToHeader`,
  `setTokenBinding`, `state`, `stateChanges`, `reset`, `setLogLevel` and
  `TrustPinAttest.logs`.
- `assertionHeaders(payloadDigest)` and `TrustPinAttest.assertionHeaderName`:
  the token and an assertion for one sensitive operation, bound to a digest of
  your choice and checked by your verifier.
- `events`: structured events for monitoring (`TrustPinAttestEvent`), with
  durations, waits, counts and reasons, never a token, key or device
  identifier.
- Error codes `VERIFIER_INCOMPATIBLE` (the verifier is too old) and
  `INVALID_DIGEST`.
- Once set up, `trustpin_sdk`'s `TrustPinHttpClient` and
  `TrustPinDioInterceptor` add the `TrustPin-Attestation` header to HTTPS
  requests for the attested hosts.
- Debug tokens from the build (`TrustPinAttestConfiguration.debugToken`), used
  on the iOS simulator and in debuggable Android builds, never sent in release
  builds.
