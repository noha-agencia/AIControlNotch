import AIControlNotchCore
import SwiftUI

/// Open panel (direction B): one row per limit with ruler, percent and renewal.
struct OpenView: View {
    enum Column {
        static let who: CGFloat = 78
        static let window: CGFloat = 92
        static let percent: CGFloat = 50
        static let gap: CGFloat = 14
    }

    static let gridPadding: CGFloat = 24
    static let topPadding: CGFloat = 22

    let content: OpenContent
    let frame: NotchFrame
    let notchHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(content.title).foregroundStyle(Theme.ink3)
                Spacer()
                Text(content.updated).foregroundStyle(content.updatedIsStale ? Theme.warn : Theme.ink3)
            }
            .font(Theme.font(11, 600))
            .tracking(0.22)
            .padding(.horizontal, Self.topPadding)
            .frame(height: notchHeight)

            VStack(spacing: 0) {
                ForEach(Array(content.sections.enumerated()), id: \.element.id) { index, section in
                    if index > 0 { Theme.line.frame(height: 1) }
                    SectionRows(section: section)
                }
            }
            .padding(.horizontal, Self.gridPadding)
            .padding(.top, NotchLayout.gridTopPadding)

            Legend(items: content.legend)
                .padding(.horizontal, Self.gridPadding)
                .padding(.top, 8)
        }
        .frame(width: frame.width, alignment: .topLeading)
    }
}

private struct SectionRows: View {
    let section: OpenSection

    var body: some View {
        ForEach(section.rows) { row in
            LimitRow(row: row)
        }
        if let message = section.message {
            HStack(spacing: OpenView.Column.gap) {
                Who(provider: section.provider, visible: section.rows.isEmpty)
                Text(message)
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .frame(height: NotchLayout.rowHeight)
        }
    }
}

private struct Who: View {
    let provider: ProviderID
    let visible: Bool
    @Environment(\.providerCatalog) private var catalog

    var body: some View {
        HStack(spacing: 7) {
            if visible {
                LogoView(provider: provider, size: 13)
                Text(catalog.descriptor(provider).displayName)
                    .font(Theme.font(13, 600))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(width: OpenView.Column.who, alignment: .leading)
    }
}

private struct LimitRow: View {
    let row: OpenRow
    @Environment(\.providerCatalog) private var catalog

    var body: some View {
        HStack(spacing: OpenView.Column.gap) {
            Who(provider: row.provider, visible: row.showsProvider)
            HStack(spacing: 7) {
                Dot(color: Theme.dot(row.dot))
                Text(row.label).font(Theme.font(12)).foregroundStyle(Theme.ink2).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(width: OpenView.Column.window, alignment: .leading)
            Segments(fills: row.segments, color: Theme.usage(catalog.descriptor(row.provider), danger: row.isDanger))
            Text("\(row.percent)%")
                .font(Theme.font(20, 650))
                .tracking(-0.2)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: OpenView.Column.percent, alignment: .trailing)
            ResetCell(reset: row.reset)
        }
        .frame(height: NotchLayout.rowHeight)
    }
}

private struct ResetCell: View {
    let reset: ResetLine

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 5) {
                ResetIcon(size: 11)
                Text(reset.relative).font(Theme.font(12.5, 600)).foregroundStyle(Theme.ink)
            }
            if !reset.absolute.isEmpty {
                Text(reset.absolute).font(Theme.font(11)).foregroundStyle(Theme.ink3)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct Legend: View {
    let items: [LegendItem]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Dot(color: Theme.dot(DotTone(item.tone)))
                    Text(item.text)
                }
            }
        }
        .font(Theme.font(11))
        .foregroundStyle(Theme.ink3)
    }
}
