@preconcurrency import Flutter
import UIKit

/// Flutter method-channel entry point. All handler logic lives in
/// `MethodHandlers.swift`; this file owns only the registration and the
/// method-name dispatch.
public final class TrustPinSDKPlugin: NSObject, FlutterPlugin {

    private static let channelName = "cloud.trustpin.sdk.flutter"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let taskQueue = registrar.messenger().makeBackgroundTaskQueue?()
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger(),
            codec: FlutterStandardMethodCodec.sharedInstance(),
            taskQueue: taskQueue
        )
        registrar.addMethodCallDelegate(TrustPinSDKPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let box = ResultBox(result)
        switch call.method {
        case Method.setup:               handleSetup(call, box: box)
        case Method.verify:              handleVerify(call, box: box)
        case Method.setLogLevel:         handleSetLogLevel(call, box: box)
        case Method.fetchCertificate:    handleFetchCertificate(call, box: box)
        case Method.validateConnection:  handleValidateConnection(call, box: box)
        default:                         box.deliver(FlutterMethodNotImplemented)
        }
    }
}
