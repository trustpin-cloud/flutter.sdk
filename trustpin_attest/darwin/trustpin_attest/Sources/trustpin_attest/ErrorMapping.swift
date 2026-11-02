#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinAttestKit

/// Translates a `TrustPinAttestError` case into the stable string code sent
/// to Dart. Unknown future cases fall through to the generic code.
func mapAttestError(_ error: TrustPinAttestError) -> String {
    switch error {
    case .invalidConfiguration: return ErrorCode.invalidConfiguration
    case .alreadyInitialized:   return ErrorCode.alreadyInitialized
    case .notSetUp:             return ErrorCode.notSetUp
    case .unsupportedDevice:    return ErrorCode.unsupportedDevice
    case .evidenceUnavailable:  return ErrorCode.evidenceUnavailable
    case .bindingRequired:      return ErrorCode.bindingRequired
    case .attestationFailed:    return ErrorCode.attestationFailed
    case .verifierUnavailable:  return ErrorCode.verifierUnavailable
    case .verifierIncompatible: return ErrorCode.verifierIncompatible
    case .invalidDigest:        return ErrorCode.invalidDigest
    @unknown default:           return ErrorCode.attest
    }
}

/// The reasons an `attestationFailed` error carries; empty for other cases.
func reasons(of error: TrustPinAttestError) -> [String] {
    if case .attestationFailed(let reasons) = error { return reasons }
    return []
}

/// Converts any error thrown from a handler into a `FlutterError` with a
/// stable code. An `attestationFailed` error carries its reasons as details.
func flutterError(from error: Error) -> FlutterError {
    switch error {
    case is CancellationError:
        return FlutterError(code: ErrorCode.cancelled, message: "Operation was cancelled", details: nil)
    case let invalid as InvalidArgumentsError:
        return FlutterError(code: ErrorCode.invalidArguments, message: invalid.message, details: nil)
    case let attest as TrustPinAttestError:
        return FlutterError(
            code: mapAttestError(attest),
            message: attest.localizedDescription,
            details: reasons(of: attest)
        )
    default:
        return FlutterError(code: ErrorCode.attest, message: error.localizedDescription, details: nil)
    }
}

// MARK: - Execute helper

/// The async operation produced by a handler's synchronous "parse" phase.
typealias HandlerOperation = @Sendable () async throws -> Any?

/// Runs a handler in two phases: `parse` extracts the arguments synchronously
/// (errors are delivered at once), then the returned operation runs on an
/// unstructured `Task` and its result is delivered through `box`.
func execute(_ box: ResultBox, _ parse: () throws -> HandlerOperation) {
    let operation: HandlerOperation
    do {
        operation = try parse()
    } catch {
        box.deliver(flutterError(from: error))
        return
    }

    Task { [box] in
        do {
            try Task.checkCancellation()
            let value = try await operation()
            try Task.checkCancellation()
            box.deliver(value)
        } catch {
            box.deliver(flutterError(from: error))
        }
    }
}
