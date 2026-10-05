import AIControlNotchCore
import SwiftUI

/// Alert (direction A): ring with the new step, title and what is left.
struct AlertView: View {
    static let padding: CGFloat = 22

    let content: AlertContent
    let frame: NotchFrame
    let topPadding: CGFloat
    let animated: Bool
    /// Frame export: the ring's sweep position instead of its animation.
    var ringProgress: Double?
    @Environment(\.providerCatalog) private var catalog

    var body: some View {
        HStack(spacing: 14) {
            RingView(
                from: content.fromPercent,
                to: content.percent,
                color: Theme.usage(catalog.descriptor(content.provider), danger: content.isDanger),
                animated: animated,
                progress: ringProgress
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    LogoView(provider: content.provider, size: 13)
                    Text(content.title).font(Theme.font(14, 650)).foregroundStyle(Theme.ink)
                }
                Text(content.subtitle).font(Theme.font(12)).foregroundStyle(Theme.ink2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Self.padding)
        .padding(.top, topPadding)
        .frame(width: frame.width, alignment: .topLeading)
    }
}
