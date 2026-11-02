package cloud.trustpin.flutter.attest

import android.content.Context
import cloud.trustpin.kotlin.attest.TrustPinAttest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMethodCodec
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * Flutter method-channel entry point of the attestation plugin. All handler
 * logic lives in `MethodHandlers.kt`; this file owns only the registration
 * and the method-name dispatch.
 *
 * The channel is registered with a background TaskQueue, so call handlers and
 * result callbacks run off the platform thread.
 */
class TrustPinAttestPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var stateEventsChannel: EventChannel
    private lateinit var eventsChannel: EventChannel
    private lateinit var logEventsChannel: EventChannel

    internal val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    internal val stateEvents = InstanceEventsStreamHandler()

    internal val events = InstanceEventsStreamHandler()

    /** Application context captured at engine attachment, needed by setup. */
    internal var applicationContext: Context? = null
        private set

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        val messenger = binding.binaryMessenger
        channel = MethodChannel(
            messenger,
            CHANNEL_NAME,
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        )
        channel.setMethodCallHandler(this)

        stateEventsChannel = EventChannel(messenger, STATE_EVENTS_CHANNEL_NAME)
        stateEventsChannel.setStreamHandler(stateEvents)

        eventsChannel = EventChannel(messenger, EVENTS_CHANNEL_NAME)
        eventsChannel.setStreamHandler(events)

        logEventsChannel = EventChannel(messenger, LOG_EVENTS_CHANNEL_NAME)
        logEventsChannel.setStreamHandler(LogEventsStreamHandler())
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            Method.SETUP -> handleSetup(call, result)
            Method.SETUP_FROM_BUNDLE -> handleSetupWithNativeBundle(call, result)
            Method.PREFETCH -> handlePrefetch(call, result)
            Method.GET_TOKEN -> handleGetToken(call, result)
            Method.ATTESTATION_HEADERS -> handleAttestationHeaders(call, result)
            Method.ASSERTION_HEADERS -> handleAssertionHeaders(call, result)
            Method.SET_TOKEN_BINDING -> handleSetTokenBinding(call, result)
            Method.BIND_TO_HEADER -> handleBindToHeader(call, result)
            Method.STATE -> handleState(call, result)
            Method.RESET -> handleReset(call, result)
            Method.SET_LOG_LEVEL -> handleSetLogLevel(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stateEventsChannel.setStreamHandler(null)
        eventsChannel.setStreamHandler(null)
        logEventsChannel.setStreamHandler(null)
        // The engine goes away without a Dart-side cancel; drop the global
        // log sink so it cannot outlive the channel it feeds. The state and
        // event listeners stay registered (one each per instance, owned by
        // the plugin) but have no sink to forward to.
        TrustPinAttest.setLogSink(null)
        stateEvents.detach()
        events.detach()
        coroutineScope.cancel()
        applicationContext = null
    }
}
