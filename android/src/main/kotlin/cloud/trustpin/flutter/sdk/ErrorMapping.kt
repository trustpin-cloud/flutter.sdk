package cloud.trustpin.flutter.sdk

import cloud.trustpin.kotlin.sdk.TrustPinError
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.launch

/** A unit of work produced by a handler's synchronous parse phase. */
internal typealias HandlerOperation = suspend () -> Any?

/**
 * Translates a [TrustPinError] case into the stable string code we send to
 * Dart. Unknown future cases fall through to `INVALID_PROJECT_CONFIG` —
 * matching the previous behaviour.
 */
internal fun mapTrustPinError(error: TrustPinError): String = when (error) {
    is TrustPinError.InvalidProjectConfig -> "INVALID_PROJECT_CONFIG"
    is TrustPinError.ErrorFetchingPinningInfo -> "ERROR_FETCHING_PINNING_INFO"
    is TrustPinError.InvalidServerCert -> "INVALID_SERVER_CERT"
    is TrustPinError.PinsMismatch -> "PINS_MISMATCH"
    is TrustPinError.AllPinsExpired -> "ALL_PINS_EXPIRED"
    is TrustPinError.ConfigurationValidationFailed -> "CONFIGURATION_VALIDATION_FAILED"
    is TrustPinError.DomainNotRegistered -> "DOMAIN_NOT_REGISTERED"
    else -> "INVALID_PROJECT_CONFIG"
}

/**
 * Delivers any error thrown from a handler to the Flutter side using the
 * appropriate stable code. Returns `true` only for a plain
 * [CancellationException] (cooperative cancellation), so the caller can
 * re-throw it and honour structured concurrency. Returns `false` for every
 * other case, including [TimeoutCancellationException] — a timeout is a
 * terminal outcome of the handler, not a cancellation request directed at
 * the surrounding scope.
 *
 * Order matters: [TimeoutCancellationException] must be checked before its
 * superclass [CancellationException].
 */
internal fun Result.deliverError(
    error: Throwable,
    defaultCode: String,
    timeoutMessage: String = "Timed out"
): Boolean = when (error) {
    is TimeoutCancellationException -> {
        error(ErrorCode.FETCH_CERTIFICATE_TIMEOUT, timeoutMessage, null)
        false
    }
    is CancellationException -> {
        error(ErrorCode.CANCELLED, "Operation was cancelled", null)
        true
    }
    is InvalidArgumentsError -> {
        error(ErrorCode.INVALID_ARGUMENTS, error.message, null)
        false
    }
    is TrustPinError -> {
        error(mapTrustPinError(error), error.message, null)
        false
    }
    else -> {
        error(defaultCode, error.message, null)
        false
    }
}

/**
 * Runs a handler in two phases:
 *
 * 1. [parse] runs synchronously on the calling thread. It extracts arguments
 *    and returns the suspending closure to execute. Anything thrown here
 *    (e.g. [InvalidArgumentsError]) is delivered immediately.
 * 2. The returned [HandlerOperation] is launched on [scope]. Its result is
 *    delivered through [result]; recognised errors are mapped to stable codes.
 */
internal fun execute(
    scope: CoroutineScope,
    result: Result,
    defaultCode: String,
    timeoutMessage: String = "Timed out",
    parse: () -> HandlerOperation
) {
    val operation: HandlerOperation = try {
        parse()
    } catch (e: Exception) {
        result.deliverError(e, defaultCode, timeoutMessage)
        return
    }

    scope.launch {
        try {
            result.success(operation())
        } catch (e: Exception) {
            val shouldRethrow = result.deliverError(e, defaultCode, timeoutMessage)
            if (shouldRethrow) throw e
        }
    }
}
