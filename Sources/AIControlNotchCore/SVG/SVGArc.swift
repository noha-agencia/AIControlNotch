import CoreGraphics
import Foundation

/// Converts an SVG elliptical arc into cubic Béziers of at most 90° each
/// (SVG 1.1 implementation notes, F.6.5 and F.6.6).
enum SVGArc {
    struct Parameters {
        let radii: CGSize
        let rotationDegrees: CGFloat
        let largeArc: Bool
        let sweep: Bool
    }

    private struct Ellipse {
        let center: CGPoint
        let radii: CGSize
        let cos: CGFloat
        let sin: CGFloat

        func point(_ unit: CGPoint) -> CGPoint {
            CGPoint(
                x: center.x + radii.width * unit.x * cos - radii.height * unit.y * sin,
                y: center.y + radii.width * unit.x * sin + radii.height * unit.y * cos
            )
        }
    }

    static func commands(from start: CGPoint, to end: CGPoint, _ arc: Parameters) -> [SVGCommand] {
        if start == end { return [] }
        if arc.radii.width == 0 || arc.radii.height == 0 { return [.line(end)] }
        let (ellipse, startAngle, sweepAngle) = centerParameterization(start, end, arc)
        let segments = max(1, Int((abs(sweepAngle) / (.pi / 2)).rounded(.up)))
        let delta = sweepAngle / CGFloat(segments)
        let handle = 4 / 3 * tan(delta / 4)
        return (0..<segments).map { index in
            let a1 = startAngle + CGFloat(index) * delta
            let a2 = a1 + delta
            let c1 = ellipse.point(CGPoint(x: cos(a1) - handle * sin(a1), y: sin(a1) + handle * cos(a1)))
            let c2 = ellipse.point(CGPoint(x: cos(a2) + handle * sin(a2), y: sin(a2) - handle * cos(a2)))
            let target = index == segments - 1 ? end : ellipse.point(CGPoint(x: cos(a2), y: sin(a2)))
            return .cubic(c1, c2, target)
        }
    }

    private static func centerParameterization(
        _ start: CGPoint, _ end: CGPoint, _ arc: Parameters
    ) -> (Ellipse, CGFloat, CGFloat) {
        let phi = arc.rotationDegrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy

        var rx = abs(arc.radii.width), ry = abs(arc.radii.height)
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }

        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let sign: CGFloat = arc.largeArc == arc.sweep ? -1 : 1
        let coefficient = sign * max(0, numerator / denominator).squareRoot()
        let cx1 = coefficient * rx * y1 / ry
        let cy1 = -coefficient * ry * x1 / rx

        let center = CGPoint(
            x: cosPhi * cx1 - sinPhi * cy1 + (start.x + end.x) / 2,
            y: sinPhi * cx1 + cosPhi * cy1 + (start.y + end.y) / 2
        )
        let u = CGPoint(x: (x1 - cx1) / rx, y: (y1 - cy1) / ry)
        let v = CGPoint(x: (-x1 - cx1) / rx, y: (-y1 - cy1) / ry)
        let startAngle = angle(CGPoint(x: 1, y: 0), u)
        var sweepAngle = angle(u, v)
        if !arc.sweep, sweepAngle > 0 { sweepAngle -= 2 * .pi }
        if arc.sweep, sweepAngle < 0 { sweepAngle += 2 * .pi }

        let ellipse = Ellipse(center: center, radii: CGSize(width: rx, height: ry), cos: cosPhi, sin: sinPhi)
        return (ellipse, startAngle, sweepAngle)
    }

    private static func angle(_ u: CGPoint, _ v: CGPoint) -> CGFloat {
        atan2(u.x * v.y - u.y * v.x, u.x * v.x + u.y * v.y)
    }
}
