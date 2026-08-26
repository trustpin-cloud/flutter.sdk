#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinKit

extension TrustPinSDKPlugin {

    func handleSetup(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.setup) {
            let args = try Arguments(call)
            let organizationId = try args.requireString(Arg.organizationId)
            let projectId = try args.requireString(Arg.projectId)
            let publicKey = try args.requireString(Arg.publicKey)
            let instanceId = args.optionalString(Arg.instanceId)
            let configurationURL = try args.optionalURL(Arg.configurationURL)
            let mode = TrustPinMode(args.optionalString(Arg.mode))
            let embeddedConfigurationURL =
                try args.optionalBundleResourceURL(Arg.embeddedConfigurationFile)

            return {
                let configuration = TrustPinConfiguration(
                    organizationId: organizationId,
                    projectId: projectId,
                    publicKey: publicKey,
                    mode: mode,
                    configurationURL: configurationURL,
                    embeddedConfigurationURL: embeddedConfigurationURL
                )
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                try await trustPin.setup(configuration)
                return nil
            }
        }
    }

    func handleSetupWithNativeBundle(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.setup) {
            let args = try Arguments(call)
            // The Dart side sends every per-platform filename in one call; read
            // the key matching the platform this binary was compiled for.
            #if os(iOS)
            let fileName = args.optionalString(Arg.iosFileName)
            #else
            let fileName = args.optionalString(Arg.macosFileName)
            #endif
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                // When the caller passes no filename we let the native SDK
                // pick its own default (`TrustPin-Info.plist`) instead of
                // duplicating the constant on the Flutter side.
                let configuration: TrustPinConfiguration
                if let fileName {
                    configuration = try TrustPinConfiguration.fromPlist(.main, fileName: fileName)
                } else {
                    configuration = try TrustPinConfiguration.fromPlist()
                }
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                try await trustPin.setup(configuration)
                return nil
            }
        }
    }

    func handleVerify(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.verify) {
            let args = try Arguments(call)
            let domain = try args.requireString(Arg.domain)
            let certificate = try args.requireString(Arg.certificate)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                try await trustPin.verify(domain: domain, certificate: certificate)
                return nil
            }
        }
    }

    func handleSetLogLevel(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.setLogLevel) {
            let args = try Arguments(call)
            let logLevel = TrustPinLogLevel(try args.requireString(Arg.logLevel))
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                trustPin.set(logLevel: logLevel)
                return nil
            }
        }
    }

    func handleFetchCertificate(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.fetchCertificate) {
            let args = try Arguments(call)
            let host = try args.requireString(Arg.host)
            let port = args.optionalInt(Arg.port) ?? defaultTLSPort
            let timeoutMs = args.optionalInt(Arg.timeoutMs)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                // A nil/non-positive timeout defers to the native SDK's
                // default; the SDK throws `TrustPinErrors.timeout` when the
                // bound is exceeded.
                if let timeoutMs, timeoutMs > 0 {
                    return try await trustPin.fetchCertificate(
                        host: host,
                        port: port,
                        timeout: TimeInterval(timeoutMs) / 1000.0
                    )
                }
                return try await trustPin.fetchCertificate(host: host, port: port)
            }
        }
    }

    func handleValidateConnection(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.validateConnection) {
            let args = try Arguments(call)
            let host = try args.requireString(Arg.host)
            let port = args.optionalInt(Arg.port) ?? defaultTLSPort
            let timeoutMs = args.optionalInt(Arg.timeoutMs)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                if let timeoutMs, timeoutMs > 0 {
                    // The caller's timeout bounds the composed operation. The
                    // native API takes one bound per call, so the verify
                    // phase gets whatever the fetch phase left of the budget.
                    let timeout = TimeInterval(timeoutMs) / 1000.0
                    let start = Date()
                    let pem = try await trustPin.fetchCertificate(
                        host: host,
                        port: port,
                        timeout: timeout
                    )
                    let remaining = timeout - Date().timeIntervalSince(start)
                    guard remaining > 0 else { throw TrustPinErrors.timeout }
                    try await trustPin.verify(
                        domain: host,
                        certificate: pem,
                        timeout: remaining
                    )
                } else {
                    let pem = try await trustPin.fetchCertificate(host: host, port: port)
                    try await trustPin.verify(domain: host, certificate: pem)
                }
                return nil
            }
        }
    }

    func handleAwaitConfiguration(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.awaitConfiguration) {
            let args = try Arguments(call)
            let timeoutMs = args.optionalInt(Arg.timeoutMs)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                // The native API takes a `TimeInterval` (seconds); the Dart
                // side passes milliseconds. A nil/non-positive value defers to
                // the SDK's default timeout.
                if let timeoutMs, timeoutMs > 0 {
                    try await trustPin.awaitConfiguration(
                        timeout: TimeInterval(timeoutMs) / 1000.0
                    )
                } else {
                    try await trustPin.awaitConfiguration()
                }
                return nil
            }
        }
    }

    func handleIsConfigurationLoaded(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box, defaultCode: ErrorCode.awaitConfiguration) {
            let args = try Arguments(call)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                return await trustPin.isConfigurationLoaded
            }
        }
    }

    /// Returns the named TrustPin instance, or the default one when `id` is
    /// nil or empty. Kept as a static method so it never captures `self`
    /// from inside a `@Sendable` closure.
    static func instance(id: String?) throws -> TrustPin {
        guard let id, !id.isEmpty else { return TrustPin.default }
        return try TrustPin.instance(id: id)
    }
}
