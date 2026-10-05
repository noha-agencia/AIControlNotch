import Foundation

/// Keeps the open panel on screen: past `maxLines`, the largest sections give up their
/// least-used rows first. Every model keeps at least one row; messages always stay.
enum OpenPanelBudget {
    static func fit(_ sections: [OpenSection], maxLines: Int) -> [OpenSection] {
        let lines = sections.reduce(0) { $0 + $1.lineCount }
        guard lines > maxLines, let index = largestTrimmable(sections) else { return sections }
        let trimmed = sections.enumerated().map { $0.offset == index ? dropLeastUsed($0.element) : $0.element }
        return fit(trimmed, maxLines: maxLines)
    }

    /// The section with the most rows (the later one on a tie), if any has more than one.
    private static func largestTrimmable(_ sections: [OpenSection]) -> Int? {
        let candidates = sections.indices.filter { sections[$0].rows.count > 1 }
        return candidates.max { (sections[$0].rows.count, $0) < (sections[$1].rows.count, $1) }
    }

    /// Removes the least-used row (the later one on a tie) and lets the new first row name the model.
    private static func dropLeastUsed(_ section: OpenSection) -> OpenSection {
        let rows = section.rows
        guard let least = rows.indices.min(by: { (rows[$0].percent, -$0) < (rows[$1].percent, -$1) }) else { return section }
        let kept = rows.indices.filter { $0 != least }.map { rows[$0] }
        let named = kept.enumerated().map { $0.element.showingProvider($0.offset == 0) }
        return OpenSection(provider: section.provider, planLabel: section.planLabel, rows: named, message: section.message)
    }
}

extension OpenRow {
    func showingProvider(_ shows: Bool) -> OpenRow {
        OpenRow(
            provider: provider, kind: kind, showsProvider: shows, label: label, dot: dot,
            percent: percent, segments: segments, isDanger: isDanger, reset: reset
        )
    }
}
