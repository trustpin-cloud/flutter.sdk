#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinKit

/// Bridges the native SDK's global `TrustPinLogSink` onto a Flutter event
/// channel.
///
/// The native sink is installed when the first Dart subscription starts
/// (`onListen`) and removed when the last one cancels (`onCancel`); while no
/// one listens the SDK keeps logging to its platform default. Per-instance
/// verbosity is still controlled by `TrustPin.set(logLevel:)` — the sink only
/// receives already-filtered messages.
final class LogEventsStreamHandler: NSObject, FlutterStreamHandler {

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        TrustPin.setLogSink(LogEventsForwarder(sink: events))
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        TrustPin.setLogSink(nil)
        return nil
    }
}

/// Forwards SDK log messages to the Dart event sink.
///
/// Messages arrive synchronously from SDK internals, including threads
/// performing TLS handshakes, while the event sink must be invoked on the
/// platform main thread — every event therefore hops through the main queue.
/// The sink contract requires callbacks to stay fast and non-blocking; an
/// async dispatch satisfies that.
///
/// `@unchecked Sendable`: the captured `FlutterEventSink` is not `Sendable`,
/// but it is only ever invoked from the main queue.
private final class LogEventsForwarder: TrustPinLogSink, @unchecked Sendable {

    private let sink: FlutterEventSink

    init(sink: @escaping FlutterEventSink) {
        self.sink = sink
    }

    func log(level: TrustPinLogLevel, instanceId: String, message: String) {
        // `[String: String]` keeps the payload `Sendable` across the hop to
        // the main queue.
        let event: [String: String] = [
            EventKey.level: wireName(for: level),
            EventKey.instanceId: instanceId,
            EventKey.message: message,
        ]
        DispatchQueue.main.async { [sink] in
            sink(event)
        }
    }
}

/// The wire string for a log level. Keep in sync with the Dart
/// `TrustPinLogLevel.value` strings (`.none` never reaches a sink — it only
/// configures filtering).
private func wireName(for level: TrustPinLogLevel) -> String {
    switch level {
    case .none:  return "none"
    case .error: return "error"
    case .info:  return "info"
    case .debug: return "debug"
    @unknown default: return "info"
    }
}
