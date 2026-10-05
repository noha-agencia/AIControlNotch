import AIControlNotchCore
import SwiftUI

/// Alert ring: sweeps from the previous step to the new one (700 ms, 250 ms delay).
struct RingView: View {
    static let size: CGFloat = 42
    static let radius: CGFloat = 17
    static let stroke: CGFloat = 5

    let from: Int
    let to: Int
    let color: Color
    let animated: Bool
    /// Frame export: where the sweep is (0…1), instead of animating it.
    var progress: Double?
    @State private var shown: Double?

    var body: some View {
        let value = progress.map { Double(from) + Double(to - from) * $0 } ?? shown ?? Double(animated ? from : to)
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: Self.stroke)
            Circle()
                .trim(from: 0, to: max(0.0001, value / 100))
                .stroke(color, style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(to)")
                .font(Theme.font(to >= 100 ? 10.5 : 12, 700))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .frame(width: Self.radius * 2, height: Self.radius * 2)
        .frame(width: Self.size, height: Self.size)
        .onAppear {
            guard animated, progress == nil else { return }
            shown = Double(from)
            withAnimation(Theme.curve(NotchMotion.ringSweep).delay(NotchMotion.ringDelay)) { shown = Double(to) }
        }
    }
}
