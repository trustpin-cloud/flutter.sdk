import Foundation

/// Thrown when an operation exceeds its caller-provided deadline.
struct OperationTimeoutError: Error {}

/// Races `operation` against a sleep of `milliseconds`. When the sleep wins,
/// throws `OperationTimeoutError` and cancels the operation task.
func withTimeout<T: Sendable>(
    milliseconds: Int,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            let nanos = UInt64(milliseconds) * 1_000_000
            try await Task.sleep(nanoseconds: nanos)
            throw OperationTimeoutError()
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else {
            throw CancellationError()
        }
        return first
    }
}

/// Runs `operation` directly, or under a timeout when `milliseconds` is
/// positive. Convenience wrapper used by handlers that expose `timeoutMs`.
func withOptionalTimeout<T: Sendable>(
    milliseconds: Int?,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard let milliseconds, milliseconds > 0 else {
        return try await operation()
    }
    return try await withTimeout(milliseconds: milliseconds, operation: operation)
}
