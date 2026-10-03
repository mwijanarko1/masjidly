import Foundation
import Testing
@testable import Masjidly

@Suite("Prayer Focus monitor reconcile")
struct PrayerFocusMonitorReconcileTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private var end: Date { start.addingTimeInterval(15 * 60) }
    private var windows: [PrayerFocusMonitorReconcile.Window] {
        [.init(start: start, end: end)]
    }

    @Test func earlyEndThenDelayedStartDoesNotReactivateRetiredGeneration() {
        let nearEnd = end.addingTimeInterval(-30)
        let live: Set<Int> = [7]

        let afterEnd = PrayerFocusMonitorReconcile.outcome(
            kind: .end,
            generation: 7,
            now: nearEnd,
            windows: windows,
            liveGenerations: live,
            retiredGenerations: []
        )
        #expect(afterEnd.applyShieldUpdate)
        #expect(!afterEnd.isActive)
        #expect(afterEnd.retiredGenerations == [7])

        let afterLateStart = PrayerFocusMonitorReconcile.outcome(
            kind: .start,
            generation: 7,
            now: nearEnd,
            windows: windows,
            liveGenerations: live,
            retiredGenerations: afterEnd.retiredGenerations
        )
        #expect(!afterLateStart.applyShieldUpdate)
        #expect(afterLateStart.retiredGenerations == [7])
    }

    @Test func oldGenerationEndDoesNotRetireReplacement() {
        let mid = start.addingTimeInterval(5 * 60)
        let afterOldEnd = PrayerFocusMonitorReconcile.outcome(
            kind: .end,
            generation: 7,
            now: mid,
            windows: windows,
            liveGenerations: [8],
            retiredGenerations: []
        )
        #expect(!afterOldEnd.applyShieldUpdate)
        #expect(afterOldEnd.retiredGenerations == [7])
        #expect(!afterOldEnd.retiredGenerations.contains(8))

        let replacementStart = PrayerFocusMonitorReconcile.outcome(
            kind: .start,
            generation: 8,
            now: mid,
            windows: windows,
            liveGenerations: [8],
            retiredGenerations: afterOldEnd.retiredGenerations
        )
        #expect(replacementStart.applyShieldUpdate)
        #expect(replacementStart.isActive)
    }

    @Test func siblingWindowInSameScheduleIsNotRetiredByAnotherEnd() {
        let otherStart = start.addingTimeInterval(60 * 60)
        let otherEnd = otherStart.addingTimeInterval(15 * 60)
        let allWindows = [
            PrayerFocusMonitorReconcile.Window(start: start, end: end),
            PrayerFocusMonitorReconcile.Window(start: otherStart, end: otherEnd),
        ]
        let afterFirstEnd = PrayerFocusMonitorReconcile.outcome(
            kind: .end,
            generation: 7,
            now: end.addingTimeInterval(-30),
            windows: allWindows,
            liveGenerations: [7, 8],
            retiredGenerations: []
        )
        #expect(afterFirstEnd.retiredGenerations == [7])

        let secondStart = PrayerFocusMonitorReconcile.outcome(
            kind: .start,
            generation: 8,
            now: otherStart,
            windows: allWindows,
            liveGenerations: [7, 8],
            retiredGenerations: afterFirstEnd.retiredGenerations
        )
        #expect(secondStart.applyShieldUpdate)
        #expect(secondStart.isActive)
    }

    @Test func nonLiveStartDoesNotApplyShieldUpdate() {
        let mid = start.addingTimeInterval(5 * 60)
        let staleStart = PrayerFocusMonitorReconcile.outcome(
            kind: .start,
            generation: 7,
            now: mid,
            windows: windows,
            liveGenerations: [8],
            retiredGenerations: []
        )
        #expect(!staleStart.applyShieldUpdate)
        #expect(staleStart.retiredGenerations.isEmpty)
    }

    @Test func activityNameEmbedsGeneration() {
        let name = PrayerFocusMonitorReconcile.activityName(generation: 12, start: start)
        #expect(name == "prayerFocus.12.1000000")
        #expect(PrayerFocusMonitorReconcile.generation(fromActivityName: name) == 12)
    }
}
