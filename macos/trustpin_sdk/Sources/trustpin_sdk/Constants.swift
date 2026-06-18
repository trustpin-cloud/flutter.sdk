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
    static let macosFileName = "macosFileName"
}

/// Error codes returned to Dart. Keep in sync with the Dart side.
enum ErrorCode {
    static let invalidArguments = "INVALID_ARGUMENTS"
    static let cancelled = "CANCELLED"
    static let setup = "SETUP_ERROR"
    static let verify = "VERIFY_ERROR"
    static let setLogLevel = "SET_LOG_LEVEL_ERROR"
    static let fetchCertificate = "FETCH_CERTIFICATE_ERROR"
    static let fetchCertificateTimeout = "FETCH_CERTIFICATE_TIMEOUT"
    static let validateConnection = "VALIDATE_CONNECTION_ERROR"
    static let awaitConfiguration = "AWAIT_CONFIGURATION_ERROR"
    static let alreadyInitialized = "ALREADY_INITIALIZED"
    static let configIntegrityFailed = "CONFIG_INTEGRITY_FAILED"
}

/// Default TCP port used when callers omit `port`.
let defaultTLSPort: Int = 443
