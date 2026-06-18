@preconcurrency import FlutterMacOS
import AppKit

/// Flutter method-channel entry point. All handler logic lives in
/// `MethodHandlers.swift`; this file owns only the registration and the
/// method-name dispatch.
public final class TrustPinSDKPlugin: NSObject, FlutterPlugin {

    private static let channelName = "cloud.trustpin.sdk.flutter"

    public static func register(with registrar: FlutterPluginRegistrar) {
        // macOS FlutterEngine does not yet implement `makeBackgroundTaskQueue`
        // (the protocol method is @optional with a TODO in the framework, and
        // calling it through the relay crashes with an unrecognized selector).
        // Result delivery therefore must go through the main thread — handled
        // inside `ResultBox.deliver(_:)`.
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger
        )
        registrar.addMethodCallDelegate(TrustPinSDKPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let box = ResultBox(result)
        switch call.method {
        case Method.setup:                  handleSetup(call, box: box)
        case Method.setupWithNativeBundle:  handleSetupWithNativeBundle(call, box: box)
        case Method.verify:                 handleVerify(call, box: box)
        case Method.setLogLevel:            handleSetLogLevel(call, box: box)
        case Method.fetchCertificate:       handleFetchCertificate(call, box: box)
        case Method.validateConnection:     handleValidateConnection(call, box: box)
        case Method.awaitConfiguration:     handleAwaitConfiguration(call, box: box)
        case Method.isConfigurationLoaded:  handleIsConfigurationLoaded(call, box: box)
        default:                            box.deliver(FlutterMethodNotImplemented)
        }
    }
}
