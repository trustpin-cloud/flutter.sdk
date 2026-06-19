#if canImport(Flutter)
@preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
@preconcurrency import FlutterMacOS
#endif
import Foundation

#if os(macOS)
private struct ResultPayload: @unchecked Sendable {
    let value: Any?
}
#endif

/// Boxes the ObjC-provided `FlutterResult` so it can be captured by
/// `@Sendable` closures, and guarantees the underlying block is invoked at
/// most once regardless of how many code paths try to deliver a value.
///
/// On iOS the plugin's `MethodChannel` is registered with a background
/// `TaskQueue`, so `FlutterResult` is safe to invoke from any thread. On macOS
/// `FlutterEngine` does not yet support background task queues, so `deliver(_:)`
/// hops to the main actor before invoking the result block. Handlers can
/// therefore call `box.deliver(...)` from any context without worrying about
/// isolation on either platform.
final class ResultBox: @unchecked Sendable {
    private let _result: FlutterResult
    private let lock = NSLock()
    private var delivered = false

    init(_ result: @escaping FlutterResult) {
        self._result = result
    }

    /// Delivers `value` to the Flutter side at most once. Subsequent calls
    /// are no-ops, which makes the box safe to share across race-y code
    /// paths (e.g. a timeout that fires after the operation completes).
    func deliver(_ value: Any?) {
        lock.lock()
        let alreadyDelivered = delivered
        delivered = true
        lock.unlock()

        guard !alreadyDelivered else { return }

        #if os(macOS)
        let payload = ResultPayload(value: value)
        Task { @MainActor [_result, payload] in
            _result(payload.value)
        }
        #else
        _result(value)
        #endif
    }
}
