#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinAttestKit

extension TrustPinAttestPlugin {

    func handleSetup(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let args = try Arguments(call)
            let rawURL = try args.requireString(Arg.verifierUrl)
            let hosts = try args.stringList(Arg.attestedHosts)
            let debugToken = args.optionalString(Arg.debugToken)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                // The native initializer validates the URL and the hosts.
                guard let url = URL(string: rawURL) else {
                    throw TrustPinAttestError.invalidConfiguration
                }
                let configuration = try TrustPinAttestConfiguration(
                    verifierURL: url,
                    attestedHosts: hosts
                )
                try await TrustPinAttestPlugin.setUp(
                    configuration,
                    debugToken: debugToken,
                    instanceId: instanceId
                )
                return nil
            }
        }
    }

    func handleSetupWithNativeBundle(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let args = try Arguments(call)
            // The Dart side sends every per-platform filename in one call;
            // read the key matching the platform this binary was compiled for.
            #if os(iOS)
            let fileName = args.optionalString(Arg.iosFileName)
            #else
            let fileName = args.optionalString(Arg.macosFileName)
            #endif
            let debugToken = args.optionalString(Arg.debugToken)
            let instanceId = args.optionalString(Arg.instanceId)

            return {
                // Without a filename the native SDK uses its own default
                // (`TrustPin-Info.plist`), the file the pinning setup reads.
                let configuration: TrustPinAttestConfiguration
                if let fileName {
                    configuration = try TrustPinAttestConfiguration.fromPlist(.main, fileName: fileName)
                } else {
                    configuration = try TrustPinAttestConfiguration.fromPlist()
                }
                try await TrustPinAttestPlugin.setUp(
                    configuration,
                    debugToken: debugToken,
                    instanceId: instanceId
                )
                return nil
            }
        }
    }

    func handlePrefetch(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let instanceId = try Arguments(call).optionalString(Arg.instanceId)
            return {
                try TrustPinAttestPlugin.instance(id: instanceId).prefetch()
                return nil
            }
        }
    }

    func handleGetToken(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let instanceId = try Arguments(call).optionalString(Arg.instanceId)
            return {
                try await TrustPinAttestPlugin.instance(id: instanceId).getToken()
            }
        }
    }

    func handleAttestationHeaders(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let args = try Arguments(call)
            let request = try args.request()
            let instanceId = args.optionalString(Arg.instanceId)
            return {
                try await TrustPinAttestPlugin.instance(id: instanceId).attestationHeaders(for: request)
            }
        }
    }

    func handleAssertionHeaders(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let args = try Arguments(call)
            let digest = try args.requireData(Arg.payloadDigest)
            let instanceId = args.optionalString(Arg.instanceId)
            return {
                try await TrustPinAttestPlugin.instance(id: instanceId).assertionHeaders(payloadDigest: digest)
            }
        }
    }

    func handleSetTokenBinding(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let args = try Arguments(call)
            let value = args.nullableString(Arg.value)
            let instanceId = args.optionalString(Arg.instanceId)
            return {
                try TrustPinAttestPlugin.instance(id: instanceId).setTokenBinding(value)
                return nil
            }
        }
    }

    func handleBindToHeader(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let args = try Arguments(call)
            let name = args.optionalString(Arg.name)
            let instanceId = args.optionalString(Arg.instanceId)
            return {
                try TrustPinAttestPlugin.instance(id: instanceId).bindToHeader(name)
                return nil
            }
        }
    }

    func handleState(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let instanceId = try Arguments(call).optionalString(Arg.instanceId)
            return {
                let state = try TrustPinAttestPlugin.instance(id: instanceId).state
                return state.wireMap(instanceId: instanceId ?? defaultInstanceId)
            }
        }
    }

    func handleReset(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let instanceId = try Arguments(call).optionalString(Arg.instanceId)
            return {
                // A no-op before setup, the contract Dart exposes on every
                // platform.
                try await TrustPinAttestPlugin.instance(id: instanceId).reset()
                return nil
            }
        }
    }

    func handleSetLogLevel(_ call: FlutterMethodCall, box: ResultBox) {
        execute(box) {
            let args = try Arguments(call)
            let level = TrustPinAttestLogLevel(wireName: try args.requireString(Arg.logLevel))
            let instanceId = args.optionalString(Arg.instanceId)
            return {
                try TrustPinAttestPlugin.instance(id: instanceId).set(logLevel: level)
                return nil
            }
        }
    }

    /// Forwards the instance's state changes and events to Dart, then sets it
    /// up. The listeners come first so the events of setup itself reach Dart.
    static func setUp(
        _ configuration: TrustPinAttestConfiguration,
        debugToken: String?,
        instanceId: String?
    ) async throws {
        exposeDebugToken(debugToken)
        let attest = try instance(id: instanceId)
        let id = instanceId ?? defaultInstanceId
        attest.setStateListener { state in
            InstanceEventsStreamHandler.states.send { state.wireMap(instanceId: id) }
        }
        attest.setEventListener { event in
            InstanceEventsStreamHandler.events.send { event.wireMap(instanceId: id) }
        }
        try await attest.setup(configuration)
    }

    /// Returns the named instance, or the default one when `id` is nil or
    /// empty. Static so it never captures `self` in a `@Sendable` closure.
    static func instance(id: String?) throws -> TrustPinAttest {
        guard let id, !id.isEmpty else { return TrustPinAttest.default }
        return try TrustPinAttest.instance(id: id)
    }
}

/// Makes the debug token visible to TrustPinAttestKit, which reads
/// `TRUSTPIN_DEBUG_TOKEN` from the process environment, and only in its
/// simulator build. `flutter run` doesn't apply Xcode scheme variables, so
/// the token comes from the Dart configuration instead. Device and macOS
/// builds don't contain this code; a token already set in the scheme wins.
private func exposeDebugToken(_ token: String?) {
    #if targetEnvironment(simulator)
    guard let token, !token.isEmpty else { return }
    setenv("TRUSTPIN_DEBUG_TOKEN", token, 0)
    #endif
}
