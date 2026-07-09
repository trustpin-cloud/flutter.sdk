package cloud.trustpin.flutter.sdk

import android.os.Handler
import android.os.Looper
import cloud.trustpin.kotlin.sdk.TrustPin
import cloud.trustpin.kotlin.sdk.TrustPinLogLevel
import cloud.trustpin.kotlin.sdk.TrustPinLogSink
import io.flutter.plugin.common.EventChannel

/**
 * Bridges the native SDK's global [TrustPinLogSink] onto a Flutter event
 * channel.
 *
 * The native sink is installed when the first Dart subscription starts
 * ([onListen]) and removed when the last one cancels ([onCancel]); while no
 * one listens the SDK keeps logging to its platform default (logcat). Per-
 * instance verbosity is still controlled by `TrustPin.setLogLevel` — the sink
 * only receives already-filtered messages.
 *
 * Threading: log messages arrive synchronously from SDK internals, including
 * threads performing TLS handshakes, while the event sink must be invoked on
 * the platform main thread. Every event therefore hops through [mainHandler].
 * The sink contract requires callbacks to stay fast and non-blocking; a
 * `post` satisfies that.
 */
internal class LogEventsStreamHandler : EventChannel.StreamHandler {

    // Lazy: `Looper.getMainLooper()` is unavailable in JVM unit tests, and
    // the handler is only needed once a message is actually delivered.
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        TrustPin.setLogSink { level, instanceId, message ->
            val event = mapOf(
                EventKey.LEVEL to level.toWireName(),
                EventKey.INSTANCE_ID to instanceId,
                EventKey.MESSAGE to message,
            )
            mainHandler.post { events.success(event) }
        }
    }

    override fun onCancel(arguments: Any?) {
        TrustPin.setLogSink(null)
    }
}

/**
 * The wire string for a log level. Keep in sync with the Dart
 * `TrustPinLogLevel.value` strings (`NONE` never reaches a sink — it only
 * configures filtering).
 */
private fun TrustPinLogLevel.toWireName(): String = when (this) {
    TrustPinLogLevel.ERROR -> "error"
    TrustPinLogLevel.INFO -> "info"
    TrustPinLogLevel.DEBUG -> "debug"
    TrustPinLogLevel.NONE -> "none"
}
