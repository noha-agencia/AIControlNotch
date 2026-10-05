import Foundation
import Testing
@testable import AIControlNotchCore

@Suite struct NotchMachineTests {
    let now = TestClock.now
    let claude40 = ThresholdAlert(provider: .claude, kind: .session, bucket: 40, resetsAt: nil)
    let codex90 = ThresholdAlert(provider: .codex, kind: .week, bucket: 90, resetsAt: nil)
    let codex100 = ThresholdAlert(provider: .codex, kind: .week, bucket: 100, resetsAt: nil)

    @Test func hoverOpensAndLeavingRests() {
        let open = NotchMachine().hover(true, now: now)
        #expect(open.mode == .open)
        #expect(open.hover(false, now: now).mode == .rest)
    }

    @Test func alertShowsAtRestAndExpires() {
        let shown = NotchMachine().enqueue([claude40], now: now)
        #expect(shown.mode == .alert(claude40))
        #expect(shown.nextDeadline == now.addingTimeInterval(4.5))
        #expect(shown.tick(now: now.addingTimeInterval(4)).mode == .alert(claude40))
        #expect(shown.tick(now: now.addingTimeInterval(4.5)).mode == .rest)
    }

    @Test func alertsQueueOneAtATime() {
        let shown = NotchMachine().enqueue([claude40, codex90], now: now)
        let next = shown.tick(now: now.addingTimeInterval(5))
        #expect(next.mode == .alert(codex90))
        #expect(next.nextDeadline == now.addingTimeInterval(9.5))
        #expect(next.tick(now: now.addingTimeInterval(10)).mode == .rest)
    }

    @Test func limitAlertsStayLonger() {
        let shown = NotchMachine().enqueue([codex100], now: now)
        #expect(shown.nextDeadline == now.addingTimeInterval(8))
    }

    @Test func alertsWaitForTheOpenPanel() {
        let open = NotchMachine().hover(true, now: now).enqueue([codex90], now: now)
        #expect(open.mode == .open)
        #expect(open.nextDeadline == nil)
        let closed = open.hover(false, now: now.addingTimeInterval(30))
        #expect(closed.mode == .alert(codex90))
        #expect(closed.nextDeadline == now.addingTimeInterval(34.5))
    }

    @Test func hoveringHoldsTheAlert() {
        let held = NotchMachine().enqueue([codex90], now: now).hover(true, now: now.addingTimeInterval(1))
        #expect(held.mode == .alert(codex90))
        #expect(held.nextDeadline == nil)
        #expect(held.tick(now: now.addingTimeInterval(60)).mode == .alert(codex90))
        let released = held.hover(false, now: now.addingTimeInterval(60))
        #expect(released.nextDeadline == now.addingTimeInterval(64.5))
        #expect(released.tick(now: now.addingTimeInterval(65)).mode == .rest)
    }

    @Test func newerStepReplacesQueuedOne() {
        let codex80 = ThresholdAlert(provider: .codex, kind: .week, bucket: 80, resetsAt: nil)
        let shown = NotchMachine().enqueue([claude40], now: now).enqueue([codex80], now: now).enqueue([codex90], now: now)
        let next = shown.tick(now: now.addingTimeInterval(5))
        #expect(next.mode == .alert(codex90))
        #expect(next.tick(now: now.addingTimeInterval(10)).mode == .rest)
    }

    @Test func dismissingAnAlertOpensThePanelWhenHovered() {
        let shown = NotchMachine().enqueue([claude40, codex90], now: now).hover(true, now: now)
        let opened = shown.dismissAlert(now: now)
        #expect(opened.mode == .open)
        #expect(opened.hover(false, now: now).mode == .alert(codex90))
    }

    @Test func emptyEnqueueChangesNothing() {
        let machine = NotchMachine()
        #expect(machine.enqueue([], now: now) == machine)
        #expect(machine.tick(now: now) == machine)
    }
}
