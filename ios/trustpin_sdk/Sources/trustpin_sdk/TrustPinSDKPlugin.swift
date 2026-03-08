@preconcurrency import Flutter
import TrustPinKit
import UIKit

// MARK: - Plugin

public final class TrustPinSDKPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let taskQueue = registrar.messenger().makeBackgroundTaskQueue?()
        let channel = FlutterMethodChannel(
            name: "cloud.trustpin.sdk.flutter",
            binaryMessenger: registrar.messenger(),
            codec: FlutterStandardMethodCodec.sharedInstance(),
            taskQueue: taskQueue
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
                boxed.result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Handlers
    
    private func handleSetup(call: FlutterMethodCall, boxed: ResultBox) {
        // Extract args synchronously (avoid capturing FlutterMethodCall in tasks)
        guard
            let args = call.arguments as? [String: Any],
            let organizationId = args["organizationId"] as? String,
            let projectId = args["projectId"] as? String,
            let publicKey = args["publicKey"] as? String
        else {
            Task { @MainActor in
                boxed.result(FlutterError(
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

        // Use structured concurrency with automatic cancellation
        Task { [organizationId, projectId, publicKey, instanceId, configurationURL, mode, boxed] in
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()

                let configuration = TrustPinConfiguration(
                    organizationId: organizationId,
                    projectId: projectId,
                    publicKey: publicKey,
                    mode: mode,
                    configurationURL: configurationURL
                )
                
                try await TrustPinSDKPlugin.getTrustPinInstance(instanceId: instanceId).setup(configuration)

                // Check for cancellation before returning result
                try Task.checkCancellation()
                await MainActor.run { boxed.result(nil) }
            } catch is CancellationError {
                // Task was cancelled, don't call result to avoid crashes
                return
            } catch let error as TrustPinErrors {
                await MainActor.run {
                    boxed.result(FlutterError(
                        code: TrustPinSDKPlugin.mapTrustPinError(error),
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } catch {
                await MainActor.run {
                    boxed.result(FlutterError(
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
                boxed.result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing required arguments",
                    details: nil
                ))
            }
            return
        }

        let instanceId = args["instanceId"] as? String

        // Use structured concurrency with automatic cancellation
        Task { [domain, certificate, instanceId, boxed] in
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()

                try await TrustPinSDKPlugin.getTrustPinInstance(instanceId: instanceId).verify(domain: domain, certificate: certificate)

                // Check for cancellation before returning result
                try Task.checkCancellation()
                await MainActor.run { boxed.result(nil) }
            } catch is CancellationError {
                // Task was cancelled, don't call result to avoid crashes
                return
            } catch let error as TrustPinErrors {
                await MainActor.run {
                    boxed.result(FlutterError(
                        code: TrustPinSDKPlugin.mapTrustPinError(error),
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } catch {
                await MainActor.run {
                    boxed.result(FlutterError(
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
                boxed.result(FlutterError(
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
        
        // complete on main for Flutter safety
        Task { @MainActor in
            boxed.result(nil)
        }
    }

    private func handleFetchCertificate(call: FlutterMethodCall, boxed: ResultBox) {
        guard
            let args = call.arguments as? [String: Any],
            let host = args["host"] as? String
        else {
            Task { @MainActor in
                boxed.result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing required arguments",
                    details: nil
                ))
            }
            return
        }

        let port = args["port"] as? Int ?? 443
        let instanceId = args["instanceId"] as? String

        Task { [host, port, instanceId, boxed] in
            do {
                try Task.checkCancellation()

                let pem = try await TrustPinSDKPlugin.getTrustPinInstance(instanceId: instanceId)
                    .fetchCertificate(host: host, port: port)

                try Task.checkCancellation()
                await MainActor.run { boxed.result(pem) }
            } catch is CancellationError {
                return
            } catch let error as TrustPinErrors {
                await MainActor.run {
                    boxed.result(FlutterError(
                        code: TrustPinSDKPlugin.mapTrustPinError(error),
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } catch {
                await MainActor.run {
                    boxed.result(FlutterError(
                        code: "FETCH_CERTIFICATE_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
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
