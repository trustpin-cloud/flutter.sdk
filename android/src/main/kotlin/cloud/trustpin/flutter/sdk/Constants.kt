package cloud.trustpin.flutter.sdk

/** Names of the Flutter method-channel calls handled by this plugin. */
internal object Method {
    const val SETUP = "setup"
    const val SETUP_FROM_BUNDLE = "setupWithNativeBundle"
    const val VERIFY = "verify"
    const val SET_LOG_LEVEL = "setLogLevel"
    const val FETCH_CERTIFICATE = "fetchCertificate"
    const val VALIDATE_CONNECTION = "validateConnection"
    const val AWAIT_CONFIGURATION = "awaitConfiguration"
    const val IS_CONFIGURATION_LOADED = "isConfigurationLoaded"
}

/** Keys used in the method-call argument map. Keep in sync with the Dart side. */
internal object Arg {
    const val ORGANIZATION_ID = "organizationId"
    const val PROJECT_ID = "projectId"
    const val PUBLIC_KEY = "publicKey"
    const val INSTANCE_ID = "instanceId"
    const val CONFIGURATION_URL = "configurationURL"
    const val MODE = "mode"
    const val DOMAIN = "domain"
    const val CERTIFICATE = "certificate"
    const val LOG_LEVEL = "logLevel"
    const val HOST = "host"
    const val PORT = "port"
    const val TIMEOUT_MS = "timeoutMs"
    const val ANDROID_FILE_NAME = "androidFileName"
    const val EMBEDDED_CONFIGURATION_FILE = "embeddedConfigurationFile"
}

/** Error codes returned to Dart. Keep in sync with the Dart side. */
internal object ErrorCode {
    // Plugin-level codes: argument parsing, cancellation, and the per-method
    // fallbacks for unclassified errors.
    const val INVALID_ARGUMENTS = "INVALID_ARGUMENTS"
    const val CANCELLED = "CANCELLED"
    const val SETUP = "SETUP_ERROR"
    const val VERIFY = "VERIFY_ERROR"
    const val SET_LOG_LEVEL = "SET_LOG_LEVEL_ERROR"
    const val FETCH_CERTIFICATE = "FETCH_CERTIFICATE_ERROR"
    const val VALIDATE_CONNECTION = "VALIDATE_CONNECTION_ERROR"
    const val AWAIT_CONFIGURATION = "AWAIT_CONFIGURATION_ERROR"

    // Stable codes for native SDK error cases (see mapTrustPinError).
    const val INVALID_PROJECT_CONFIG = "INVALID_PROJECT_CONFIG"
    const val ALREADY_INITIALIZED = "ALREADY_INITIALIZED"
    const val ERROR_FETCHING_PINNING_INFO = "ERROR_FETCHING_PINNING_INFO"
    const val INVALID_SERVER_CERT = "INVALID_SERVER_CERT"
    const val PINS_MISMATCH = "PINS_MISMATCH"
    const val ALL_PINS_EXPIRED = "ALL_PINS_EXPIRED"
    const val CONFIGURATION_VALIDATION_FAILED = "CONFIGURATION_VALIDATION_FAILED"
    const val DOMAIN_NOT_REGISTERED = "DOMAIN_NOT_REGISTERED"
    const val FETCH_CERTIFICATE_TIMEOUT = "FETCH_CERTIFICATE_TIMEOUT"
    const val CONFIG_INTEGRITY_FAILED = "CONFIG_INTEGRITY_FAILED"

    // Android-only codes: the iOS/macOS native SDK has no equivalent error
    // cases, so these are never produced on Apple platforms.
    const val SETUP_IN_PROGRESS = "SETUP_IN_PROGRESS"
    const val LOCK_TIMEOUT = "LOCK_TIMEOUT"
    const val SSL_CONTEXT_SETUP_FAILED = "SSL_CONTEXT_SETUP_FAILED"
    const val UNSUPPORTED_DEVICE = "UNSUPPORTED_DEVICE"
}

/** Keys of the validation- and log-event maps sent to Dart. Keep in sync with the Dart side. */
internal object EventKey {
    const val INSTANCE_ID = "instanceId"
    const val DOMAIN = "domain"
    const val CODE = "code"
    const val MESSAGE = "message"
    const val CERTIFICATE_PEM = "certificatePem"
    const val LEVEL = "level"
}

/** Default TCP port used when callers omit `port`. */
internal const val DEFAULT_TLS_PORT: Int = 443

/** Method-channel name shared by the platform interface. */
internal const val CHANNEL_NAME: String = "cloud.trustpin.sdk.flutter"

/** Event-channel name carrying pin-validation verdicts to Dart. */
internal const val VALIDATION_EVENTS_CHANNEL_NAME: String =
    CHANNEL_NAME + "/validation_events"

/** Event-channel name carrying SDK log messages to Dart. */
internal const val LOG_EVENTS_CHANNEL_NAME: String =
    CHANNEL_NAME + "/log_events"
