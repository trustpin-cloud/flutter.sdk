package cloud.trustpin.flutter.sdk

/** Names of the Flutter method-channel calls handled by this plugin. */
internal object Method {
    const val SETUP = "setup"
    const val SETUP_FROM_BUNDLE = "setupWithNativeBundle"
    const val VERIFY = "verify"
    const val SET_LOG_LEVEL = "setLogLevel"
    const val FETCH_CERTIFICATE = "fetchCertificate"
    const val VALIDATE_CONNECTION = "validateConnection"
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
}

/** Error codes returned to Dart. Keep in sync with the Dart side. */
internal object ErrorCode {
    const val INVALID_ARGUMENTS = "INVALID_ARGUMENTS"
    const val CANCELLED = "CANCELLED"
    const val SETUP = "SETUP_ERROR"
    const val VERIFY = "VERIFY_ERROR"
    const val SET_LOG_LEVEL = "SET_LOG_LEVEL_ERROR"
    const val FETCH_CERTIFICATE = "FETCH_CERTIFICATE_ERROR"
    const val FETCH_CERTIFICATE_TIMEOUT = "FETCH_CERTIFICATE_TIMEOUT"
    const val VALIDATE_CONNECTION = "VALIDATE_CONNECTION_ERROR"
}

/** Default TCP port used when callers omit `port`. */
internal const val DEFAULT_TLS_PORT: Int = 443

/** Method-channel name shared by the platform interface. */
internal const val CHANNEL_NAME: String = "cloud.trustpin.sdk.flutter"
