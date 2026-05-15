@preconcurrency import FlutterMacOS
import Foundation

private struct ResultPayload: @unchecked Sendable {
    let value: Any?
}

/// Boxes the ObjC-provided `FlutterResult` so it can be captured by
/// `@Sendable` closures, and guarantees the underlying block is invoked at
/// most once regardless of how many code paths try to deliver a value.
///
/// On macOS, `FlutterEngine` does not yet support background task queues, so
/// `deliver(_:)` hops to the main actor before invoking the result block.
/// Handlers can therefore call `box.deliver(...)` from any context without
/// worrying about isolation.
final class ResultBox: @unchecked Sendable {
    private let _result: FlutterResult
    private let lock = NSLock()
    private var delivered = false

    init(_ result: @escaping FlutterResult) {
        self._result = result
    }

    /// Delivers `value` to the Flutter side at most once on the main actor.
    /// Subsequent calls are no-ops.
    func deliver(_ value: Any?) {
        lock.lock()
        let alreadyDelivered = delivered
        delivered = true
        lock.unlock()

        guard !alreadyDelivered else { return }
        let payload = ResultPayload(value: value)
        Task { @MainActor [_result, payload] in
            _result(payload.value)
        }
    }
}
