@preconcurrency import Flutter
import Foundation

// MARK: - Result boxing

/// Boxes the ObjC-provided FlutterResult so it can be captured by @Sendable closures.
/// Thread-safe wrapper that guarantees the underlying result block is invoked at most once.
///
/// The plugin's MethodChannel is registered with a background TaskQueue, which means
/// FlutterResult is safe to invoke from any thread — no MainActor hop required.
final class ResultBox: @unchecked Sendable {
    private let _result: FlutterResult
    private let callOnce = CallOnce()

    init(_ result: @escaping FlutterResult) {
        self._result = result
    }

    /// Call the Flutter result exactly once. Safe to invoke from any thread because
    /// the channel uses a background TaskQueue.
    func callResult(_ value: Any?) {
        callOnce.perform {
            _result(value)
        }
    }
}

// MARK: - Call Once Helper

/// Helper to ensure a block is executed only once in a thread-safe manner.
private final class CallOnce: @unchecked Sendable {
    private var executed = false
    private let lock = NSLock()

    func perform(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard !executed else { return }
        executed = true
        block()
    }
}
