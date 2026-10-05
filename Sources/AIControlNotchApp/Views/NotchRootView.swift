import AIControlNotchCore
import SwiftUI

/// The whole island: one morphing black shape with the three state layers on top.
/// Live it animates itself; with a `pose` (frame export) it draws that exact moment.
struct NotchRootView: View {
    let model: NotchModel
    var pose: NotchPose?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let frame = pose?.frame ?? model.frame
        let canvas = model.canvas
        let shadow = pose?.shadowOpacity ?? (model.mode == .rest ? 0 : NotchMotion.shadowOpacity)
        ZStack(alignment: .top) {
            NotchShape(width: frame.width, height: frame.height, radius: frame.radius)
                .fill(Theme.notch)
                .shadow(color: Theme.shadow.opacity(shadow), radius: 14, y: 10)

            // Content never shows outside the island while it grows or shrinks.
            layers
                .frame(width: canvas.width, height: canvas.height, alignment: .top)
                .mask { NotchShape(width: frame.width, height: frame.height, radius: frame.radius) }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        .animation(pose == nil ? Theme.curve(NotchMotion.morph, reduceMotion: reduceMotion) : nil, value: frame)
        .environment(\.colorScheme, .dark)
        .environment(\.providerCatalog, model.catalog)
    }

    private var layers: some View {
        ZStack(alignment: .top) {
            RestView(sides: model.restSides, frame: model.layout.frame(for: .rest))
                .modifier(layer(active: model.mode == .rest, pose: pose?.rest))

            let open = model.openContent
            OpenView(
                content: open,
                frame: model.layout.frame(for: .open(rows: open.rowCount, sections: open.sections.count)),
                notchHeight: model.layout.notch.height
            )
                .modifier(layer(active: model.mode == .open, pose: pose?.open))

            if let alert = model.alertContent {
                AlertView(
                    content: alert,
                    frame: model.layout.frame(for: .alert),
                    topPadding: model.layout.alertTopPadding,
                    animated: model.animated && !reduceMotion,
                    ringProgress: pose?.ringProgress
                )
                .id(model.alertSerial)
                .modifier(layer(active: isAlert, pose: pose?.alert))
            }
        }
    }

    private func layer(active: Bool, pose: LayerPose?) -> NotchLayer {
        NotchLayer(active: active, reduceMotion: reduceMotion, pose: pose)
    }

    private var isAlert: Bool {
        if case .alert = model.mode { return true }
        return false
    }
}

/// Layers fade in after the morph starts (160 ms, 90 ms delay) and drop 6 pt when hidden.
/// With a `pose` the layer sits exactly there, unanimated.
struct NotchLayer: ViewModifier {
    let active: Bool
    let reduceMotion: Bool
    var pose: LayerPose?

    func body(content: Content) -> some View {
        if let pose {
            content
                .scaleEffect(pose.scale, anchor: .top)
                .offset(y: pose.offsetY)
                .opacity(pose.opacity)
                .allowsHitTesting(false)
        } else {
            live(content)
        }
    }

    private func live(_ content: Content) -> some View {
        let delay = active ? NotchMotion.layerEnterDelay : 0
        let target = LayerPose.of(active: active)
        return content
            .animation(Theme.curve(NotchMotion.layerMove, reduceMotion: reduceMotion).delay(delay)) {
                $0.scaleEffect(target.scale, anchor: .top).offset(y: target.offsetY)
            }
            .animation(Theme.curve(NotchMotion.layerFade, reduceMotion: reduceMotion).delay(delay)) {
                $0.opacity(target.opacity)
            }
            .allowsHitTesting(false)
    }
}
