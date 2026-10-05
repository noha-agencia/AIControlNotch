import Foundation

/// A CSS-style `cubic-bezier(x1, y1, x2, y2)` timing curve: maps the elapsed
/// fraction of an animation to how far along the value is.
public struct CubicBezier: Equatable, Sendable {
    static let tolerance = 1e-7
    static let newtonSteps = 8
    static let bisectionSteps = 60

    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    public func progress(at fraction: Double) -> Double {
        guard fraction > 0 else { return 0 }
        guard fraction < 1 else { return 1 }
        return Self.sample(y1, y2, at: parameter(for: fraction))
    }

    /// The curve parameter whose x is `fraction`: Newton first, bisection if it stalls.
    private func parameter(for fraction: Double) -> Double {
        var t = fraction
        for _ in 0..<Self.newtonSteps {
            let error = Self.sample(x1, x2, at: t) - fraction
            if abs(error) < Self.tolerance { return t }
            let slope = Self.slope(x1, x2, at: t)
            guard abs(slope) > 1e-6 else { break }
            t = min(1, max(0, t - error / slope))
        }
        var low = 0.0
        var high = 1.0
        t = fraction
        for _ in 0..<Self.bisectionSteps {
            let x = Self.sample(x1, x2, at: t)
            if abs(x - fraction) < Self.tolerance { break }
            if x < fraction { low = t } else { high = t }
            t = (low + high) / 2
        }
        return t
    }

    /// One coordinate of the curve with end points 0 and 1.
    private static func sample(_ a: Double, _ b: Double, at t: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
    }

    private static func slope(_ a: Double, _ b: Double, at t: Double) -> Double {
        let u = 1 - t
        return 3 * u * u * a + 6 * u * t * (b - a) + 3 * t * t * (1 - b)
    }
}
