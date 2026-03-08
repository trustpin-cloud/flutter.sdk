@preconcurrency import FlutterMacOS
import Foundation

// MARK: - Result boxing

/// Boxes the ObjC-provided FlutterResult so it can be captured by @Sendable closures.
/// Thread-safe wrapper that ensures result is called only once on the main actor.
final class ResultBox: @unchecked Sendable {
    private let _result: FlutterResult
    private let callOnce = CallOnce()

    init(_ result: @escaping FlutterResult) {
        self._result = result
    }

    /// Provides direct access to result for backward compatibility.
    /// Prefer using callResult() for better safety.
    var result: FlutterResult {
        return _result
    }

    /// Call the Flutter result exactly once, safely on MainActor.
    @MainActor
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
