package cloud.trustpin.flutter.attest

import android.content.Context
import cloud.trustpin.kotlin.attest.TrustPinAttest
import cloud.trustpin.kotlin.attest.TrustPinAttestConfiguration
import cloud.trustpin.kotlin.attest.TrustPinAttestError
import cloud.trustpin.kotlin.attest.fromAssets
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

internal fun TrustPinAttestPlugin.handleSetup(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val verifierUrl = call.requireString(Arg.VERIFIER_URL)
        val attestedHosts = call.stringList(Arg.ATTESTED_HOSTS)
        val projectNumber = call.optionalLong(Arg.GOOGLE_CLOUD_PROJECT_NUMBER)
        val debugToken = call.optionalString(Arg.DEBUG_TOKEN)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        val context = requireContext()

        suspend {
            // The constructor validates the values and throws
            // InvalidConfiguration when one is rejected.
            val configuration = TrustPinAttestConfiguration(
                verifierUrl, attestedHosts, projectNumber, debugToken,
            )
            setUp(context, configuration, instanceId)
            null
        }
    }
}

internal fun TrustPinAttestPlugin.handleSetupWithNativeBundle(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val fileName = call.optionalString(Arg.ANDROID_FILE_NAME)
        val debugToken = call.optionalString(Arg.DEBUG_TOKEN)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        val context = requireContext()

        suspend {
            // Without a filename the SDK reads its default, `trustpin.json`:
            // the file the pinning setup reads.
            val loaded = if (fileName == null) {
                TrustPinAttestConfiguration.fromAssets(context)
            } else {
                TrustPinAttestConfiguration.fromAssets(context, fileName)
            }
            // The asset loader never reads a debug token; it comes from the
            // build, through Dart. The SDK uses it only in debuggable apps.
            val configuration = if (debugToken == null) loaded else TrustPinAttestConfiguration(
                loaded.verifierUrl,
                loaded.attestedHosts,
                loaded.googleCloudProjectNumber,
                debugToken,
            )
            setUp(context, configuration, instanceId)
            null
        }
    }
}

internal fun TrustPinAttestPlugin.handlePrefetch(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend {
            attestInstance(instanceId).prefetch()
            null
        }
    }
}

internal fun TrustPinAttestPlugin.handleGetToken(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend { attestInstance(instanceId).getToken() }
    }
}

internal fun TrustPinAttestPlugin.handleAttestationHeaders(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val url = call.requireString(Arg.URL)
        val headers = call.headerLists(Arg.HEADERS)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend { attestInstance(instanceId).attestationHeaders(url, headers) }
    }
}

internal fun TrustPinAttestPlugin.handleAssertionHeaders(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val digest = call.requireBytes(Arg.PAYLOAD_DIGEST)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend { attestInstance(instanceId).assertionHeaders(digest) }
    }
}

internal fun TrustPinAttestPlugin.handleSetTokenBinding(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val value = call.nullableString(Arg.VALUE)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend {
            attestInstance(instanceId).setTokenBinding(value)
            null
        }
    }
}

internal fun TrustPinAttestPlugin.handleBindToHeader(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val name = call.optionalString(Arg.NAME)
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend {
            attestInstance(instanceId).bindToHeader(name)
            null
        }
    }
}

internal fun TrustPinAttestPlugin.handleState(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend {
            attestInstance(instanceId).state.toWireMap(instanceId ?: DEFAULT_INSTANCE_ID)
        }
    }
}

internal fun TrustPinAttestPlugin.handleReset(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend {
            try {
                attestInstance(instanceId).reset()
            } catch (_: TrustPinAttestError.NotSetUp) {
                // A no-op before setup, the contract Dart exposes on every
                // platform (the Swift SDK's behaviour).
            }
            null
        }
    }
}

internal fun TrustPinAttestPlugin.handleSetLogLevel(call: MethodCall, result: Result) {
    execute(coroutineScope, result) {
        val level = call.requireString(Arg.LOG_LEVEL).toAttestLogLevel()
        val instanceId = call.optionalString(Arg.INSTANCE_ID)
        suspend {
            attestInstance(instanceId).setLogLevel(level)
            null
        }
    }
}

/**
 * Forwards the instance's state changes and events to Dart, then sets it up.
 * The listeners come first so the events of setup itself reach Dart.
 */
private suspend fun TrustPinAttestPlugin.setUp(
    context: Context,
    configuration: TrustPinAttestConfiguration,
    instanceId: String?,
) {
    val attest = attestInstance(instanceId)
    val id = instanceId ?: DEFAULT_INSTANCE_ID
    attest.setStateListener { state -> stateEvents.send { state.toWireMap(id) } }
    attest.setEventListener { event -> events.send { event.toWireMap(id) } }
    attest.setup(context, configuration)
}

/**
 * The application context captured at engine attachment. Absent only if the
 * plugin was used before onAttachedToEngine ran.
 */
private fun TrustPinAttestPlugin.requireContext(): Context =
    applicationContext ?: throw TrustPinAttestError.InvalidConfiguration

/**
 * Returns the named instance, or the default one when [id] is null or empty.
 * An invalid id throws IllegalArgumentException (INVALID_CONFIGURATION).
 */
internal fun attestInstance(id: String?): TrustPinAttest =
    if (id.isNullOrEmpty()) TrustPinAttest.default else TrustPinAttest.instance(id)
