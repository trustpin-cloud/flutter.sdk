package cloud.trustpin.flutter.attest

import android.os.Handler
import android.os.Looper
import cloud.trustpin.kotlin.attest.TrustPinAttest
import io.flutter.plugin.common.EventChannel

/**
 * Bridges one kind of per-instance native callback (state changes or events)
 * of every instance this plugin set up onto one Flutter event channel.
 *
 * A native instance has a single state listener and a single event listener,
 * so the plugin owns them: they are registered when the instance is set up
 * and forward to the current Dart sink, or nowhere while no one listens. Dart
 * filters by instance id; native listeners don't replay, so Dart reads the
 * current state itself. Listeners are called on a background thread; every
 * map hops to the main thread.
 */
internal class InstanceEventsStreamHandler : EventChannel.StreamHandler {

    // Lazy: `Looper.getMainLooper()` is unavailable in JVM unit tests.
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    @Volatile
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /** Sends the map [build] returns, built only while Dart listens. */
    fun send(build: () -> Map<String, Any?>) {
        val events = sink ?: return
        val map = build()
        mainHandler.post { events.success(map) }
    }

    /** Drops the sink when the engine detaches. */
    fun detach() {
        sink = null
    }
}

/**
 * Bridges the module's process-wide log sink onto a Flutter event channel:
 * installed on the first Dart subscription, removed after the last cancels.
 */
internal class LogEventsStreamHandler : EventChannel.StreamHandler {

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        TrustPinAttest.setLogSink { level, instanceId, message ->
            val event = mapOf(
                EventKey.LEVEL to level.toWireName(),
                EventKey.INSTANCE_ID to instanceId,
                EventKey.MESSAGE to message,
            )
            mainHandler.post { events.success(event) }
        }
    }

    override fun onCancel(arguments: Any?) {
        TrustPinAttest.setLogSink(null)
    }
}
