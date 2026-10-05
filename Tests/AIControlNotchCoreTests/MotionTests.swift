import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct CubicBezierTests {
    @Test func endpointsAndClamping() {
        let curve = NotchMotion.curve
        #expect(curve.progress(at: 0) == 0)
        #expect(curve.progress(at: 1) == 1)
        #expect(curve.progress(at: -0.5) == 0)
        #expect(curve.progress(at: 1.5) == 1)
    }

    @Test func linearCurveIsIdentity() {
        let linear = CubicBezier(0, 0, 1, 1)
        for x in stride(from: 0.0, through: 1.0, by: 0.1) {
            #expect(abs(linear.progress(at: x) - x) < 1e-6)
        }
    }

    @Test func cssEaseMatchesKnownValues() {
        // CSS `ease` = cubic-bezier(0.25, 0.1, 0.25, 1): 0.5 → ~0.8024.
        let ease = CubicBezier(0.25, 0.1, 0.25, 1)
        #expect(abs(ease.progress(at: 0.5) - 0.8024) < 0.001)
    }

    @Test func notchCurveIsAStrongEaseOutAndMonotonic() {
        let curve = NotchMotion.curve
        #expect(curve.progress(at: 0.25) > 0.7)
        var last = 0.0
        for x in stride(from: 0.0, through: 1.0, by: 0.01) {
            let y = curve.progress(at: x)
            #expect(y >= last - 1e-9)
            last = y
        }
    }
}

@Suite struct AnimatedValueTests {
    let linear = CubicBezier(0, 0, 1, 1)

    @Test func holdsUntilTheDelayThenEases() {
        let value = AnimatedValue(10).animating(to: 20, at: 1, duration: 0.5, delay: 0.1, curve: linear)
        #expect(value.value(at: 0) == 10)
        #expect(value.value(at: 1.1) == 10)
        #expect(abs(value.value(at: 1.35) - 15) < 1e-9)
        #expect(value.value(at: 1.6) == 20)
        #expect(value.value(at: 9) == 20)
        #expect(value.target == 20)
    }

    @Test func zeroDurationJumps() {
        let value = AnimatedValue(0).animating(to: 1, at: 2, duration: 0)
        #expect(value.value(at: 1.999) == 0)
        #expect(value.value(at: 2) == 1)
    }

    @Test func sameTargetAddsNothing() {
        let value = AnimatedValue(5)
        #expect(value.animating(to: 5, at: 1, duration: 1) == value)
    }

    /// SwiftUI adds an interrupting timing-curve animation on top of the running one.
    @Test func interruptionsAreAdditive() {
        let value = AnimatedValue(0)
            .animating(to: 100, at: 0, duration: 1, curve: linear)
            .animating(to: 0, at: 0.5, duration: 1, curve: linear)
        #expect(abs(value.value(at: 0.5) - 50) < 1e-9)
        #expect(abs(value.value(at: 1) - 50) < 1e-9, "first step done (+100), second half way (-50)")
        #expect(value.value(at: 1.5) == 0)
    }
}

@Suite struct SceneRunnerTests {
    let start = TestClock.now
    let claude40 = ThresholdAlert(provider: .claude, kind: .session, bucket: 40, resetsAt: nil)
    let codex90 = ThresholdAlert(provider: .codex, kind: .week, bucket: 90, resetsAt: nil)
    let claude100 = ThresholdAlert(provider: .claude, kind: .session, bucket: 100, resetsAt: nil)

    @Test func hoverOpensAndCloses() {
        let changes = SceneRunner.run([SceneEvent(time: 0.5, action: .hover(true)), SceneEvent(time: 3, action: .hover(false))], start: start)
        #expect(changes.map(\.time) == [0, 0.5, 3])
        #expect(changes.map(\.machine.mode) == [.rest, .open, .rest])
    }

    /// The 100% step arrives in a later refresh: queued with the 40% one, it would replace it.
    @Test func alertsFollowEachOtherAtTheirOwnDeadlines() {
        let changes = SceneRunner.run([
            SceneEvent(time: 0.5, action: .enqueue([claude40, codex90])),
            SceneEvent(time: 1, action: .enqueue([claude100])),
        ], start: start)
        let normal = AlertQueue.displayDuration(for: claude40)
        let limit = AlertQueue.displayDuration(for: claude100)
        #expect(changes.map(\.machine.mode) == [.rest, .alert(claude40), .alert(codex90), .alert(claude100), .rest])
        let expected = [0, 0.5, 0.5 + normal, 0.5 + 2 * normal, 0.5 + 2 * normal + limit]
        for (time, want) in zip(changes.map(\.time), expected) {
            #expect(abs(time - want) < 1e-9)
        }
    }

    @Test func sceneEndsAfterTheLastChangeOrEventPlusTheTail() {
        let events = [SceneEvent(time: 0.5, action: .hover(true)), SceneEvent(time: 3, action: .hover(false))]
        #expect(SceneRunner.end(of: SceneRunner.run(events, start: start), events: events, tail: 1) == 4)
        #expect(SceneRunner.end(of: SceneRunner.run([], start: start), events: [], tail: 2) == 2)
    }
}

