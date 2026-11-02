package cloud.trustpin.flutter.attest

import cloud.trustpin.kotlin.attest.TrustPinAttestError
import cloud.trustpin.kotlin.attest.TrustPinAttestEvent
import cloud.trustpin.kotlin.attest.TrustPinAttestLogLevel
import cloud.trustpin.kotlin.attest.TrustPinAttestState

/** A retry time at least this far away is sent to Dart as "no retry". */
private const val NO_RETRY_THRESHOLD_MS: Long = 365L * 24 * 3600 * 1000

/**
 * Translates a [TrustPinAttestError] case into the stable string code sent
 * to Dart.
 */
internal fun mapAttestError(error: TrustPinAttestError): String = when (error) {
    is TrustPinAttestError.InvalidConfiguration -> ErrorCode.INVALID_CONFIGURATION
    is TrustPinAttestError.AlreadyInitialized -> ErrorCode.ALREADY_INITIALIZED
    is TrustPinAttestError.NotSetUp -> ErrorCode.NOT_SET_UP
    is TrustPinAttestError.UnsupportedDevice -> ErrorCode.UNSUPPORTED_DEVICE
    is TrustPinAttestError.EvidenceUnavailable -> ErrorCode.EVIDENCE_UNAVAILABLE
    is TrustPinAttestError.BindingRequired -> ErrorCode.BINDING_REQUIRED
    is TrustPinAttestError.AttestationFailed -> ErrorCode.ATTESTATION_FAILED
    is TrustPinAttestError.VerifierUnavailable -> ErrorCode.VERIFIER_UNAVAILABLE
    is TrustPinAttestError.VerifierIncompatible -> ErrorCode.VERIFIER_INCOMPATIBLE
    is TrustPinAttestError.InvalidDigest -> ErrorCode.INVALID_DIGEST
}

/** The reasons an `AttestationFailed` error carries; empty for other cases. */
internal fun TrustPinAttestError.reasonList(): List<String> =
    (this as? TrustPinAttestError.AttestationFailed)?.reasons ?: emptyList()

/** The map sent to Dart for this state, tagged with [instanceId]. */
internal fun TrustPinAttestState.toWireMap(
    instanceId: String,
    nowMillis: Long = System.currentTimeMillis(),
): Map<String, Any?> = when (this) {
    is TrustPinAttestState.Unavailable -> mapOf(
        EventKey.INSTANCE_ID to instanceId,
        EventKey.STATE to "unavailable",
    )
    is TrustPinAttestState.Attesting -> mapOf(
        EventKey.INSTANCE_ID to instanceId,
        EventKey.STATE to "attesting",
    )
    is TrustPinAttestState.Ready -> mapOf(
        EventKey.INSTANCE_ID to instanceId,
        EventKey.STATE to "ready",
        EventKey.EXPIRES_AT_MS to expiresAtMillis,
    )
    is TrustPinAttestState.Failed -> mapOf(
        EventKey.INSTANCE_ID to instanceId,
        EventKey.STATE to "failed",
        EventKey.CODE to mapAttestError(error),
        EventKey.MESSAGE to error.message,
        EventKey.REASONS to error.reasonList(),
        EventKey.RETRY_AT_MS to retryTime(retryAtMillis, nowMillis),
    )
}

/**
 * The map sent to Dart for this event, tagged with [instanceId]: the event's
 * name and its own fields, nothing else.
 */
internal fun TrustPinAttestEvent.toWireMap(
    instanceId: String,
    nowMillis: Long = System.currentTimeMillis(),
): Map<String, Any?> {
    val fields: Map<String, Any?> = when (this) {
        is TrustPinAttestEvent.KeyGenerated -> mapOf(EventKey.EVENT to "keyGenerated")
        is TrustPinAttestEvent.KeyReplaced -> mapOf(EventKey.EVENT to "keyReplaced", EventKey.COUNT to count)
        is TrustPinAttestEvent.AttestationSucceeded ->
            mapOf(EventKey.EVENT to "attestationSucceeded", EventKey.DURATION_MS to durationMillis)
        is TrustPinAttestEvent.Refused ->
            mapOf(EventKey.EVENT to "refused", EventKey.RETRY_AT_MS to retryTime(retryAtMillis, nowMillis))
        is TrustPinAttestEvent.AttestationFailed -> mapOf(
            EventKey.EVENT to "attestationFailed",
            EventKey.REASONS to reasons,
            EventKey.RETRY_AT_MS to retryTime(retryAtMillis, nowMillis),
        )
        is TrustPinAttestEvent.RefreshSucceeded ->
            mapOf(EventKey.EVENT to "refreshSucceeded", EventKey.DURATION_MS to durationMillis)
        is TrustPinAttestEvent.RefreshFailed -> error.toWireFields("refreshFailed")
        is TrustPinAttestEvent.WaitEntered -> mapOf(EventKey.EVENT to "waitEntered", EventKey.UNTIL_MS to untilMillis)
        is TrustPinAttestEvent.WaitCleared -> mapOf(EventKey.EVENT to "waitCleared")
        is TrustPinAttestEvent.DeviceUnsupported -> mapOf(EventKey.EVENT to "deviceUnsupported")
        is TrustPinAttestEvent.VerifierUnavailable -> mapOf(EventKey.EVENT to "verifierUnavailable")
        is TrustPinAttestEvent.AssertionSucceeded ->
            mapOf(EventKey.EVENT to "assertionSucceeded", EventKey.DURATION_MS to durationMillis)
        is TrustPinAttestEvent.AssertionFailed -> error.toWireFields("assertionFailed")
    }
    return mapOf(EventKey.INSTANCE_ID to instanceId) + fields
}

private fun TrustPinAttestError.toWireFields(event: String): Map<String, Any?> = mapOf(
    EventKey.EVENT to event,
    EventKey.CODE to mapAttestError(this),
    EventKey.MESSAGE to message,
    EventKey.REASONS to reasonList(),
)

/** Long.MAX_VALUE means no new attempt in this process; Dart gets null. */
private fun retryTime(retryAtMillis: Long, nowMillis: Long): Long? =
    retryAtMillis.takeIf { it - nowMillis < NO_RETRY_THRESHOLD_MS }

/** Maps the Dart-side string to a log level; unknown values turn logging off. */
internal fun String?.toAttestLogLevel(): TrustPinAttestLogLevel = when (this?.lowercase()) {
    "error" -> TrustPinAttestLogLevel.ERROR
    "warning" -> TrustPinAttestLogLevel.WARNING
    "info" -> TrustPinAttestLogLevel.INFO
    "debug" -> TrustPinAttestLogLevel.DEBUG
    else -> TrustPinAttestLogLevel.NONE
}

/** The wire string for a log level. Keep in sync with the Dart enum values. */
internal fun TrustPinAttestLogLevel.toWireName(): String = when (this) {
    TrustPinAttestLogLevel.NONE -> "none"
    TrustPinAttestLogLevel.ERROR -> "error"
    TrustPinAttestLogLevel.WARNING -> "warning"
    TrustPinAttestLogLevel.INFO -> "info"
    TrustPinAttestLogLevel.DEBUG -> "debug"
}
