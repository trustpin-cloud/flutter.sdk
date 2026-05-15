package cloud.trustpin.flutter.sdk

import cloud.trustpin.kotlin.sdk.TrustPin
import cloud.trustpin.kotlin.sdk.TrustPinConfiguration
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.withTimeout

internal fun TrustPinSDKPlugin.handleSetup(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.SETUP) {
        val organizationId = call.requireString(Arg.ORGANIZATION_ID)
        val projectId = call.requireString(Arg.PROJECT_ID)
        val publicKey = call.requireString(Arg.PUBLIC_KEY)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        val configurationURL = call.optionalURL(Arg.CONFIGURATION_URL)
        val mode = call.optionalString(Arg.MODE).toTrustPinMode()

        suspend {
            val configuration = TrustPinConfiguration(
                organizationId = organizationId,
                projectId = projectId,
                publicKey = publicKey,
                mode = mode,
                configurationURL = configurationURL
            )
            trustPinInstance(instanceId).setup(configuration)
            null
        }
    }
}

internal fun TrustPinSDKPlugin.handleVerify(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.VERIFY) {
        val domain = call.requireString(Arg.DOMAIN)
        val pem = call.requireString(Arg.CERTIFICATE)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        val certificate = parsePemCertificate(pem)

        suspend {
            trustPinInstance(instanceId).verify(domain, certificate)
            null
        }
    }
}

internal fun TrustPinSDKPlugin.handleSetLogLevel(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.SET_LOG_LEVEL) {
        val logLevel = call.requireString(Arg.LOG_LEVEL).toTrustPinLogLevel()
        val instanceId = call.optionalString(Arg.INSTANCE_ID)

        suspend {
            trustPinInstance(instanceId).setLogLevel(logLevel)
            null
        }
    }
}

internal fun TrustPinSDKPlugin.handleFetchCertificate(call: MethodCall, result: Result) {
    execute(
        coroutineScope,
        result,
        defaultCode = ErrorCode.FETCH_CERTIFICATE,
        timeoutMessage = "Timed out fetching certificate"
    ) {
        val host = call.requireString(Arg.HOST)
        val port = call.optionalInt(Arg.PORT) ?: DEFAULT_TLS_PORT
        val timeoutMs = call.optionalInt(Arg.TIMEOUT_MS)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)

        suspend {
            withOptionalTimeout(timeoutMs) {
                trustPinInstance(instanceId).fetchCertificate(host, port)
            }
        }
    }
}

internal fun TrustPinSDKPlugin.handleValidateConnection(call: MethodCall, result: Result) {
    execute(
        coroutineScope,
        result,
        defaultCode = ErrorCode.VALIDATE_CONNECTION,
        timeoutMessage = "Timed out validating connection"
    ) {
        val host = call.requireString(Arg.HOST)
        val port = call.optionalInt(Arg.PORT) ?: DEFAULT_TLS_PORT
        val timeoutMs = call.optionalInt(Arg.TIMEOUT_MS)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)

        suspend {
            withOptionalTimeout(timeoutMs) {
                val trustPin = trustPinInstance(instanceId)
                val pem = trustPin.fetchCertificate(host, port)
                trustPin.verify(host, parsePemCertificate(pem))
            }
            null
        }
    }
}

/**
 * Runs [block] directly, or under [withTimeout] when [timeoutMs] is positive.
 * Convenience wrapper used by handlers that expose `timeoutMs`.
 */
internal suspend fun <T> withOptionalTimeout(
    timeoutMs: Int?,
    block: suspend () -> T
): T = if (timeoutMs != null && timeoutMs > 0) {
    withTimeout(timeoutMs.toLong()) { block() }
} else {
    block()
}

/**
 * Returns the named TrustPin instance, or the default one when [id] is null
 * or empty.
 */
internal fun trustPinInstance(id: String?): TrustPin =
    if (id.isNullOrEmpty()) TrustPin.default else TrustPin.instance(id)
