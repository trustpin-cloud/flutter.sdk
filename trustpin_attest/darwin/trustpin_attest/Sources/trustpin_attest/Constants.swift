import Foundation

/// Names of the Flutter method-channel calls handled by this plugin.
enum Method {
    static let setup = "setup"
    static let setupWithNativeBundle = "setupWithNativeBundle"
    static let prefetch = "prefetch"
    static let getToken = "getToken"
    static let attestationHeaders = "attestationHeaders"
    static let assertionHeaders = "assertionHeaders"
    static let setTokenBinding = "setTokenBinding"
    static let bindToHeader = "bindToHeader"
    static let state = "state"
    static let reset = "reset"
    static let setLogLevel = "setLogLevel"
}

/// Keys used in the method-call argument map. Keep in sync with the Dart side.
///
/// Both `iosFileName` and `macosFileName` are declared here because the Dart
/// side sends every per-platform key in one call; the native handler reads the
/// one matching the platform it was compiled for.
enum Arg {
    static let instanceId = "instanceId"
    static let verifierUrl = "verifierUrl"
    static let attestedHosts = "attestedHosts"
    static let debugToken = "debugToken"
    static let iosFileName = "iosFileName"
    static let macosFileName = "macosFileName"
    static let url = "url"
    static let method = "method"
    static let headers = "headers"
    static let payloadDigest = "payloadDigest"
    static let value = "value"
    static let name = "name"
    static let logLevel = "logLevel"
}

/// Keys of the state, event and log maps sent to Dart. Keep in sync with the Dart
/// side.
enum EventKey {
    static let instanceId = "instanceId"
    static let state = "state"
    static let expiresAtMs = "expiresAtMs"
    static let retryAtMs = "retryAtMs"
    static let code = "code"
    static let message = "message"
    static let reasons = "reasons"
    static let level = "level"
    static let event = "event"
    static let count = "count"
    static let durationMs = "durationMs"
    static let untilMs = "untilMs"
}

/// Error codes returned to Dart. Keep in sync with the Dart side.
enum ErrorCode {
    // Plugin-level codes.
    static let invalidArguments = "INVALID_ARGUMENTS"
    static let cancelled = "CANCELLED"
    static let attest = "ATTEST_ERROR"

    // Stable codes for `TrustPinAttestError` cases (see mapAttestError).
    static let invalidConfiguration = "INVALID_CONFIGURATION"
    static let alreadyInitialized = "ALREADY_INITIALIZED"
    static let notSetUp = "NOT_SET_UP"
    static let unsupportedDevice = "UNSUPPORTED_DEVICE"
    static let evidenceUnavailable = "EVIDENCE_UNAVAILABLE"
    static let bindingRequired = "BINDING_REQUIRED"
    static let attestationFailed = "ATTESTATION_FAILED"
    static let verifierUnavailable = "VERIFIER_UNAVAILABLE"
    static let verifierIncompatible = "VERIFIER_INCOMPATIBLE"
    static let invalidDigest = "INVALID_DIGEST"
}

/// The instance id events carry for `TrustPinAttest.default`.
let defaultInstanceId = "default"
