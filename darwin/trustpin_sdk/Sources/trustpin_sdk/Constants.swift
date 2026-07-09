import Foundation

/// Names of the Flutter method-channel calls handled by this plugin.
enum Method {
    static let setup = "setup"
    static let setupWithNativeBundle = "setupWithNativeBundle"
    static let verify = "verify"
    static let setLogLevel = "setLogLevel"
    static let fetchCertificate = "fetchCertificate"
    static let validateConnection = "validateConnection"
    static let awaitConfiguration = "awaitConfiguration"
    static let isConfigurationLoaded = "isConfigurationLoaded"
}

/// Keys used in the method-call argument map. Keep in sync with the Dart side.
///
/// Both `iosFileName` and `macosFileName` are declared here because the Dart
/// side sends every per-platform key in one call; the native handler reads the
/// one matching the platform it was compiled for (see `handleSetupWithNativeBundle`).
enum Arg {
    static let organizationId = "organizationId"
    static let projectId = "projectId"
    static let publicKey = "publicKey"
    static let instanceId = "instanceId"
    static let configurationURL = "configurationURL"
    static let mode = "mode"
    static let domain = "domain"
    static let certificate = "certificate"
    static let logLevel = "logLevel"
    static let host = "host"
    static let port = "port"
    static let timeoutMs = "timeoutMs"
    static let iosFileName = "iosFileName"
    static let macosFileName = "macosFileName"
}

/// Keys of the validation- and log-event maps sent to Dart. Keep in sync
/// with the Dart side.
enum EventKey {
    static let instanceId = "instanceId"
    static let domain = "domain"
    static let code = "code"
    static let message = "message"
    static let certificatePem = "certificatePem"
    static let level = "level"
}

/// Error codes returned to Dart. Keep in sync with the Dart side.
enum ErrorCode {
    // Plugin-level codes: argument parsing, cancellation, and the per-method
    // fallbacks for unclassified errors.
    static let invalidArguments = "INVALID_ARGUMENTS"
    static let cancelled = "CANCELLED"
    static let setup = "SETUP_ERROR"
    static let verify = "VERIFY_ERROR"
    static let setLogLevel = "SET_LOG_LEVEL_ERROR"
    static let fetchCertificate = "FETCH_CERTIFICATE_ERROR"
    static let validateConnection = "VALIDATE_CONNECTION_ERROR"
    static let awaitConfiguration = "AWAIT_CONFIGURATION_ERROR"

    // Stable codes for native SDK error cases (see mapTrustPinError).
    static let invalidProjectConfig = "INVALID_PROJECT_CONFIG"
    static let alreadyInitialized = "ALREADY_INITIALIZED"
    static let errorFetchingPinningInfo = "ERROR_FETCHING_PINNING_INFO"
    static let invalidServerCert = "INVALID_SERVER_CERT"
    static let pinsMismatch = "PINS_MISMATCH"
    static let allPinsExpired = "ALL_PINS_EXPIRED"
    static let configurationValidationFailed = "CONFIGURATION_VALIDATION_FAILED"
    static let domainNotRegistered = "DOMAIN_NOT_REGISTERED"
    static let fetchCertificateTimeout = "FETCH_CERTIFICATE_TIMEOUT"
    static let configIntegrityFailed = "CONFIG_INTEGRITY_FAILED"
}

/// Default TCP port used when callers omit `port`.
let defaultTLSPort: Int = 443
