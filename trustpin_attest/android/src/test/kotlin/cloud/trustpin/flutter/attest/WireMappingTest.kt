package cloud.trustpin.flutter.attest

import cloud.trustpin.kotlin.attest.TrustPinAttestError
import cloud.trustpin.kotlin.attest.TrustPinAttestEvent
import cloud.trustpin.kotlin.attest.TrustPinAttestLogLevel
import cloud.trustpin.kotlin.attest.TrustPinAttestState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class WireMappingTest {

    private val now = 1_800_000_000_000L

    @Test
    fun `ready carries the expiry`() {
        val map = TrustPinAttestState.Ready(now + 60_000).toWireMap("default", now)

        assertEquals("ready", map[EventKey.STATE])
        assertEquals(now + 60_000, map[EventKey.EXPIRES_AT_MS])
        assertEquals("default", map[EventKey.INSTANCE_ID])
    }

    @Test
    fun `failed carries code, reasons and retry time`() {
        val state = TrustPinAttestState.Failed(
            TrustPinAttestError.AttestationFailed(listOf("app_not_allowed")),
            now + 30_000,
        )

        val map = state.toWireMap("lib", now)

        assertEquals("failed", map[EventKey.STATE])
        assertEquals(ErrorCode.ATTESTATION_FAILED, map[EventKey.CODE])
        assertEquals(listOf("app_not_allowed"), map[EventKey.REASONS])
        assertEquals(now + 30_000, map[EventKey.RETRY_AT_MS])
        assertEquals("lib", map[EventKey.INSTANCE_ID])
    }

    @Test
    fun `no retry in this process is sent as null`() {
        val state = TrustPinAttestState.Failed(TrustPinAttestError.BindingRequired, Long.MAX_VALUE)

        val map = state.toWireMap("default", now)

        assertEquals(ErrorCode.BINDING_REQUIRED, map[EventKey.CODE])
        assertEquals(emptyList<String>(), map[EventKey.REASONS])
        assertNull(map[EventKey.RETRY_AT_MS])
    }

    @Test
    fun `every error case has a stable code`() {
        val codes = listOf(
            TrustPinAttestError.InvalidConfiguration,
            TrustPinAttestError.AlreadyInitialized,
            TrustPinAttestError.NotSetUp,
            TrustPinAttestError.UnsupportedDevice,
            TrustPinAttestError.EvidenceUnavailable,
            TrustPinAttestError.BindingRequired,
            TrustPinAttestError.AttestationFailed(emptyList()),
            TrustPinAttestError.VerifierUnavailable,
            TrustPinAttestError.VerifierIncompatible,
            TrustPinAttestError.InvalidDigest,
        ).map(::mapAttestError)

        assertEquals(
            listOf(
                "INVALID_CONFIGURATION", "ALREADY_INITIALIZED", "NOT_SET_UP",
                "UNSUPPORTED_DEVICE", "EVIDENCE_UNAVAILABLE", "BINDING_REQUIRED",
                "ATTESTATION_FAILED", "VERIFIER_UNAVAILABLE", "VERIFIER_INCOMPATIBLE",
                "INVALID_DIGEST",
            ),
            codes,
        )
    }

    @Test
    fun `events carry their name and fields`() {
        assertEquals(
            mapOf(EventKey.INSTANCE_ID to "default", EventKey.EVENT to "keyReplaced", EventKey.COUNT to 2),
            TrustPinAttestEvent.KeyReplaced(2).toWireMap("default", now),
        )
        assertEquals(
            mapOf(EventKey.INSTANCE_ID to "lib", EventKey.EVENT to "attestationSucceeded", EventKey.DURATION_MS to 850L),
            TrustPinAttestEvent.AttestationSucceeded(850).toWireMap("lib", now),
        )
        assertEquals(
            mapOf(EventKey.INSTANCE_ID to "default", EventKey.EVENT to "waitEntered", EventKey.UNTIL_MS to now + 600_000),
            TrustPinAttestEvent.WaitEntered(now + 600_000).toWireMap("default", now),
        )
        val failed = TrustPinAttestEvent.AttestationFailed(listOf("app_not_allowed"), now + 600_000).toWireMap("default", now)
        assertEquals("attestationFailed", failed[EventKey.EVENT])
        assertEquals(listOf("app_not_allowed"), failed[EventKey.REASONS])
        assertEquals(now + 600_000, failed[EventKey.RETRY_AT_MS])
        val refreshFailed = TrustPinAttestEvent.RefreshFailed(TrustPinAttestError.VerifierIncompatible).toWireMap("default", now)
        assertEquals("refreshFailed", refreshFailed[EventKey.EVENT])
        assertEquals(ErrorCode.VERIFIER_INCOMPATIBLE, refreshFailed[EventKey.CODE])
    }

    @Test
    fun `an event with no retry in this process is sent as null`() {
        val map = TrustPinAttestEvent.Refused(Long.MAX_VALUE).toWireMap("default", now)

        assertEquals("refused", map[EventKey.EVENT])
        assertTrue(map.containsKey(EventKey.RETRY_AT_MS))
        assertNull(map[EventKey.RETRY_AT_MS])
    }

    @Test
    fun `log levels round-trip and unknown turns logging off`() {
        for (level in TrustPinAttestLogLevel.entries) {
            assertEquals(level, level.toWireName().toAttestLogLevel())
        }
        assertEquals(TrustPinAttestLogLevel.NONE, "verbose".toAttestLogLevel())
    }
}
