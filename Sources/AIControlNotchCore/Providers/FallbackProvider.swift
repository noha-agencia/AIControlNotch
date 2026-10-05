import Foundation

/// What happened when reading one AI: the snapshot (if any) and why sources failed.
public struct FallbackOutcome: Sendable {
    public let snapshot: ProviderSnapshot?
    public let primaryError: UsageError?
    public let fallbackError: UsageError?

    /// Neither source answered before the coordinator's deadline.
    static func timedOut(skipPrimary: Bool) -> FallbackOutcome {
        FallbackOutcome(snapshot: nil, primaryError: skipPrimary ? nil : .timeout, fallbackError: .timeout)
    }
}

/// Tries the primary source, then the fallback if there is one. Alerts treat both the same.
public struct FallbackProvider: UsageProvider {
    public let primary: any UsageProvider
    public let fallback: (any UsageProvider)?

    public init(primary: any UsageProvider, fallback: (any UsageProvider)? = nil) {
        self.primary = primary
        self.fallback = fallback
    }

    public var provider: ProviderID { primary.provider }
    public var source: DataSource { primary.source }
    public var policy: FetchPolicy { primary.policy }

    /// `skipPrimary` is set while the primary source is backing off.
    public func fetch(skipPrimary: Bool) async -> FallbackOutcome {
        var primaryError: UsageError?
        if !skipPrimary {
            do {
                return FallbackOutcome(snapshot: try await primary.fetch(), primaryError: nil, fallbackError: nil)
            } catch {
                primaryError = Self.usageError(error)
            }
        }
        guard let fallback else {
            return FallbackOutcome(snapshot: nil, primaryError: primaryError, fallbackError: nil)
        }
        do {
            return FallbackOutcome(snapshot: try await fallback.fetch(), primaryError: primaryError, fallbackError: nil)
        } catch {
            return FallbackOutcome(snapshot: nil, primaryError: primaryError, fallbackError: Self.usageError(error))
        }
    }

    public func fetch() async throws -> ProviderSnapshot {
        let outcome = await fetch(skipPrimary: false)
        if let snapshot = outcome.snapshot { return snapshot }
        throw outcome.primaryError ?? outcome.fallbackError ?? UsageError.processFailed("no source")
    }

    static func usageError(_ error: Error) -> UsageError {
        (error as? UsageError) ?? .processFailed(String(describing: type(of: error)))
    }
}
