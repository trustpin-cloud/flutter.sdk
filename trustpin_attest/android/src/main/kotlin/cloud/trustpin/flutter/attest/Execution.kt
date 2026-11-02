package cloud.trustpin.flutter.attest

import cloud.trustpin.kotlin.attest.TrustPinAttestError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** A unit of work produced by a handler's synchronous parse phase. */
internal typealias HandlerOperation = suspend () -> Any?

/**
 * Raised when the inbound argument map is missing or malformed; delivered as
 * `INVALID_ARGUMENTS`.
 */
internal class InvalidArgumentsError(message: String) : Exception(message)

internal fun MethodCall.requireString(key: String): String =
    argument<String>(key) ?: throw InvalidArgumentsError("Missing required argument: $key")

/** Null when the key is missing or the value is empty. */
internal fun MethodCall.optionalString(key: String): String? =
    argument<String>(key)?.takeIf { it.isNotEmpty() }

/** Null only when the key is missing; an empty string stays empty. */
internal fun MethodCall.nullableString(key: String): String? = argument<String>(key)

internal fun MethodCall.stringList(key: String): List<String> =
    argument<List<*>>(key)?.filterIsInstance<String>()
        ?: throw InvalidArgumentsError("Missing required argument: $key")

/** A Dart `Uint8List` argument. */
internal fun MethodCall.requireBytes(key: String): ByteArray =
    argument<ByteArray>(key) ?: throw InvalidArgumentsError("Missing required argument: $key")

/** A number argument as a Long; Dart ints arrive as Int or Long. */
internal fun MethodCall.optionalLong(key: String): Long? =
    (argument<Any>(key) as? Number)?.toLong()

/** Request headers as the SDK takes them: one-element value lists. */
internal fun MethodCall.headerLists(key: String): Map<String, List<String>> {
    val raw = argument<Map<*, *>>(key) ?: return emptyMap()
    return buildMap {
        for ((name, value) in raw) {
            if (name is String && value is String) put(name, listOf(value))
        }
    }
}

/**
 * Delivers [error] to Dart with a stable code. Returns `true` only for a
 * cooperative [CancellationException], which the caller re-throws.
 */
internal fun Result.deliverError(error: Throwable): Boolean = when (error) {
    is CancellationException -> {
        error(ErrorCode.CANCELLED, "Operation was cancelled", null)
        true
    }
    is InvalidArgumentsError -> {
        error(ErrorCode.INVALID_ARGUMENTS, error.message, null)
        false
    }
    is TrustPinAttestError -> {
        error(mapAttestError(error), error.message, error.reasonList())
        false
    }
    // `TrustPinAttest.instance(id)` rejects an invalid id this way.
    is IllegalArgumentException -> {
        error(ErrorCode.INVALID_CONFIGURATION, error.message, null)
        false
    }
    else -> {
        error(ErrorCode.ATTEST, error.message, null)
        false
    }
}

/**
 * Runs a handler in two phases: [parse] extracts the arguments synchronously
 * (errors are delivered at once), then the returned operation is launched on
 * [scope] and its result delivered through [result].
 */
internal fun execute(scope: CoroutineScope, result: Result, parse: () -> HandlerOperation) {
    val operation: HandlerOperation = try {
        parse()
    } catch (e: Exception) {
        result.deliverError(e)
        return
    }

    scope.launch {
        try {
            result.success(operation())
        } catch (e: Exception) {
            if (result.deliverError(e)) throw e
        }
    }
}
