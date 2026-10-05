import CoreGraphics
import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct SVGPathTests {
    private func points(_ commands: [SVGCommand]) -> [CGPoint] {
        commands.flatMap { command -> [CGPoint] in
            switch command {
            case let .move(p), let .line(p): [p]
            case let .quad(c, p): [c, p]
            case let .cubic(c1, c2, p): [c1, c2, p]
            case .close: []
            }
        }
    }

    private func bounds(_ commands: [SVGCommand]) -> CGRect {
        let pts = points(commands)
        let xs = pts.map(\.x), ys = pts.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    @Test func absoluteAndRelativeLines() throws {
        let commands = try SVGPath.parse("M1 2L4 6l1-1H10v3h-2V0z")
        #expect(commands == [
            .move(CGPoint(x: 1, y: 2)), .line(CGPoint(x: 4, y: 6)), .line(CGPoint(x: 5, y: 5)),
            .line(CGPoint(x: 10, y: 5)), .line(CGPoint(x: 10, y: 8)), .line(CGPoint(x: 8, y: 8)),
            .line(CGPoint(x: 8, y: 0)), .close,
        ])
    }

    @Test func implicitLinetoAfterMove() throws {
        #expect(try SVGPath.parse("m1 1 2 2 3 3") == [
            .move(CGPoint(x: 1, y: 1)), .line(CGPoint(x: 3, y: 3)), .line(CGPoint(x: 6, y: 6)),
        ])
    }

    @Test func compactNumbers() throws {
        #expect(try SVGPath.parse("M.5-.5l1.5.25e1") == [.move(CGPoint(x: 0.5, y: -0.5)), .line(CGPoint(x: 2, y: 2))])
    }

    @Test func smoothCubicReflectsControlPoint() throws {
        let commands = try SVGPath.parse("M0 0C0 1 1 1 1 0S2-1 2 0")
        #expect(commands.last == .cubic(CGPoint(x: 1, y: -1), CGPoint(x: 2, y: -1), CGPoint(x: 2, y: 0)))
    }

    @Test func quadraticAndSmoothQuadratic() throws {
        let commands = try SVGPath.parse("M0 0Q1 1 2 0T4 0q1 1 2 0")
        #expect(commands[1] == .quad(CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0)))
        #expect(commands[2] == .quad(CGPoint(x: 3, y: -1), CGPoint(x: 4, y: 0)))
        #expect(commands[3] == .quad(CGPoint(x: 5, y: 1), CGPoint(x: 6, y: 0)))
    }

    @Test func relativeCubicAndSmooth() throws {
        let commands = try SVGPath.parse("M1 1c0 1 1 1 1 0s1-1 1 0")
        #expect(commands[1] == .cubic(CGPoint(x: 1, y: 2), CGPoint(x: 2, y: 2), CGPoint(x: 2, y: 1)))
        #expect(commands[2] == .cubic(CGPoint(x: 2, y: 0), CGPoint(x: 3, y: 0), CGPoint(x: 3, y: 1)))
    }

    @Test func arcBecomesCubicsEndingAtTarget() throws {
        let commands = try SVGPath.parse("M0 0A5 5 0 0 1 10 0")
        let cubics = commands.dropFirst()
        #expect(!cubics.isEmpty)
        guard case let .cubic(_, _, end)? = cubics.last else {
            Issue.record("expected a cubic")
            return
        }
        #expect(abs(end.x - 10) < 1e-6 && abs(end.y) < 1e-6)
        // A half circle of radius 5 bulges 5 units away from the chord.
        #expect(abs(bounds(Array(commands)).height - 5) < 0.3)
    }

    @Test func compactArcFlags() throws {
        let commands = try SVGPath.parse("M0 0a.071.071 0 0 1 .038.052a1 1 0 01 1 1")
        guard case let .cubic(_, _, end)? = commands.last else {
            Issue.record("expected a cubic")
            return
        }
        #expect(abs(end.x - 1.038) < 1e-6 && abs(end.y - 1.052) < 1e-6)
    }

    @Test func degenerateArcIsALine() throws {
        #expect(try SVGPath.parse("M0 0A0 0 0 0 1 3 4") == [.move(.zero), .line(CGPoint(x: 3, y: 4))])
        #expect(try SVGPath.parse("M1 1A2 2 0 0 1 1 1") == [.move(CGPoint(x: 1, y: 1))])
    }

    @Test func closeReturnsToSubpathStart() throws {
        let commands = try SVGPath.parse("M2 2l1 0z l1 1")
        #expect(commands.last == .line(CGPoint(x: 3, y: 3)))
    }

    @Test func invalidPathsThrow() {
        #expect(throws: SVGPath.ParseError.self) { _ = try SVGPath.parse("L1 1") }
        #expect(throws: SVGPath.ParseError.self) { _ = try SVGPath.parse("M1") }
        #expect(throws: SVGPath.ParseError.self) { _ = try SVGPath.parse("M1 1 X2 2") }
    }
}
