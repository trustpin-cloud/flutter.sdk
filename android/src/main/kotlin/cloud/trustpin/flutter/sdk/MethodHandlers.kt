package cloud.trustpin.flutter.sdk

import cloud.trustpin.kotlin.sdk.TrustPin
import cloud.trustpin.kotlin.sdk.TrustPinConfiguration
import cloud.trustpin.kotlin.sdk.TrustPinError
import cloud.trustpin.kotlin.sdk.fromAssets
import cloud.trustpin.kotlin.sdk.withAndroidStorage
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

internal fun TrustPinSDKPlugin.handleSetup(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.SETUP) {
        val organizationId = call.requireString(Arg.ORGANIZATION_ID)
        val projectId = call.requireString(Arg.PROJECT_ID)
        val publicKey = call.requireString(Arg.PUBLIC_KEY)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        val configurationURL = call.optionalURL(Arg.CONFIGURATION_URL)
        val mode = call.optionalString(Arg.MODE).toTrustPinMode()
        // Required by the native SDK 5.0.0+ `withAndroidStorage` hardening
        // chain. Absent only if the plugin was used before onAttachedToEngine
        // ran, which indicates a Flutter engine attachment bug.
        val context = applicationContext ?: throw TrustPinError.InvalidProjectConfig

        suspend {
            val configuration = TrustPinConfiguration(
                organizationId = organizationId,
                projectId = projectId,
                publicKey = publicKey,
                mode = mode,
                configurationURL = configurationURL
            ).withAndroidStorage(context)
            trustPinInstance(instanceId).setup(configuration)
            null
        }
    }
}

internal fun TrustPinSDKPlugin.handleSetupWithNativeBundle(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.SETUP) {
        val fileName = call.optionalString(Arg.ANDROID_FILE_NAME)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        val context = applicationContext ?: throw TrustPinError.InvalidProjectConfig

        suspend {
            // `fromAssets` chains `withAndroidStorage(context)` internally, so
            // no extra hardening step is required for this path. When the
            // caller passes no filename we let the native SDK pick its own
            // default (`trustpin.json`) instead of duplicating the constant.
            val configuration = if (fileName == null) {
                TrustPinConfiguration.fromAssets(context)
            } else {
                TrustPinConfiguration.fromAssets(context, fileName)
            }
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
    execute(coroutineScope, result, ErrorCode.FETCH_CERTIFICATE) {
        val host = call.requireString(Arg.HOST)
        val port = call.optionalInt(Arg.PORT) ?: DEFAULT_TLS_PORT
        val timeoutMs = call.optionalInt(Arg.TIMEOUT_MS)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)

        suspend {
            val trustPin = trustPinInstance(instanceId)
            // A null/non-positive timeout defers to the native SDK's default;
            // the SDK raises TrustPinError.Timeout when the bound is exceeded.
            if (timeoutMs != null && timeoutMs > 0) {
                trustPin.fetchCertificate(host, port, timeoutMs.toLong())
            } else {
                trustPin.fetchCertificate(host, port)
            }
        }
    }
}

internal fun TrustPinSDKPlugin.handleValidateConnection(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.VALIDATE_CONNECTION) {
        val host = call.requireString(Arg.HOST)
        val port = call.optionalInt(Arg.PORT) ?: DEFAULT_TLS_PORT
        val timeoutMs = call.optionalInt(Arg.TIMEOUT_MS)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)

        suspend {
            val trustPin = trustPinInstance(instanceId)
            if (timeoutMs != null && timeoutMs > 0) {
                // The caller's timeout bounds the composed operation. The
                // native API takes one bound per call, so the verify phase
                // gets whatever the fetch phase left of the budget.
                val start = System.nanoTime()
                val pem = trustPin.fetchCertificate(host, port, timeoutMs.toLong())
                val elapsedMs = (System.nanoTime() - start) / 1_000_000
                val remainingMs = timeoutMs - elapsedMs
                if (remainingMs <= 0) throw TrustPinError.Timeout
                trustPin.verify(host, parsePemCertificate(pem), remainingMs)
            } else {
                val pem = trustPin.fetchCertificate(host, port)
                trustPin.verify(host, parsePemCertificate(pem))
            }
            null
        }
    }
}

internal fun TrustPinSDKPlugin.handleAwaitConfiguration(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.AWAIT_CONFIGURATION) {
        val timeoutMs = call.optionalInt(Arg.TIMEOUT_MS)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)

        suspend {
            val trustPin = trustPinInstance(instanceId)
            // The native API takes a millisecond deadline. A null/non-positive
            // value defers to the SDK's default timeout.
            if (timeoutMs != null && timeoutMs > 0) {
                trustPin.awaitConfiguration(timeoutMs.toLong())
            } else {
                trustPin.awaitConfiguration()
            }
            null
        }
    }
}

internal fun TrustPinSDKPlugin.handleIsConfigurationLoaded(call: MethodCall, result: Result) {
    execute(coroutineScope, result, ErrorCode.AWAIT_CONFIGURATION) {
        val instanceId = call.optionalString(Arg.INSTANCE_ID)

        suspend {
            trustPinInstance(instanceId).isConfigurationLoaded
        }
    }
}

/**
 * Returns the named TrustPin instance, or the default one when [id] is null
 * or empty.
 */
internal fun trustPinInstance(id: String?): TrustPin =
    if (id.isNullOrEmpty()) TrustPin.default else TrustPin.instance(id)
