import Foundation

/// Resumes a continuation exactly once, whichever side finishes first.
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?

    init(_ continuation: CheckedContinuation<T, any Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<T, any Error>) {
        let pending: CheckedContinuation<T, any Error>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(with: result)
    }
}

/// Like `withTimeout`, but returns at the deadline even when `operation` ignores
/// cancellation (a read stuck on a pipe). The operation is cancelled and left to finish alone.
func withDeadline<T: Sendable>(
    _ seconds: TimeInterval,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        let once = ResumeOnce(continuation)
        let work = Task { try await operation() }
        let timer = Task {
            try await Task.sleep(for: .seconds(seconds))
            work.cancel()
            once.resume(.failure(UsageError.timeout))
        }
        Task {
            let result = await work.result
            timer.cancel()
            once.resume(result)
        }
    }
}