@Suite struct NotchTimelineTests {
    let layout = NotchLayout(notch: CGSize(width: 190, height: 32))
    let openKind = NotchShapeKind.open(rows: 3, sections: 2)
    let alert = ThresholdAlert(provider: .claude, kind: .session, bucket: 40, resetsAt: nil)

    private func timeline(_ events: [SceneEvent]) -> NotchTimeline {
        NotchTimeline(layout: layout, openKind: openKind, changes: SceneRunner.run(events, start: TestClock.now))
    }

    @Test func startsAtRest() {
        let pose = timeline([]).pose(at: 0)
        #expect(pose.frame == layout.frame(for: .rest))
        #expect(pose.shadowOpacity == 0)
        #expect(pose.rest == .shown)
        #expect(pose.open == .hidden)
        #expect(pose.alert == .hidden)
        #expect(pose.machine.mode == .rest)
    }

    @Test func openingMorphsTheShapeAndCrossFadesTheLayers() {
        let open = timeline([SceneEvent(time: 1, action: .hover(true))])
        let early = open.pose(at: 1.05)
        #expect(early.frame.width > layout.frame(for: .rest).width)
        #expect(early.frame.width < layout.frame(for: openKind).width)
        #expect(early.rest.opacity < 1, "the leaving layer fades at once")
        #expect(early.open.opacity == 0, "the arriving layer waits 90 ms")
        #expect(early.machine.mode == .open)

        let settled = open.pose(at: 1 + NotchMotion.morph + 0.01)
        #expect(settled.frame == layout.frame(for: openKind))
        #expect(settled.shadowOpacity == NotchMotion.shadowOpacity)
        #expect(open.pose(at: 2).open == .shown)
        #expect(open.pose(at: 2).rest == .hidden)
    }

    @Test func ringSweepsAfterItsDelayAndRestartsPerAlert() {
        let second = ThresholdAlert(provider: .codex, kind: .week, bucket: 90, resetsAt: nil)
        let line = timeline([SceneEvent(time: 0, action: .enqueue([alert, second]))])
        #expect(line.pose(at: 0.2).ringProgress == 0)
        #expect(line.pose(at: 0.6).ringProgress > 0.5)
        #expect(line.pose(at: 1).ringProgress == 1)
        let next = AlertQueue.displayDuration(for: alert)
        #expect(line.pose(at: next + 0.1).ringProgress == 0)
        #expect(line.pose(at: next + 0.1).machine.mode == .alert(second))
        #expect(line.pose(at: next + 0.1).alert == .shown, "alert to alert keeps the layer on")
    }

    @Test func ringIsFullWhenNoAlertHasShown() {
        #expect(timeline([]).pose(at: 3).ringProgress == 1)
    }
}

@Suite struct FrameClockTests {
    @Test func countsFramesAndTimes() {
        let clock = FrameClock(fps: 30, duration: 2)
        #expect(clock.frameCount == 60)
        #expect(clock.time(of: 0) == 0)
        #expect(clock.time(of: 15) == 0.5)
        #expect(FrameClock(fps: 30, duration: 2.01).frameCount == 61)
        #expect(FrameClock(fps: 30, duration: 0).frameCount == 1)
    }
}

@Suite struct FrameExportOptionsTests {
    private func parse(_ args: String) -> FrameExportOptions? {
        FrameExportOptions.parse(args.split(separator: " ").map(String.init))
    }

    @Test func readsEveryFlag() throws {
        let options = try #require(parse("--render-frames /tmp/film --scene alerts --fps 60 --scale 2 --lang pt"))
        #expect(options.directory.path == "/tmp/film")
        #expect(options.scene == .alerts)
        #expect(options.fps == 60)
        #expect(options.scale == 2)
        #expect(options.language == .portuguese)
    }

    @Test func defaults() throws {
        let options = try #require(parse("--render-frames /tmp/film --scene rest"))
        #expect(options.fps == 30)
        #expect(options.scale == 3)
        #expect(options.language == nil)
        #expect(FilmScene.allCases.map(\.rawValue) == ["rest", "open", "alerts", "models"])
    }

    @Test(arguments: [
        "--render-frames",
        "--render-frames /tmp/film",
        "--render-frames /tmp/film --scene party",
        "--render-frames /tmp/film --scene rest --fps 0",
        "--render-frames /tmp/film --scene rest --fps 121",
        "--render-frames /tmp/film --scene rest --scale 5",
        "--render-frames /tmp/film --scene rest --fps x",
        "--render-frames /tmp/film --scene rest --lang fr",
        "--render-frames --scene rest",
    ])
    func rejects(_ args: String) {
        #expect(parse(args) == nil)
    }

    @Test(arguments: [("en", AppLanguage.english), ("pt", .portuguese), ("pt-BR", .portuguese)])
    func languageFlag(value: String, expected: AppLanguage) {
        #expect(AppLanguage.flag(value) == expected)
    }
}
