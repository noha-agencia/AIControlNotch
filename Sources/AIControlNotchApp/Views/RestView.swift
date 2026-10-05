import AIControlNotchCore
import SwiftUI

/// Resting state (direction C): logo, highest percent and pace dot on each side of the camera.
struct RestView: View {
    static let padding: CGFloat = 13
    static let spacing: CGFloat = 6
    static let logo: CGFloat = 12

    /// Pinned models: the first on the left, the second (if any) on the right.
    let sides: [RestSide]
    let frame: NotchFrame

    var body: some View {
        HStack(spacing: 0) {
            if let left = sides.first {
                HStack(spacing: Self.spacing) {
                    LogoView(provider: left.provider, size: Self.logo)
                    Text(left.percentText).monospacedDigit()
                    if let dot = left.dot { Dot(color: Theme.dot(dot)) }
                }
            }
            Spacer(minLength: 0)
            if let right = sides.dropFirst().first {
                HStack(spacing: Self.spacing) {
                    if let dot = right.dot { Dot(color: Theme.dot(dot)) }
                    Text(right.percentText).monospacedDigit()
                    LogoView(provider: right.provider, size: Self.logo)
                }
            }
        }
        .font(Theme.font(12, 650))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Self.padding)
        .frame(width: frame.width, height: frame.height)
    }
}
