package cloud.trustpin.flutter.sdk

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
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
 * Flutter method-channel entry point. All handler logic lives in
 * `MethodHandlers.kt`; this file owns only the registration and the
 * method-name dispatch.
 *
 * The channel is registered with a background TaskQueue, so call handlers and
 * result callbacks run off the platform thread. The coroutine scope is anchored
 * on [Dispatchers.Default]; no thread-bouncing per call.
 */
class TrustPinSDKPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel

    internal val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /**
     * Application Context captured at engine attachment. Required by the
     * native SDK's `withAndroidStorage(context)` hardening chain, which must
     * be applied to every [cloud.trustpin.kotlin.sdk.TrustPinConfiguration]
     * passed to `setup` on Android.
     */
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
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            Method.SETUP -> handleSetup(call, result)
            Method.SETUP_FROM_BUNDLE -> handleSetupWithNativeBundle(call, result)
            Method.VERIFY -> handleVerify(call, result)
            Method.SET_LOG_LEVEL -> handleSetLogLevel(call, result)
            Method.FETCH_CERTIFICATE -> handleFetchCertificate(call, result)
            Method.VALIDATE_CONNECTION -> handleValidateConnection(call, result)
            Method.AWAIT_CONFIGURATION -> handleAwaitConfiguration(call, result)
            Method.IS_CONFIGURATION_LOADED -> handleIsConfigurationLoaded(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        coroutineScope.cancel()
        applicationContext = null
    }
}
