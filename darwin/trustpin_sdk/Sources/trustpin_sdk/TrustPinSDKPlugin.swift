#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Flutter method-channel entry point. All handler logic lives in
/// `MethodHandlers.swift`; this file owns only the registration and the
/// method-name dispatch.
public final class TrustPinSDKPlugin: NSObject, FlutterPlugin {

    private static let channelName = "cloud.trustpin.sdk.flutter"
    private static let validationEventsChannelName =
        "cloud.trustpin.sdk.flutter/validation_events"
    private static let logEventsChannelName =
        "cloud.trustpin.sdk.flutter/log_events"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel: FlutterMethodChannel
        #if os(iOS)
        // iOS registers the channel on a background task queue, so handlers
        // and result callbacks run off the platform thread.
        let taskQueue = registrar.messenger().makeBackgroundTaskQueue?()
        channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger(),
            codec: FlutterStandardMethodCodec.sharedInstance(),
            taskQueue: taskQueue
        )
        #else
        // macOS FlutterEngine does not yet implement `makeBackgroundTaskQueue`
        // (the protocol method is @optional with a TODO in the framework, and
        // calling it through the relay crashes with an unrecognized selector).
        // Result delivery therefore must go through the main thread — handled
        // inside `ResultBox.deliver(_:)`.
        channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger
        )
        #endif
        registrar.addMethodCallDelegate(TrustPinSDKPlugin(), channel: channel)

        // Validation-verdict telemetry and SDK log routing. Both event
        // channels stay on the main thread; the stream handlers hop every
        // event to the main queue before touching the sink.
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        let validationEventsChannel = FlutterEventChannel(
            name: validationEventsChannelName,
            binaryMessenger: messenger
        )
        validationEventsChannel.setStreamHandler(ValidationEventsStreamHandler())

        let logEventsChannel = FlutterEventChannel(
            name: logEventsChannelName,
            binaryMessenger: messenger
        )
        logEventsChannel.setStreamHandler(LogEventsStreamHandler())
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
