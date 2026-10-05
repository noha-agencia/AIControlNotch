import Foundation

/// Runs `operation`, failing with `UsageError.timeout` if it takes longer than `seconds`.
/// The operation must stop when cancelled (stream iteration and sleeps do).
func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw UsageError.timeout
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw UsageError.timeout }
        return first
    }
}
