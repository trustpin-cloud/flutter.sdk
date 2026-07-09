package cloud.trustpin.flutter.sdk

import android.os.Handler
import android.os.Looper
import cloud.trustpin.kotlin.sdk.TrustPin
import cloud.trustpin.kotlin.sdk.TrustPinError
import cloud.trustpin.kotlin.sdk.TrustPinValidationListener
import io.flutter.plugin.common.EventChannel
import java.security.cert.X509Certificate

/**
 * Bridges the native SDK's global [TrustPinValidationListener] onto a Flutter
 * event channel.
 *
 * The native listener is installed when the first Dart subscription starts
 * ([onListen]) and removed when the last one cancels ([onCancel]) — the Dart
 * side multiplexes all of its listeners onto one channel subscription.
 *
 * Threading: verdict callbacks arrive synchronously from SDK internals,
 * including threads performing TLS handshakes, while the event sink must be
 * invoked on the platform main thread. Every event therefore hops through
 * [mainHandler]. The listener contract requires callbacks to stay fast and
 * non-blocking; a `post` satisfies that.
 */
internal class ValidationEventsStreamHandler : EventChannel.StreamHandler {

    // Lazy: `Looper.getMainLooper()` is unavailable in JVM unit tests, and
    // the handler is only needed once a verdict is actually delivered.
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        TrustPin.setValidationListener(object : TrustPinValidationListener {
            override fun onValidationFailure(
                instanceId: String,
                domain: String,
                error: TrustPinError,
                presentedCertificate: X509Certificate,
            ) {
                deliver(
                    events,
                    mapOf(
                        EventKey.INSTANCE_ID to instanceId,
                        EventKey.DOMAIN to domain,
                        EventKey.CODE to mapTrustPinError(error),
                        EventKey.MESSAGE to error.message,
                        EventKey.CERTIFICATE_PEM to
                            encodePemCertificate(presentedCertificate),
                    )
                )
            }

            override fun onValidationSuccess(instanceId: String, domain: String) {
                deliver(
                    events,
                    mapOf(
                        EventKey.INSTANCE_ID to instanceId,
                        EventKey.DOMAIN to domain,
                        // A null code marks a success event on the Dart side.
                        EventKey.CODE to null,
                    )
                )
            }
        })
    }

    override fun onCancel(arguments: Any?) {
        TrustPin.setValidationListener(null)
    }

    private fun deliver(events: EventChannel.EventSink, event: Map<String, Any?>) {
        mainHandler.post { events.success(event) }
    }
}
