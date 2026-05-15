package cloud.trustpin.flutter.sdk

import cloud.trustpin.kotlin.sdk.TrustPinError
import cloud.trustpin.kotlin.sdk.TrustPinLogLevel
import cloud.trustpin.kotlin.sdk.TrustPinMode
import io.flutter.plugin.common.MethodCall
import java.net.URI
import java.net.URL

/**
 * Raised when the inbound argument map is missing or malformed. The wrapping
 * `execute` helper converts this into an `INVALID_ARGUMENTS` Flutter error.
 */
internal class InvalidArgumentsError(message: String) : Exception(message)

/**
 * Returns the value for [key] as a String, or throws when missing / not a
 * String. An empty string is considered present — the original handlers
 * passed empty strings through to the underlying SDK, so we preserve that
 * contract here.
 */
internal fun MethodCall.requireString(key: String): String {
    val value = argument<String>(key)
        ?: throw InvalidArgumentsError("Missing required argument: $key")
    return value
}

/**
 * Returns the value for [key] as a String, or null when the key is missing,
 * not a String, or empty. Empty is treated as "not provided" to match the
 * previous handler behaviour.
 */
internal fun MethodCall.optionalString(key: String): String? {
    val value = argument<String>(key)
    return if (value.isNullOrEmpty()) null else value
}

/** Returns the value for [key] as an Int, or null when missing / not an Int. */
internal fun MethodCall.optionalInt(key: String): Int? = argument<Int>(key)

/**
 * Parses an optional URL argument. A missing or empty value returns null.
 * Anything that cannot be parsed surfaces as `TrustPinError.InvalidProjectConfig`,
 * matching the previous handler behaviour.
 */
internal fun MethodCall.optionalURL(key: String): URL? {
    val raw = optionalString(key) ?: return null
    return try {
        URI.create(raw).toURL()
    } catch (_: Exception) {
        throw TrustPinError.InvalidProjectConfig
    }
}

// MARK: - Domain value parsing

internal fun String?.toTrustPinMode(): TrustPinMode = when (this?.lowercase()) {
    "permissive" -> TrustPinMode.PERMISSIVE
    else -> TrustPinMode.STRICT
}

internal fun String?.toTrustPinLogLevel(): TrustPinLogLevel = when (this?.lowercase()) {
    "none" -> TrustPinLogLevel.NONE
    "info" -> TrustPinLogLevel.INFO
    "debug" -> TrustPinLogLevel.DEBUG
    else -> TrustPinLogLevel.ERROR
}
