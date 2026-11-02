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

/// Flutter method-channel entry point of the attestation plugin. All handler
/// logic lives in `MethodHandlers.swift`; this file owns only the
/// registration and the method-name dispatch.
public final class TrustPinAttestPlugin: NSObject, FlutterPlugin {

    private static let channelName = "cloud.trustpin.attest.flutter"
    private static let stateEventsChannelName = "cloud.trustpin.attest.flutter/state_events"
    private static let eventsChannelName = "cloud.trustpin.attest.flutter/events"
    private static let logEventsChannelName = "cloud.trustpin.attest.flutter/log_events"

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
        let messenger = registrar.messenger()
        #else
        // macOS FlutterEngine does not implement `makeBackgroundTaskQueue`;
        // `ResultBox.deliver(_:)` hops to the main thread instead.
        channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger
        )
        let messenger = registrar.messenger
        #endif
        registrar.addMethodCallDelegate(TrustPinAttestPlugin(), channel: channel)

        FlutterEventChannel(name: stateEventsChannelName, binaryMessenger: messenger)
            .setStreamHandler(InstanceEventsStreamHandler.states)
        FlutterEventChannel(name: eventsChannelName, binaryMessenger: messenger)
            .setStreamHandler(InstanceEventsStreamHandler.events)
        FlutterEventChannel(name: logEventsChannelName, binaryMessenger: messenger)
            .setStreamHandler(LogEventsStreamHandler())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let box = ResultBox(result)
        switch call.method {
        case Method.setup:                  handleSetup(call, box: box)
        case Method.setupWithNativeBundle:  handleSetupWithNativeBundle(call, box: box)
        case Method.prefetch:               handlePrefetch(call, box: box)
        case Method.getToken:               handleGetToken(call, box: box)
        case Method.attestationHeaders:     handleAttestationHeaders(call, box: box)
        case Method.assertionHeaders:       handleAssertionHeaders(call, box: box)
        case Method.setTokenBinding:        handleSetTokenBinding(call, box: box)
        case Method.bindToHeader:           handleBindToHeader(call, box: box)
        case Method.state:                  handleState(call, box: box)
        case Method.reset:                  handleReset(call, box: box)
        case Method.setLogLevel:            handleSetLogLevel(call, box: box)
        default:                            box.deliver(FlutterMethodNotImplemented)
        }
    }
}
