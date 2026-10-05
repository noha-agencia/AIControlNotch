import Foundation

/// The notch's motion: one ease-out curve and the durations the views animate with.
/// The live views and the frame export both read these, so the film moves like the app.
public enum NotchMotion {
    public static let curve = CubicBezier(0.16, 1, 0.3, 1)
    /// The black shape changing size (rest, open, alert).
    public static let morph: TimeInterval = 0.34
    public static let layerFade: TimeInterval = 0.16
    public static let layerMove: TimeInterval = 0.3
    /// Arriving layers wait for the morph to get going.
    public static let layerEnterDelay: TimeInterval = 0.09
    public static let ringSweep: TimeInterval = 0.7
    public static let ringDelay: TimeInterval = 0.25
    /// Shadow under the open panel and the alert; none at rest.
    public static let shadowOpacity = 0.55
    public static let hiddenScale = 0.98
    public static let hiddenOffset = -6.0
}

/// How one content layer (rest, open, alert) sits at a moment.
public struct LayerPose: Equatable, Sendable {
    public let opacity: Double
    public let scale: Double
    public let offsetY: Double

    public init(opacity: Double, scale: Double, offsetY: Double) {
        self.opacity = opacity
        self.scale = scale
        self.offsetY = offsetY
    }

    public static let shown = LayerPose(opacity: 1, scale: 1, offsetY: 0)
    public static let hidden = LayerPose(opacity: 0, scale: NotchMotion.hiddenScale, offsetY: NotchMotion.hiddenOffset)

    public static func of(active: Bool) -> LayerPose { active ? shown : hidden }
}
