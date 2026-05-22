package cloud.trustpin.flutter.sdk

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.BinaryMessenger.TaskQueue
import kotlin.test.Test
import kotlin.test.assertNull
import kotlin.test.assertSame
import org.mockito.Mockito.doReturn
import org.mockito.Mockito.mock

internal class TrustPinSDKPluginTest {

    @Test
    fun onAttachedToEngine_capturesApplicationContext() {
        val plugin = TrustPinSDKPlugin()
        val context = mock(Context::class.java)
        val binding = newBinding(context)

        plugin.onAttachedToEngine(binding)

        assertSame(
            context,
            plugin.applicationContext,
            "Plugin must capture the FlutterPluginBinding.applicationContext " +
                "so handleSetup can chain TrustPinConfiguration.withAndroidStorage(...)."
        )
    }

    @Test
    fun onDetachedFromEngine_clearsApplicationContext() {
        val plugin = TrustPinSDKPlugin()
        val context = mock(Context::class.java)
        val binding = newBinding(context)
        plugin.onAttachedToEngine(binding)

        plugin.onDetachedFromEngine(binding)

        assertNull(
            plugin.applicationContext,
            "Plugin must release the application Context on detach to avoid " +
                "outliving the FlutterEngine."
        )
    }

    private fun newBinding(context: Context): FlutterPlugin.FlutterPluginBinding {
        val messenger = mock(BinaryMessenger::class.java)
        val taskQueue = mock(TaskQueue::class.java)
        doReturn(taskQueue).`when`(messenger).makeBackgroundTaskQueue()
        val binding = mock(FlutterPlugin.FlutterPluginBinding::class.java)
        doReturn(context).`when`(binding).applicationContext
        doReturn(messenger).`when`(binding).binaryMessenger
        return binding
    }
}
