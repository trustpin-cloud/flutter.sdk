#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation
import TrustPinKit

/// Bridges the native SDK's global `TrustPinValidationListener` onto a
/// Flutter event channel.
///
/// The native listener is installed when the first Dart subscription starts
/// (`onListen`) and removed when the last one cancels (`onCancel`) — the Dart
/// side multiplexes all of its listeners onto one channel subscription.
final class ValidationEventsStreamHandler: NSObject, FlutterStreamHandler {

    private var forwarder: ValidationEventsForwarder?

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        let forwarder = ValidationEventsForwarder(sink: events)
        self.forwarder = forwarder
        TrustPin.setValidationListener(forwarder)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        TrustPin.setValidationListener(nil)
        forwarder = nil
        return nil
    }
}

/// Forwards validation verdicts to the Dart event sink.
///
/// Verdict callbacks arrive synchronously from SDK internals, including
/// threads performing TLS handshakes, while the event sink must be invoked on
/// the platform main thread — every event therefore hops through the main
/// queue. The listener contract requires callbacks to stay fast and
/// non-blocking; an async dispatch satisfies that.
///
/// `@unchecked Sendable`: the captured `FlutterEventSink` is not `Sendable`,
/// but it is only ever invoked from the main queue.
private final class ValidationEventsForwarder: TrustPinValidationListener, @unchecked Sendable {

    private let sink: FlutterEventSink

    init(sink: @escaping FlutterEventSink) {
        self.sink = sink
    }

    func onValidationFailure(
        instanceId: String,
        domain: String,
        error: TrustPinErrors,
        presentedCertificate: Data
    ) {
        deliver([
            EventKey.instanceId: instanceId,
            EventKey.domain: domain,
            EventKey.code: mapTrustPinError(error),
            EventKey.message: error.localizedDescription,
            EventKey.certificatePem: pemEncodedCertificate(presentedCertificate),
        ])
    }

    func onValidationSuccess(instanceId: String, domain: String) {
        // The absent `code` key decodes as null on the Dart side, which marks
        // a success event.
        deliver([
            EventKey.instanceId: instanceId,
            EventKey.domain: domain,
        ])
    }

    /// `[String: String]` keeps the payload `Sendable` across the hop to the
    /// main queue.
    private func deliver(_ event: [String: String]) {
        DispatchQueue.main.async { [sink] in
            sink(event)
        }
    }
}

/// Encodes DER certificate bytes as a PEM string (64-character Base64 lines
/// between BEGIN/END markers).
private func pemEncodedCertificate(_ der: Data) -> String {
    let base64 = der.base64EncodedString(
        options: [.lineLength64Characters, .endLineWithLineFeed]
    )
    return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
}
