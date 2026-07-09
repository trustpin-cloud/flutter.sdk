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
    is TrustPinError.InvalidProjectConfig -> ErrorCode.INVALID_PROJECT_CONFIG
    is TrustPinError.AlreadyInitialized -> ErrorCode.ALREADY_INITIALIZED
    is TrustPinError.ErrorFetchingPinningInfo -> ErrorCode.ERROR_FETCHING_PINNING_INFO
    is TrustPinError.InvalidServerCert -> ErrorCode.INVALID_SERVER_CERT
    is TrustPinError.PinsMismatch -> ErrorCode.PINS_MISMATCH
    is TrustPinError.AllPinsExpired -> ErrorCode.ALL_PINS_EXPIRED
    is TrustPinError.ConfigurationValidationFailed ->
        ErrorCode.CONFIGURATION_VALIDATION_FAILED
    is TrustPinError.DomainNotRegistered -> ErrorCode.DOMAIN_NOT_REGISTERED
    is TrustPinError.Timeout -> ErrorCode.FETCH_CERTIFICATE_TIMEOUT
    is TrustPinError.ConfigIntegrityError -> ErrorCode.CONFIG_INTEGRITY_FAILED
    // Documented cross-platform contract: operations before setup surface as
    // INVALID_PROJECT_CONFIG, matching the iOS/macOS SDK which has no
    // separate not-initialized case.
    is TrustPinError.NotInitialized -> ErrorCode.INVALID_PROJECT_CONFIG
    is TrustPinError.SetupInProgress -> ErrorCode.SETUP_IN_PROGRESS
    is TrustPinError.LockTimeout -> ErrorCode.LOCK_TIMEOUT
    is TrustPinError.SSLContextSetupFailed -> ErrorCode.SSL_CONTEXT_SETUP_FAILED
    is TrustPinError.UnsupportedDevice -> ErrorCode.UNSUPPORTED_DEVICE
    else -> ErrorCode.INVALID_PROJECT_CONFIG
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
 * Timeouts are enforced by the native SDK (surfacing as
 * [TrustPinError.Timeout]); the [TimeoutCancellationException] branch is
 * defensive, in case a `kotlinx.coroutines` timeout ever leaks through, and
 * must stay before its superclass [CancellationException].
 */
internal fun Result.deliverError(
    error: Throwable,
    defaultCode: String
): Boolean = when (error) {
    is TimeoutCancellationException -> {
        error(ErrorCode.FETCH_CERTIFICATE_TIMEOUT, "Timed out", null)
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
    parse: () -> HandlerOperation
) {
    val operation: HandlerOperation = try {
        parse()
    } catch (e: Exception) {
        result.deliverError(e, defaultCode)
        return
    }

    scope.launch {
        try {
            result.success(operation())
        } catch (e: Exception) {
            val shouldRethrow = result.deliverError(e, defaultCode)
            if (shouldRethrow) throw e
        }
    }
}
