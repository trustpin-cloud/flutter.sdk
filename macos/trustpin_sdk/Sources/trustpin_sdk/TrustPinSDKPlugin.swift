@preconcurrency import FlutterMacOS
import TrustPinKit
import AppKit

/// Thrown when `fetchCertificate` exceeds its caller-provided deadline.
private struct FetchCertificateTimeoutError: Error {}

// MARK: - Plugin

public final class TrustPinSDKPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        // macOS FlutterEngine does not yet implement `makeBackgroundTaskQueue`
        // (the protocol method is @optional with a TODO in the framework, and
        // calling it through the relay crashes with an unrecognized selector).
        // Result delivery therefore must go through the main thread.
        let channel = FlutterMethodChannel(
            name: "cloud.trustpin.sdk.flutter",
            binaryMessenger: registrar.messenger
        )
        registrar.addMethodCallDelegate(TrustPinSDKPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let boxed = ResultBox(result)

        switch call.method {
        case "setup":
            handleSetup(call: call, boxed: boxed)

        case "verify":
            handleVerify(call: call, boxed: boxed)

        case "setLogLevel":
            handleSetLogLevel(call: call, boxed: boxed)

        case "fetchCertificate":
            handleFetchCertificate(call: call, boxed: boxed)

        default:
            Task { @MainActor in
                boxed.callResult(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Handlers

    private func handleSetup(call: FlutterMethodCall, boxed: ResultBox) {
        guard
            let args = call.arguments as? [String: Any],
            let organizationId = args["organizationId"] as? String,
            let projectId = args["projectId"] as? String,
            let publicKey = args["publicKey"] as? String
        else {
            Task { @MainActor in
                boxed.callResult(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing required arguments",
                    details: nil
                ))
            }
            return
        }

        let instanceId = args["instanceId"] as? String

        var configurationURL: URL?
        if let s = args["configurationURL"] as? String, !s.isEmpty {
            configurationURL = URL(string: s)
        }

        let modeString = (args["mode"] as? String) ?? "strict"
        let mode: TrustPinMode = (modeString == "permissive") ? .permissive : .strict

        Task { [organizationId, projectId, publicKey, instanceId, configurationURL, mode, boxed] in
            do {
                try Task.checkCancellation()

                let configuration = TrustPinConfiguration(
                    organizationId: organizationId,
                    projectId: projectId,
                    publicKey: publicKey,
                    mode: mode,
                    configurationURL: configurationURL
                )

                try await TrustPinSDKPlugin.getTrustPinInstance(instanceId: instanceId).setup(configuration)

                try Task.checkCancellation()
                await MainActor.run { boxed.callResult(nil) }
            } catch is CancellationError {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: "CANCELLED",
                        message: "Operation was cancelled",
                        details: nil
                    ))
                }
            } catch let error as TrustPinErrors {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: TrustPinSDKPlugin.mapTrustPinError(error),
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } catch {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: "SETUP_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    private func handleVerify(call: FlutterMethodCall, boxed: ResultBox) {
        guard
            let args = call.arguments as? [String: Any],
            let domain = args["domain"] as? String,
            let certificate = args["certificate"] as? String
        else {
            Task { @MainActor in
                boxed.callResult(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing required arguments",
                    details: nil
                ))
            }
            return
        }

        let instanceId = args["instanceId"] as? String

        Task { [domain, certificate, instanceId, boxed] in
            do {
                try Task.checkCancellation()

                try await TrustPinSDKPlugin.getTrustPinInstance(instanceId: instanceId).verify(domain: domain, certificate: certificate)

                try Task.checkCancellation()
                await MainActor.run { boxed.callResult(nil) }
            } catch is CancellationError {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: "CANCELLED",
                        message: "Operation was cancelled",
                        details: nil
                    ))
                }
            } catch let error as TrustPinErrors {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: TrustPinSDKPlugin.mapTrustPinError(error),
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } catch {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: "VERIFY_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    private func handleSetLogLevel(call: FlutterMethodCall, boxed: ResultBox) {
        guard let args = call.arguments as? [String: Any],
              let logLevelString = args["logLevel"] as? String
        else {
            Task { @MainActor in
                boxed.callResult(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing logLevel argument",
                    details: nil
                ))
            }
            return
        }

        let logLevel: TrustPinLogLevel
        switch logLevelString.lowercased() {
        case "none":  logLevel = .none
        case "error": logLevel = .error
        case "info":  logLevel = .info
        case "debug": logLevel = .debug
        default:      logLevel = .error
        }

        let instanceId = args["instanceId"] as? String

        TrustPinSDKPlugin.getTrustPinInstance(instanceId: instanceId).set(logLevel: logLevel)

        Task { @MainActor in
            boxed.callResult(nil)
        }
    }

    private func handleFetchCertificate(call: FlutterMethodCall, boxed: ResultBox) {
        guard
            let args = call.arguments as? [String: Any],
            let host = args["host"] as? String
        else {
            Task { @MainActor in
                boxed.callResult(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing required arguments",
                    details: nil
                ))
            }
            return
        }

        let port = args["port"] as? Int ?? 443
        let timeoutMs = args["timeoutMs"] as? Int
        let instanceId = args["instanceId"] as? String

        Task { [host, port, timeoutMs, instanceId, boxed] in
            do {
                try Task.checkCancellation()

                let fetch: @Sendable () async throws -> String = {
                    try await TrustPinSDKPlugin.getTrustPinInstance(instanceId: instanceId)
                        .fetchCertificate(host: host, port: port)
                }

                let pem: String
                if let timeoutMs, timeoutMs > 0 {
                    pem = try await TrustPinSDKPlugin.withTimeout(
                        milliseconds: timeoutMs,
                        operation: fetch
                    )
                } else {
                    pem = try await fetch()
                }

                try Task.checkCancellation()
                await MainActor.run { boxed.callResult(pem) }
            } catch is FetchCertificateTimeoutError {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: "FETCH_CERTIFICATE_TIMEOUT",
                        message: "Timed out fetching certificate",
                        details: nil
                    ))
                }
            } catch is CancellationError {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: "CANCELLED",
                        message: "Operation was cancelled",
                        details: nil
                    ))
                }
            } catch let error as TrustPinErrors {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: TrustPinSDKPlugin.mapTrustPinError(error),
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } catch {
                await MainActor.run {
                    boxed.callResult(FlutterError(
                        code: "FETCH_CERTIFICATE_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    /// Races [operation] against a sleep of [milliseconds]. If the sleep wins,
    /// throws `FetchCertificateTimeoutError` and the operation task is
    /// cancelled by structured concurrency.
    fileprivate static func withTimeout<T: Sendable>(
        milliseconds: Int,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanos = UInt64(milliseconds) * 1_000_000
                try await Task.sleep(nanoseconds: nanos)
                throw FetchCertificateTimeoutError()
            }
            do {
                guard let first = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return first
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private static func getTrustPinInstance(instanceId: String?) -> TrustPin {
        guard let instanceId, instanceId.isEmpty == false else {
            return TrustPin.default
        }
        return TrustPin.instance(id: instanceId)
    }

    /// Keep error mapping outside the class so it doesn't capture `self` inside detached tasks.
    private static func mapTrustPinError(_ error: TrustPinErrors) -> String {
        switch error {
        case .invalidProjectConfig:            return "INVALID_PROJECT_CONFIG"
        case .errorFetchingPinningInfo:        return "ERROR_FETCHING_PINNING_INFO"
        case .invalidServerCert:               return "INVALID_SERVER_CERT"
        case .pinsMismatch:                    return "PINS_MISMATCH"
        case .allPinsExpired:                  return "ALL_PINS_EXPIRED"
        case .configurationValidationFailed:   return "CONFIGURATION_VALIDATION_FAILED"
        case .domainNotRegistered:             return "DOMAIN_NOT_REGISTERED"
        @unknown default:                      return "INVALID_PROJECT_CONFIG"
        }
    }
}
