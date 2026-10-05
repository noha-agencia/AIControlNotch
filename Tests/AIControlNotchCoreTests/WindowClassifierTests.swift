import Testing
@testable import AIControlNotchCore

@Suite struct WindowClassifierTests {
    @Test(arguments: [240, 300, 360])
    func sessionRange(minutes: Int) {
        #expect(WindowClassifier.kind(minutes: minutes) == .session)
    }

    @Test(arguments: [9_360, 10_080, 10_800])
    func weekRange(minutes: Int) {
        #expect(WindowClassifier.kind(minutes: minutes) == .week)
    }

    @Test func outsideRangesBecomeDays() {
        #expect(WindowClassifier.kind(minutes: 239) == .minutes(239))
        #expect(WindowClassifier.kind(minutes: 361) == .minutes(361))
        #expect(WindowClassifier.kind(minutes: 1_440) == .days(1))
        #expect(WindowClassifier.kind(minutes: 9_359) == .days(6))
        #expect(WindowClassifier.kind(minutes: 10_801) == .days(8))
        #expect(WindowClassifier.kind(minutes: 43_200) == .days(30))
        #expect(WindowClassifier.kind(minutes: 0) == .minutes(1))
    }


    @Test func sortOrderPutsSessionFirst() {
        let sorted = [WindowKind.days(30), .week, .session].sorted()
        #expect(sorted == [.session, .week, .days(30)])
    }

    @Test func keysAreStable() {
        #expect(WindowKind.session.key == "session")
        #expect(WindowKind.week.key == "week")
        #expect(WindowKind.days(30).key == "days30")
    }
}
