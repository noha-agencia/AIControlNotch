import Foundation

/// Codex limits from either source, before they become a snapshot.
public struct CodexLimits: Equatable, Sendable {
    public let windows: [UsageWindow]
    public let planLabel: String?
    /// When the data was produced; only rollout lines carry it.
    public let timestamp: Date?
}

/// Parses the app-server reply (camelCase) and rollout log lines (snake_case).
public enum CodexRateLimitParser {
    static let codexBucket = "codex"
    static let knownPlans = [
        "free": "Free", "go": "Go", "plus": "Plus", "pro": "Pro", "prolite": "Pro Lite",
        "team": "Team", "business": "Business", "enterprise": "Enterprise", "edu": "Edu",
    ]

    /// Parses the `account/rateLimits/read` reply line.
    public static func parseAppServerResponse(_ line: Data) throws -> CodexLimits {
        guard let envelope = try? JSONDecoder().decode(AppServerEnvelope.self, from: line) else {
            throw UsageError.invalidFormat("codex app-server reply is not JSON")
        }
        if let error = envelope.error {
            throw UsageError.processFailed("codex app-server error \(error.code ?? 0)")
        }
        let bucket = envelope.result?.rateLimitsByLimitId?[codexBucket] ?? nil
        guard let snapshot = bucket ?? envelope.result?.rateLimits else {
            throw UsageError.invalidFormat("codex app-server reply has no rateLimits")
        }
        let windows = [snapshot.primary, snapshot.secondary].compactMap { raw in
            raw.flatMap { window(used: $0.usedPercent, minutes: $0.windowDurationMins, resetsAt: $0.resetsAt) }
        }
        guard !windows.isEmpty else { throw UsageError.invalidFormat("codex app-server reply has no windows") }
        return CodexLimits(windows: windows.sorted { $0.kind < $1.kind }, planLabel: planLabel(snapshot.planType), timestamp: nil)
    }

    /// Parses one rollout line; `nil` unless it is a `token_count` event with limits.
    public static func parseRolloutLine(_ line: Data) -> CodexLimits? {
        guard
            let parsed = try? rolloutDecoder.decode(RolloutLine.self, from: line),
            parsed.payload?.type == "token_count",
            let limits = parsed.payload?.rateLimits
        else { return nil }
        let windows = [limits.primary, limits.secondary].compactMap { raw in
            raw.flatMap { window(used: $0.usedPercent, minutes: $0.windowMinutes, resetsAt: $0.resetsAt) }
        }
        guard !windows.isEmpty else { return nil }
        return CodexLimits(
            windows: windows.sorted { $0.kind < $1.kind },
            planLabel: planLabel(limits.planType),
            timestamp: parsed.timestamp.flatMap(ISODate.parse)
        )
    }

    /// "prolite" → "Pro Lite"; unknown names become title case; "unknown" → nil.
    public static func planLabel(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty, raw != "unknown" else { return nil }
        return knownPlans[raw] ?? raw.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    /// Windows without a duration or a real reset time cannot be classified or shown.
    private static func window(used: Double, minutes: Int?, resetsAt: Double?) -> UsageWindow? {
        guard let minutes, minutes > 0, let resetsAt, resetsAt > 0 else { return nil }
        return UsageWindow(
            kind: WindowClassifier.kind(minutes: minutes),
            usedPercent: used,
            durationMinutes: minutes,
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
    }

    private static let rolloutDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

private struct AppServerEnvelope: Decodable {
    let result: AppServerResult?
    let error: AppServerError?
}

/// Only the code is kept: the message can carry upstream response text.
private struct AppServerError: Decodable {
    let code: Int?
}

private struct AppServerResult: Decodable {
    let rateLimits: AppServerSnapshot?
    let rateLimitsByLimitId: [String: AppServerSnapshot?]?
}

private struct AppServerSnapshot: Decodable {
    let primary: AppServerWindow?
    let secondary: AppServerWindow?
    let planType: String?
}

private struct AppServerWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
}

private struct RolloutLine: Decodable {
    let timestamp: String?
    let payload: RolloutPayload?
}

private struct RolloutPayload: Decodable {
    let type: String?
    let rateLimits: RolloutSnapshot?
}

private struct RolloutSnapshot: Decodable {
    let primary: RolloutWindow?
    let secondary: RolloutWindow?
    let planType: String?
}

private struct RolloutWindow: Decodable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Double?
}
