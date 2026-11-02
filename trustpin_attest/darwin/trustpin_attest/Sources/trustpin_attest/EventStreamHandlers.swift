#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinAttestKit

/// Bridges one kind of per-instance native callback (state changes or
/// events) of every instance this plugin set up onto one Flutter event
/// channel.
///
/// A native instance has a single state listener and a single event
/// listener, so the plugin owns them: they are registered when the instance
/// is set up and forward to the current Dart sink, or nowhere while no one
/// listens. Dart filters by instance id; native listeners don't replay, so
/// Dart reads the current state itself.
///
/// `@unchecked Sendable`: the sink is guarded by `lock` and only invoked on
/// the main queue.
final class InstanceEventsStreamHandler: NSObject, FlutterStreamHandler, @unchecked Sendable {

    /// State changes, on `cloud.trustpin.attest.flutter/state_events`.
    static let states = InstanceEventsStreamHandler()

    /// Events, on `cloud.trustpin.attest.flutter/events`.
    static let events = InstanceEventsStreamHandler()

    private let lock = NSLock()
    private var sink: FlutterEventSink?

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        lock.lock()
        sink = events
        lock.unlock()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        lock.lock()
        sink = nil
        lock.unlock()
        return nil
    }

    /// Sends the map `build` returns, built on the main queue and only while
    /// Dart listens: the native values are Sendable, the dictionary isn't.
    func send(_ build: @escaping @Sendable () -> [String: Any]) {
        lock.lock()
        let sink = self.sink
        lock.unlock()
        guard let sink else { return }
        DispatchQueue.main.async {
            sink(build())
        }
    }
}

/// Bridges the attestation module's process-wide log sink onto a Flutter
/// event channel: installed on the first Dart subscription, removed after
/// the last one cancels. Per-instance verbosity stays with
/// `TrustPinAttest.set(logLevel:)`.
final class LogEventsStreamHandler: NSObject, FlutterStreamHandler {

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        TrustPinAttest.setLogSink(LogEventsForwarder(sink: events))
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        TrustPinAttest.setLogSink(nil)
        return nil
    }
}

/// Forwards log messages to the Dart event sink through the main queue.
///
/// `@unchecked Sendable`: the captured `FlutterEventSink` is only ever
/// invoked from the main queue.
private final class LogEventsForwarder: TrustPinAttestLogSink, @unchecked Sendable {

    private let sink: FlutterEventSink

    init(sink: @escaping FlutterEventSink) {
        self.sink = sink
    }

    func log(level: TrustPinAttestLogLevel, instanceId: String, message: String) {
        let event: [String: String] = [
            EventKey.level: level.wireName,
            EventKey.instanceId: instanceId,
            EventKey.message: message,
        ]
        DispatchQueue.main.async { [sink] in
            sink(event)
        }
    }
}
