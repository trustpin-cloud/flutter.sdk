@preconcurrency import Flutter
import Foundation

/// Boxes the ObjC-provided `FlutterResult` so it can be captured by
/// `@Sendable` closures, and guarantees the underlying block is invoked at
/// most once regardless of how many code paths try to deliver a value.
///
/// The plugin's `MethodChannel` is registered with a background `TaskQueue`,
/// so `FlutterResult` is safe to invoke from any thread — no MainActor hop is
/// required on iOS.
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
        _result(value)
    }
}
