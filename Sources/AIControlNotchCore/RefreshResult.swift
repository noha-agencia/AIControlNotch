import Foundation

/// What the UI needs after a refresh: current numbers, new 10% alerts, problems.
public struct RefreshResult: Equatable, Sendable {
    public let snapshots: [ProviderID: ProviderSnapshot]
    public let alerts: [ThresholdAlert]
    public let issues: [ProviderID: ProviderIssue]

    public init(
        snapshots: [ProviderID: ProviderSnapshot] = [:],
        alerts: [ThresholdAlert] = [],
        issues: [ProviderID: ProviderIssue] = [:]
    ) {
        self.snapshots = snapshots
        self.alerts = alerts
        self.issues = issues
    }
}

/// The result of reading one AI during a refresh, before it is merged into state.
struct ProviderStep: Sendable {
    let provider: ProviderID
    let backoffKey: String
    let backoff: BackoffState
    let snapshot: ProviderSnapshot?
    let issue: ProviderIssue?
}
