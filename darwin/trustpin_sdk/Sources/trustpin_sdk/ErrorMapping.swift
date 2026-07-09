#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinKit

/// Translates a `TrustPinErrors` case into the stable string code we send to
/// Dart. Unknown future cases fall through to `INVALID_PROJECT_CONFIG` —
/// matching the previous behaviour.
func mapTrustPinError(_ error: TrustPinErrors) -> String {
    switch error {
    case .invalidProjectConfig:          return ErrorCode.invalidProjectConfig
    case .alreadyInitialized:            return ErrorCode.alreadyInitialized
    case .errorFetchingPinningInfo:      return ErrorCode.errorFetchingPinningInfo
    case .invalidServerCert:             return ErrorCode.invalidServerCert
    case .pinsMismatch:                  return ErrorCode.pinsMismatch
    case .allPinsExpired:                return ErrorCode.allPinsExpired
    case .configurationValidationFailed: return ErrorCode.configurationValidationFailed
    case .domainNotRegistered:           return ErrorCode.domainNotRegistered
    case .timeout:                       return ErrorCode.fetchCertificateTimeout
    case .configIntegrityFailed:         return ErrorCode.configIntegrityFailed
    @unknown default:                    return ErrorCode.invalidProjectConfig
    }
}

/// Converts any error thrown from a handler into a `FlutterError` with the
/// appropriate stable code and message.
///
/// Timeouts are enforced by the native SDK and arrive as
/// `TrustPinErrors.timeout`, mapped like every other SDK error case.
///
/// - parameters:
///   - error: the thrown error
///   - defaultCode: code used for generic, unclassified errors
func flutterError(
    from error: Error,
    defaultCode: String
) -> FlutterError {
    switch error {
    case is CancellationError:
        return FlutterError(
            code: ErrorCode.cancelled,
            message: "Operation was cancelled",
            details: nil
        )
    case let invalid as InvalidArgumentsError:
        return FlutterError(
            code: ErrorCode.invalidArguments,
            message: invalid.message,
            details: nil
        )
    case let trustPin as TrustPinErrors:
        return FlutterError(
            code: mapTrustPinError(trustPin),
            message: trustPin.localizedDescription,
            details: nil
        )
    default:
        return FlutterError(
            code: defaultCode,
            message: error.localizedDescription,
            details: nil
        )
    }
}

// MARK: - Execute helper

/// The async operation produced by a handler's synchronous "parse" phase.
/// Handlers return a certificate PEM string, a boolean (e.g.
/// `isConfigurationLoaded`), or no value.
typealias HandlerOperation = @Sendable () async throws -> Any?

/// Runs a handler in two phases:
///
/// 1. The caller's `parse` block runs synchronously. It extracts arguments
///    and returns the async closure to execute. Anything thrown here (e.g.
///    `InvalidArgumentsError`) is delivered immediately as a Flutter error.
/// 2. The returned async closure runs on an unstructured `Task`. Its result
///    is delivered through the supplied `ResultBox`. All recognised error
///    types are mapped to stable Flutter error codes.
func execute(
    _ box: ResultBox,
    defaultCode: String,
    _ parse: () throws -> HandlerOperation
) {
    let operation: HandlerOperation
    do {
        operation = try parse()
    } catch {
        box.deliver(flutterError(from: error, defaultCode: defaultCode))
        return
    }

    Task { [box] in
        do {
            try Task.checkCancellation()
            let value = try await operation()
            try Task.checkCancellation()
            box.deliver(value)
        } catch {
            box.deliver(flutterError(from: error, defaultCode: defaultCode))
        }
    }
}
