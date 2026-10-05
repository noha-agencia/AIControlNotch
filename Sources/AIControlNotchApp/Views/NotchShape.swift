import SwiftUI

/// The black island: bottom corners rounded and 9 pt concave ears where it
/// meets the top edge. Width, height and radius animate together (the morph).
struct NotchShape: Shape {
    static let ear: CGFloat = 9

    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(width, AnimatablePair(height, radius)) }
        set {
            width = newValue.first
            height = newValue.second.first
            radius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let left = rect.midX - width / 2
        let right = rect.midX + width / 2
        let ear = min(Self.ear, height / 2)
        let corner = min(radius, height - ear, width / 2)
        var path = Path()
        path.move(to: CGPoint(x: left - ear, y: rect.minY))
        path.addLine(to: CGPoint(x: right + ear, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: right, y: rect.minY), tangent2End: CGPoint(x: right, y: ear), radius: ear)
        path.addLine(to: CGPoint(x: right, y: height - corner))
        path.addArc(tangent1End: CGPoint(x: right, y: height), tangent2End: CGPoint(x: right - corner, y: height), radius: corner)
        path.addLine(to: CGPoint(x: left + corner, y: height))
        path.addArc(tangent1End: CGPoint(x: left, y: height), tangent2End: CGPoint(x: left, y: height - corner), radius: corner)
        path.addLine(to: CGPoint(x: left, y: ear))
        path.addArc(tangent1End: CGPoint(x: left, y: rect.minY), tangent2End: CGPoint(x: left - ear, y: rect.minY), radius: ear)
        path.closeSubpath()
        return path
    }
}
