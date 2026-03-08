package cloud.trustpin.flutter.sdk

import cloud.trustpin.kotlin.sdk.TrustPin
import cloud.trustpin.kotlin.sdk.TrustPinConfiguration
import cloud.trustpin.kotlin.sdk.TrustPinError
import cloud.trustpin.kotlin.sdk.TrustPinLogLevel
import cloud.trustpin.kotlin.sdk.TrustPinMode

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.io.ByteArrayInputStream
import java.util.Base64
import java.net.URI
import java.net.URL

/** TrustPinSDKPlugin */
class TrustPinSDKPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel

  // Use SupervisorJob for proper lifecycle management and cancellation
  private val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cloud.trustpin.sdk.flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "setup" -> handleSetup(call, result)
      "verify" -> handleVerify(call, result)
      "setLogLevel" -> handleSetLogLevel(call, result)
      "fetchCertificate" -> handleFetchCertificate(call, result)
      else -> result.notImplemented()
    }
  }

  private fun handleSetup(call: MethodCall, result: Result) {
    coroutineScope.launch {
      try {
        val organizationId = call.argument<String>("organizationId")
        val projectId = call.argument<String>("projectId")
        val publicKey = call.argument<String>("publicKey")
        val instanceId = call.argument<String>("instanceId")
        val configurationURL = call.argument<String>("configurationURL")
        val modeString = call.argument<String>("mode") ?: "strict"

        if (organizationId == null || projectId == null || publicKey == null) {
          result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
          return@launch
        }

        val mode = when (modeString.lowercase()) {
          "permissive" -> TrustPinMode.PERMISSIVE
          "strict" -> TrustPinMode.STRICT
          else -> TrustPinMode.STRICT
        }

        val url = if (configurationURL != null && configurationURL.isNotEmpty()) {
          try {
            URI.create(configurationURL).toURL()
          } catch (e: Exception) {
            throw TrustPinError.InvalidProjectConfig
          }
        } else {
          null
        }

        val configuration = TrustPinConfiguration(
          organizationId = organizationId,
          projectId = projectId,
          publicKey = publicKey,
          mode = mode,
          configurationURL = url
        )

        val trustPin = getTrustPinInstance(instanceId)
        trustPin.setup(configuration)

        result.success(null)
      } catch (e: TrustPinError) {
        result.error(mapTrustPinError(e), e.message, null)
      } catch (e: Exception) {
        result.error("SETUP_ERROR", e.message, null)
      }
    }
  }

  private fun handleVerify(call: MethodCall, result: Result) {
    coroutineScope.launch {
      try {
        val domain = call.argument<String>("domain")
        val certificatePem = call.argument<String>("certificate")
        val instanceId = call.argument<String>("instanceId")

        if (domain == null || certificatePem == null) {
          result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
          return@launch
        }

        val certificate = parsePemCertificate(certificatePem)
        val trustPin = getTrustPinInstance(instanceId)

        trustPin.verify(domain, certificate)
        result.success(null)
      } catch (e: TrustPinError) {
        result.error(mapTrustPinError(e), e.message, null)
      } catch (e: Exception) {
        result.error("VERIFY_ERROR", e.message, null)
      }
    }
  }

  private fun handleSetLogLevel(call: MethodCall, result: Result) {
    try {
      val logLevelString = call.argument<String>("logLevel")
      val instanceId = call.argument<String>("instanceId")

      if (logLevelString == null) {
        result.error("INVALID_ARGUMENTS", "Missing logLevel argument", null)
        return
      }

      val logLevel = when (logLevelString.lowercase()) {
        "none" -> TrustPinLogLevel.NONE
        "error" -> TrustPinLogLevel.ERROR
        "info" -> TrustPinLogLevel.INFO
        "debug" -> TrustPinLogLevel.DEBUG
        else -> TrustPinLogLevel.ERROR
      }

      val trustPin = getTrustPinInstance(instanceId)
      trustPin.setLogLevel(logLevel)

      result.success(null)
    } catch (e: Exception) {
      result.error("SET_LOG_LEVEL_ERROR", e.message, null)
    }
  }

  private fun handleFetchCertificate(call: MethodCall, result: Result) {
    coroutineScope.launch {
      try {
        val host = call.argument<String>("host")
        val port = call.argument<Int>("port") ?: 443
        val instanceId = call.argument<String>("instanceId")

        if (host == null) {
          result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
          return@launch
        }

        val trustPin = getTrustPinInstance(instanceId)
        val pem = trustPin.fetchCertificate(host, port)

        result.success(pem)
      } catch (e: TrustPinError) {
        result.error(mapTrustPinError(e), e.message, null)
      } catch (e: Exception) {
        result.error("FETCH_CERTIFICATE_ERROR", e.message, null)
      }
    }
  }

  private fun parsePemCertificate(pemCertificate: String): X509Certificate {
    val certificateFactory = CertificateFactory.getInstance("X.509")

    // Extract the certificate content between BEGIN and END markers
    val cleanPem = pemCertificate
      .replace("-----BEGIN CERTIFICATE-----", "")
      .replace("-----END CERTIFICATE-----", "")
      .replace("\\s".toRegex(), "")

    val decodedBytes = Base64.getDecoder().decode(cleanPem)

    // Use 'use' to ensure the stream is properly closed
    return ByteArrayInputStream(decodedBytes).use { inputStream ->
      certificateFactory.generateCertificate(inputStream) as X509Certificate
    }
  }

  private fun getTrustPinInstance(instanceId: String?): TrustPin {
    return if (instanceId.isNullOrEmpty()) {
      TrustPin.default
    } else {
      TrustPin.instance(instanceId)
    }
  }

  private fun mapTrustPinError(error: TrustPinError): String {
    return when (error) {
      is TrustPinError.InvalidProjectConfig -> "INVALID_PROJECT_CONFIG"
      is TrustPinError.ErrorFetchingPinningInfo -> "ERROR_FETCHING_PINNING_INFO"
      is TrustPinError.InvalidServerCert -> "INVALID_SERVER_CERT"
      is TrustPinError.PinsMismatch -> "PINS_MISMATCH"
      is TrustPinError.AllPinsExpired -> "ALL_PINS_EXPIRED"
      is TrustPinError.ConfigurationValidationFailed -> "CONFIGURATION_VALIDATION_FAILED"
      is TrustPinError.DomainNotRegistered -> "DOMAIN_NOT_REGISTERED"
      else -> "INVALID_PROJECT_CONFIG"
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    // Cancel all running coroutines to prevent memory leaks and crashes
    coroutineScope.cancel()
  }
}