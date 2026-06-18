@preconcurrency import FlutterMacOS
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

            return {
                let configuration = TrustPinConfiguration(
                    organizationId: organizationId,
                    projectId: projectId,
                    publicKey: publicKey,
                    mode: mode,
                    configurationURL: configurationURL
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
            let fileName = args.optionalString(Arg.macosFileName)
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
        execute(
            box,
            defaultCode: ErrorCode.fetchCertificate,
            timeoutMessage: "Timed out fetching certificate"
        ) {
            let args = try Arguments(call)
            let host = try args.requireString(Arg.host)
            let port = args.optionalInt(Arg.port) ?? defaultTLSPort
            let timeoutMs = args.optionalInt(Arg.timeoutMs)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                try await withOptionalTimeout(milliseconds: timeoutMs) { () async throws -> String in
                    let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                    return try await trustPin.fetchCertificate(host: host, port: port)
                }
            }
        }
    }

    func handleValidateConnection(_ call: FlutterMethodCall, box: ResultBox) {
        execute(
            box,
            defaultCode: ErrorCode.validateConnection,
            timeoutMessage: "Timed out validating connection"
        ) {
            let args = try Arguments(call)
            let host = try args.requireString(Arg.host)
            let port = args.optionalInt(Arg.port) ?? defaultTLSPort
            let timeoutMs = args.optionalInt(Arg.timeoutMs)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                try await withOptionalTimeout(milliseconds: timeoutMs) {
                    let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
                    let pem = try await trustPin.fetchCertificate(host: host, port: port)
                    try await trustPin.verify(domain: host, certificate: pem)
                }
                return nil
            }
        }
    }

    func handleAwaitConfiguration(_ call: FlutterMethodCall, box: ResultBox) {
        execute(
            box,
            defaultCode: ErrorCode.awaitConfiguration,
            timeoutMessage: "Timed out awaiting configuration"
        ) {
            let args = try Arguments(call)
            let timeoutMs = args.optionalInt(Arg.timeoutMs)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                let trustPin = try TrustPinSDKPlugin.instance(id: instanceId)
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
