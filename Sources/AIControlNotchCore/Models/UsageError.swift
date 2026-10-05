import Foundation

/// Why a data source could not produce a snapshot.
public enum UsageError: Error, Equatable, Sendable {
    case http(status: Int, retryAfter: TimeInterval?)
    case network(String)
    case timeout
    case invalidFormat(String)
    case notFound(String)
    case processFailed(String)
    /// A script provider failed; never retried faster than its own interval.
    case script(ScriptFailure)

    /// Failures that mean "ask again later, more slowly".
    public var triggersBackoff: Bool {
        switch self {
        case .network, .timeout, .invalidFormat: true
        case let .http(status, _): status == 429 || (500...599).contains(status)
        case .notFound, .processFailed, .script: false
        }
    }

    public var retryAfter: TimeInterval? {
        if case let .http(_, retryAfter) = self { return retryAfter }
        return nil
    }

    /// Short, secret-free text for the log file.
    public var logDescription: String {
        switch self {
        case let .http(status, retryAfter): "http \(status)" + (retryAfter.map { " retry-after \(Int($0))s" } ?? "")
        case let .network(reason): "network \(reason)"
        case .timeout: "timeout"
        case let .invalidFormat(reason): "invalid format: \(reason)"
        case let .notFound(what): "not found: \(what)"
        case let .processFailed(reason): "process failed: \(reason)"
        case let .script(failure): "script \(failure)"
        }
    }
}
