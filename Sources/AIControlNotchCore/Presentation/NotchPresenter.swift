import Foundation

/// Turns snapshots into what each notch state draws.
public struct NotchPresenter: Sendable {
    static let segmentCount = 10
    static let dangerPercent = 90
    static let refreshOnOpenAfter: TimeInterval = 3 * 60
    static let missingValue = "–"
    static let legendTones: [PaceTone] = [.ok, .warn, .danger]
    /// Rows plus messages the open panel shows at most (six models, two lines each).
    public static let maxOpenLines = 12

    public let copy: Copy

    public init(copy: Copy = Copy()) {
        self.copy = copy
    }

    public var catalog: ProviderCatalog { copy.catalog }

    /// One side per pinned model: left first, then right.
    public func restSides(_ snapshots: [ProviderID: ProviderSnapshot], now: Date) -> [RestSide] {
        catalog.pinned.map { rest(snapshots[$0], provider: $0, now: now) }
    }

    public func rest(_ snapshot: ProviderSnapshot?, provider: ProviderID, now: Date) -> RestSide {
        guard let snapshot, let percent = snapshot.maxPercent else {
            return RestSide(provider: provider, percentText: Self.missingValue, dot: nil)
        }
        let stale = PaceCalculator.isStale(fetchedAt: snapshot.fetchedAt, now: now)
        let dot = stale ? DotTone.stale : DotTone(PaceCalculator.worst(snapshot.windows, now: now))
        return RestSide(provider: provider, percentText: "\(percent)", dot: dot)
    }

    public func open(
        _ snapshots: [ProviderID: ProviderSnapshot], issues: [ProviderID: ProviderIssue], now: Date
    ) -> OpenContent {
        let oldest = catalog.ids.compactMap { snapshots[$0]?.fetchedAt }.min()
        let sections = catalog.ids.map { section($0, snapshot: snapshots[$0], issue: issues[$0], now: now) }
        return OpenContent(
            title: copy.panelTitle,
            updated: copy.updatedAgo(oldest, now: now),
            updatedIsStale: oldest.map { PaceCalculator.isStale(fetchedAt: $0, now: now) } ?? false,
            sections: OpenPanelBudget.fit(sections, maxLines: Self.maxOpenLines),
            legend: Self.legendTones.map { LegendItem(tone: $0, text: copy.legend($0)) }
        )
    }

    public func alert(_ alert: ThresholdAlert, now: Date) -> AlertContent {
        AlertContent(
            provider: alert.provider,
            title: copy.alertTitle(alert),
            subtitle: copy.alertSubtitle(alert, now: now),
            percent: alert.bucket,
            fromPercent: max(0, alert.bucket - 10),
            isDanger: alert.bucket >= Self.dangerPercent
        )
    }

    public static func segments(for percent: Int) -> [Double] {
        (0..<segmentCount).map { index in
            min(1, max(0, Double(percent - index * 10) / 10))
        }
    }

    public static func shouldRefreshOnOpen(lastRefresh: Date?, now: Date) -> Bool {
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) > refreshOnOpenAfter
    }

    private func section(
        _ provider: ProviderID, snapshot: ProviderSnapshot?, issue: ProviderIssue?, now: Date
    ) -> OpenSection {
        let rows = (snapshot?.windows ?? []).enumerated().map { index, window in
            row(provider, window: window, first: index == 0, now: now)
        }
        let message = issue.map { copy.issueMessage($0, provider: provider) } ?? (rows.isEmpty ? copy.loading : nil)
        return OpenSection(provider: provider, planLabel: snapshot?.planLabel, rows: rows, message: message)
    }

    private func row(_ provider: ProviderID, window: UsageWindow, first: Bool, now: Date) -> OpenRow {
        let percent = window.displayPercent
        return OpenRow(
            provider: provider,
            kind: window.kind,
            showsProvider: first,
            label: copy.windowLabel(window),
            dot: DotTone(PaceCalculator.tone(window, now: now)),
            percent: percent,
            segments: Self.segments(for: percent),
            isDanger: percent >= Self.dangerPercent,
            reset: copy.resetLine(window, now: now)
        )
    }
}
