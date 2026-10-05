import Foundation

/// A number animated the way SwiftUI combines timing-curve animations: every change
/// adds its own eased delta, so an interrupted animation blends into the next one.
public struct AnimatedValue: Equatable, Sendable {
    struct Step: Equatable, Sendable {
        let start: TimeInterval
        let duration: TimeInterval
        let delta: Double
        let curve: CubicBezier
    }

    public let initial: Double
    public let target: Double
    let steps: [Step]

    public init(_ initial: Double) {
        self.init(initial: initial, target: initial, steps: [])
    }

    private init(initial: Double, target: Double, steps: [Step]) {
        self.initial = initial
        self.target = target
        self.steps = steps
    }

    /// A copy that heads to `target` from `time + delay` over `duration`.
    public func animating(
        to target: Double,
        at time: TimeInterval,
        duration: TimeInterval,
        delay: TimeInterval = 0,
        curve: CubicBezier = NotchMotion.curve
    ) -> AnimatedValue {
        guard target != self.target else { return self }
        let step = Step(start: time + delay, duration: duration, delta: target - self.target, curve: curve)
        return AnimatedValue(initial: initial, target: target, steps: steps + [step])
    }

    public func value(at time: TimeInterval) -> Double {
        steps.reduce(initial) { value, step in
            value + step.delta * Self.progress(of: step, at: time)
        }
    }

    private static func progress(of step: Step, at time: TimeInterval) -> Double {
        let elapsed = time - step.start
        guard elapsed >= 0 else { return 0 }
        guard step.duration > 0, elapsed < step.duration else { return 1 }
        return step.curve.progress(at: elapsed / step.duration)
    }
}
