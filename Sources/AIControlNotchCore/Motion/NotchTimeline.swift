import CoreGraphics
import Foundation

/// Everything that moves in the notch at one moment of a scene.
public struct NotchPose: Equatable, Sendable {
    public let frame: NotchFrame
    public let shadowOpacity: Double
    public let rest: LayerPose
    public let open: LayerPose
    public let alert: LayerPose
    /// 0 → 1 along the alert ring's sweep from the previous step to the new one.
    public let ringProgress: Double
    /// The state in effect (what the layers show).
    public let machine: NotchMachine
}

/// Turns a scene's mode changes into poses at any time, animating each property
/// with the same curve, durations and delays as the live views.
public struct NotchTimeline: Sendable {
    private struct Layer: Sendable {
        let opacity: AnimatedValue
        let scale: AnimatedValue
        let offset: AnimatedValue

        init(active: Bool) {
            let pose = LayerPose.of(active: active)
            opacity = AnimatedValue(pose.opacity)
            scale = AnimatedValue(pose.scale)
            offset = AnimatedValue(pose.offsetY)
        }

        private init(opacity: AnimatedValue, scale: AnimatedValue, offset: AnimatedValue) {
            self.opacity = opacity
            self.scale = scale
            self.offset = offset
        }

        func switching(active: Bool, at time: TimeInterval) -> Layer {
            let pose = LayerPose.of(active: active)
            let delay = active ? NotchMotion.layerEnterDelay : 0
            return Layer(
                opacity: opacity.animating(to: pose.opacity, at: time, duration: NotchMotion.layerFade, delay: delay),
                scale: scale.animating(to: pose.scale, at: time, duration: NotchMotion.layerMove, delay: delay),
                offset: offset.animating(to: pose.offsetY, at: time, duration: NotchMotion.layerMove, delay: delay)
            )
        }

        func pose(at time: TimeInterval) -> LayerPose {
            LayerPose(opacity: opacity.value(at: time), scale: scale.value(at: time), offsetY: offset.value(at: time))
        }
    }

    private struct Shape: Sendable {
        let width: AnimatedValue
        let height: AnimatedValue
        let radius: AnimatedValue
        let shadow: AnimatedValue
    }

    private let changes: [ModeChange]
    private let shape: Shape
    private let layers: [Layer]
    private let alertStarts: [TimeInterval]

    public init(layout: NotchLayout, openKind: NotchShapeKind, changes: [ModeChange]) {
        let changes = changes.isEmpty ? [ModeChange(time: 0, machine: NotchMachine())] : changes
        self.changes = changes
        let first = changes[0].machine.mode
        let start = layout.frame(for: Self.kind(first, open: openKind))
        var shape = Shape(
            width: AnimatedValue(Double(start.width)),
            height: AnimatedValue(Double(start.height)),
            radius: AnimatedValue(Double(start.radius)),
            shadow: AnimatedValue(Self.shadow(first))
        )
        var layers = Self.activity(first).map(Layer.init(active:))
        var alertStarts: [TimeInterval] = []
        for (previous, change) in zip(changes, changes.dropFirst()) {
            let (before, after, time) = (previous.machine.mode, change.machine.mode, change.time)
            shape = Self.morph(shape, from: before, to: after, at: time, layout: layout, open: openKind)
            layers = zip(layers, zip(Self.activity(before), Self.activity(after))).map { layer, activity in
                activity.0 == activity.1 ? layer : layer.switching(active: activity.1, at: time)
            }
            if case .alert = after { alertStarts.append(time) }
        }
        self.shape = shape
        self.layers = layers
        self.alertStarts = alertStarts
    }

    public func pose(at time: TimeInterval) -> NotchPose {
        let machine = changes.last { $0.time <= time }?.machine ?? changes[0].machine
        return NotchPose(
            frame: NotchFrame(
                width: CGFloat(shape.width.value(at: time)),
                height: CGFloat(shape.height.value(at: time)),
                radius: CGFloat(shape.radius.value(at: time))
            ),
            shadowOpacity: shape.shadow.value(at: time),
            rest: layers[0].pose(at: time),
            open: layers[1].pose(at: time),
            alert: layers[2].pose(at: time),
            ringProgress: ringProgress(at: time),
            machine: machine
        )
    }

    private func ringProgress(at time: TimeInterval) -> Double {
        guard let start = alertStarts.last(where: { $0 <= time }) else { return 1 }
        let elapsed = time - start - NotchMotion.ringDelay
        return NotchMotion.curve.progress(at: elapsed / NotchMotion.ringSweep)
    }

    /// The root view animates the shape and its shadow only when the shape's size changes.
    private static func morph(
        _ shape: Shape, from before: NotchMode, to after: NotchMode, at time: TimeInterval,
        layout: NotchLayout, open: NotchShapeKind
    ) -> Shape {
        let target = layout.frame(for: kind(after, open: open))
        let changed = layout.frame(for: kind(before, open: open)) != target
        let duration = changed ? NotchMotion.morph : 0
        return Shape(
            width: shape.width.animating(to: Double(target.width), at: time, duration: duration),
            height: shape.height.animating(to: Double(target.height), at: time, duration: duration),
            radius: shape.radius.animating(to: Double(target.radius), at: time, duration: duration),
            shadow: shape.shadow.animating(to: Self.shadow(after), at: time, duration: duration)
        )
    }

    private static func kind(_ mode: NotchMode, open: NotchShapeKind) -> NotchShapeKind {
        switch mode {
        case .rest: .rest
        case .open: open
        case .alert: .alert
        }
    }

    private static func shadow(_ mode: NotchMode) -> Double {
        mode == .rest ? 0 : NotchMotion.shadowOpacity
    }

    /// Whether the rest, open and alert layers are on.
    private static func activity(_ mode: NotchMode) -> [Bool] {
        switch mode {
        case .rest: [true, false, false]
        case .open: [false, true, false]
        case .alert: [false, false, true]
        }
    }
}
