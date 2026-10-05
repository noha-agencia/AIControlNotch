import CoreGraphics
import Foundation

/// An absolute drawing step. Arcs arrive already converted to cubics.
public enum SVGCommand: Equatable, Sendable {
    case move(CGPoint)
    case line(CGPoint)
    case quad(CGPoint, CGPoint)
    case cubic(CGPoint, CGPoint, CGPoint)
    case close
}

/// Parses SVG path data (`d` attribute) into absolute commands, so the official
/// logos and small icons such as the reset arrow can be drawn at runtime without assets.
public enum SVGPath {
    public enum ParseError: Error, Equatable {
        case mustStartWithMove
        case unexpected(offset: Int)
        case missingNumber(offset: Int)
    }

    public static func parse(_ data: String) throws -> [SVGCommand] {
        var builder = SVGPathBuilder(scanner: SVGScanner(data))
        return try builder.run()
    }
}

/// Walks the tokens keeping the pen position and the last control points (for S and T).
private struct SVGPathBuilder {
    var scanner: SVGScanner
    private var commands: [SVGCommand] = []
    private var current = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControl: CGPoint?
    private var lastQuadControl: CGPoint?

    init(scanner: SVGScanner) {
        self.scanner = scanner
    }

    mutating func run() throws -> [SVGCommand] {
        if scanner.isAtEnd { return [] }
        guard let first = scanner.peekCommand(), first == "M" || first == "m" else {
            throw SVGPath.ParseError.mustStartWithMove
        }
        while !scanner.isAtEnd {
            try handle(try scanner.command())
        }
        return commands
    }

    private mutating func handle(_ letter: Character) throws {
        let relative = letter.isLowercase
        switch letter.uppercased() {
        case "M": try moveTo(relative)
        case "L": repeat { lineTo(try point(relative)) } while scanner.hasNumber()
        case "H": repeat { lineTo(CGPoint(x: try coordinate(relative, current.x), y: current.y)) } while scanner.hasNumber()
        case "V": repeat { lineTo(CGPoint(x: current.x, y: try coordinate(relative, current.y))) } while scanner.hasNumber()
        case "C": repeat { try cubicTo(relative, smooth: false) } while scanner.hasNumber()
        case "S": repeat { try cubicTo(relative, smooth: true) } while scanner.hasNumber()
        case "Q": repeat { try quadTo(relative, smooth: false) } while scanner.hasNumber()
        case "T": repeat { try quadTo(relative, smooth: true) } while scanner.hasNumber()
        case "A": repeat { try arcTo(relative) } while scanner.hasNumber()
        default: close()
        }
    }

    private mutating func moveTo(_ relative: Bool) throws {
        let target = try point(relative)
        append(.move(target), end: target)
        subpathStart = target
        while scanner.hasNumber() { lineTo(try point(relative)) }
    }

    private mutating func lineTo(_ target: CGPoint) {
        append(.line(target), end: target)
    }

    private mutating func cubicTo(_ relative: Bool, smooth: Bool) throws {
        let first = try smooth ? reflected(lastCubicControl) : point(relative)
        let second = try point(relative)
        let target = try point(relative)
        append(.cubic(first, second, target), end: target)
        lastCubicControl = second
    }

    private mutating func quadTo(_ relative: Bool, smooth: Bool) throws {
        let control = try smooth ? reflected(lastQuadControl) : point(relative)
        let target = try point(relative)
        append(.quad(control, target), end: target)
        lastQuadControl = control
    }

    private mutating func arcTo(_ relative: Bool) throws {
        let radii = CGSize(width: try scanner.number(), height: try scanner.number())
        let rotation = try scanner.number()
        let largeArc = try scanner.flag()
        let sweep = try scanner.flag()
        let target = try point(relative)
        let parameters = SVGArc.Parameters(radii: radii, rotationDegrees: rotation, largeArc: largeArc, sweep: sweep)
        let segments = SVGArc.commands(from: current, to: target, parameters)
        commands += segments
        current = target
        lastCubicControl = nil
        lastQuadControl = nil
    }

    private mutating func close() {
        commands.append(.close)
        current = subpathStart
        lastCubicControl = nil
        lastQuadControl = nil
    }

    private mutating func append(_ command: SVGCommand, end: CGPoint) {
        commands.append(command)
        current = end
        lastCubicControl = nil
        lastQuadControl = nil
    }

    private func reflected(_ control: CGPoint?) -> CGPoint {
        guard let control else { return current }
        return CGPoint(x: 2 * current.x - control.x, y: 2 * current.y - control.y)
    }

    private mutating func point(_ relative: Bool) throws -> CGPoint {
        let x = try scanner.number()
        let y = try scanner.number()
        return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    }

    private mutating func coordinate(_ relative: Bool, _ base: CGFloat) throws -> CGFloat {
        let value = try scanner.number()
        return relative ? base + value : value
    }
}
