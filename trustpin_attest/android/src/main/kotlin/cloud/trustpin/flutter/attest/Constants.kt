package cloud.trustpin.flutter.attest

/** Names of the Flutter method-channel calls handled by this plugin. */
internal object Method {
    const val SETUP = "setup"
    const val SETUP_FROM_BUNDLE = "setupWithNativeBundle"
    const val PREFETCH = "prefetch"
    const val GET_TOKEN = "getToken"
    const val ATTESTATION_HEADERS = "attestationHeaders"
    const val ASSERTION_HEADERS = "assertionHeaders"
    const val SET_TOKEN_BINDING = "setTokenBinding"
    const val BIND_TO_HEADER = "bindToHeader"
    const val STATE = "state"
    const val RESET = "reset"
    const val SET_LOG_LEVEL = "setLogLevel"
}

/** Keys used in the method-call argument map. Keep in sync with the Dart side. */
internal object Arg {
    const val INSTANCE_ID = "instanceId"
    const val VERIFIER_URL = "verifierUrl"
    const val ATTESTED_HOSTS = "attestedHosts"
    const val GOOGLE_CLOUD_PROJECT_NUMBER = "googleCloudProjectNumber"
    const val DEBUG_TOKEN = "debugToken"
    const val ANDROID_FILE_NAME = "androidFileName"
    const val URL = "url"
    const val HEADERS = "headers"
    const val PAYLOAD_DIGEST = "payloadDigest"
    const val VALUE = "value"
    const val NAME = "name"
    const val LOG_LEVEL = "logLevel"
}

/** Keys of the state, event and log maps sent to Dart. Keep in sync with the Dart side. */
internal object EventKey {
    const val INSTANCE_ID = "instanceId"
    const val STATE = "state"
    const val EXPIRES_AT_MS = "expiresAtMs"
    const val RETRY_AT_MS = "retryAtMs"
    const val CODE = "code"
    const val MESSAGE = "message"
    const val REASONS = "reasons"
    const val LEVEL = "level"
    const val EVENT = "event"
    const val COUNT = "count"
    const val DURATION_MS = "durationMs"
    const val UNTIL_MS = "untilMs"
}

/** Error codes returned to Dart. Keep in sync with the Dart side. */
internal object ErrorCode {
    // Plugin-level codes.
    const val INVALID_ARGUMENTS = "INVALID_ARGUMENTS"
    const val CANCELLED = "CANCELLED"
    const val ATTEST = "ATTEST_ERROR"

    // Stable codes for TrustPinAttestError cases (see mapAttestError).
    const val INVALID_CONFIGURATION = "INVALID_CONFIGURATION"
    const val ALREADY_INITIALIZED = "ALREADY_INITIALIZED"
    const val NOT_SET_UP = "NOT_SET_UP"
    const val UNSUPPORTED_DEVICE = "UNSUPPORTED_DEVICE"
    const val EVIDENCE_UNAVAILABLE = "EVIDENCE_UNAVAILABLE"
    const val BINDING_REQUIRED = "BINDING_REQUIRED"
    const val ATTESTATION_FAILED = "ATTESTATION_FAILED"
    const val VERIFIER_UNAVAILABLE = "VERIFIER_UNAVAILABLE"
    const val VERIFIER_INCOMPATIBLE = "VERIFIER_INCOMPATIBLE"
    const val INVALID_DIGEST = "INVALID_DIGEST"
}

/** The instance id events carry for `TrustPinAttest.default`. */
internal const val DEFAULT_INSTANCE_ID: String = "default"

/** Method-channel name shared with the Dart side. */
internal const val CHANNEL_NAME: String = "cloud.trustpin.attest.flutter"

/** Event-channel name carrying the state changes of every instance. */
internal const val STATE_EVENTS_CHANNEL_NAME: String = CHANNEL_NAME + "/state_events"

/** Event-channel name carrying the events of every instance. */
internal const val EVENTS_CHANNEL_NAME: String = CHANNEL_NAME + "/events"

/** Event-channel name carrying the module's log messages. */
internal const val LOG_EVENTS_CHANNEL_NAME: String = CHANNEL_NAME + "/log_events"
