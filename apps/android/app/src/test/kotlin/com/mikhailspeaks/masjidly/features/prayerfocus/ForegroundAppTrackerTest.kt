package com.mikhailspeaks.masjidly.features.prayerfocus

import com.mikhailspeaks.masjidly.features.prayerfocus.ForegroundAppTracker.Event
import com.mikhailspeaks.masjidly.features.prayerfocus.ForegroundAppTracker.Kind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundAppTrackerTest {
    private val selected = setOf("com.social")
    private val excluded = setOf("com.mikhailspeaks.masjidly", "com.launcher", "com.android.settings")
    private val launchers = setOf("com.launcher")

    private fun ev(kind: Kind, pkg: String, time: Long, cls: String = "Main") = Event(kind, pkg, cls, time)

    @Test
    fun coversSelectedAppAlreadyOpenWhenWindowStarts() {
        val tracker = ForegroundAppTracker()
        tracker.apply(listOf(ev(Kind.RESUMED, "com.social", 10)), launchers)
        assertTrue(tracker.shouldCover(selected, excluded))
    }

    @Test
    fun uncoversWhenLeavingForHomeOrAnotherApp() {
        val tracker = ForegroundAppTracker()
        tracker.apply(listOf(ev(Kind.RESUMED, "com.social", 10)), launchers)
        tracker.apply(listOf(ev(Kind.PAUSED, "com.social", 20), ev(Kind.RESUMED, "com.launcher", 21)), launchers)
        assertFalse(tracker.shouldCover(selected, excluded))
        assertEquals("com.launcher", tracker.topPackage)

        tracker.apply(listOf(ev(Kind.RESUMED, "com.social", 30)), launchers)
        tracker.apply(listOf(ev(Kind.PAUSED, "com.social", 40), ev(Kind.RESUMED, "com.notes", 41)), launchers)
        assertFalse(tracker.shouldCover(selected, excluded))
    }

    @Test
    fun pollBetweenPauseAndResumeDoesNotCover() {
        val tracker = ForegroundAppTracker()
        tracker.apply(listOf(ev(Kind.RESUMED, "com.social", 10), ev(Kind.PAUSED, "com.social", 20)), launchers)
        assertNull(tracker.topPackage)
        assertFalse(tracker.shouldCover(selected, excluded))
    }

    @Test
    fun splitScreenCoversWhenSelectedAppIsVisibleBesideAnother() {
        val tracker = ForegroundAppTracker()
        tracker.apply(listOf(ev(Kind.RESUMED, "com.social", 10), ev(Kind.RESUMED, "com.notes", 11)), launchers)
        assertEquals("com.notes", tracker.topPackage)
        assertTrue(tracker.shouldCover(selected, excluded))
    }

    @Test
    fun neverCoversWhenAnEscapeSurfaceIsOnTop() {
        val tracker = ForegroundAppTracker()
        tracker.apply(listOf(ev(Kind.RESUMED, "com.social", 10), ev(Kind.RESUMED, "com.android.settings", 11)), launchers)
        assertFalse(tracker.shouldCover(selected, excluded))
        tracker.apply(listOf(ev(Kind.RESUMED, "com.mikhailspeaks.masjidly", 12)), launchers)
        assertFalse(tracker.shouldCover(selected, excluded))
    }

    @Test
    fun outOfOrderBatchesAreAppliedByTimestamp() {
        val tracker = ForegroundAppTracker()
        tracker.apply(listOf(ev(Kind.RESUMED, "com.launcher", 21), ev(Kind.PAUSED, "com.social", 20), ev(Kind.RESUMED, "com.social", 10)), launchers)
        assertFalse(tracker.shouldCover(selected, excluded))
    }

    @Test
    fun keyguardClearsStaleState() {
        val tracker = ForegroundAppTracker()
        tracker.apply(listOf(ev(Kind.RESUMED, "com.social", 10), ev(Kind.KEYGUARD_SHOWN, "android", 20)), launchers)
        assertFalse(tracker.shouldCover(selected, excluded))
        assertTrue(tracker.resumedPackages.isEmpty())
    }

    @Test
    fun multipleActivitiesOfOneAppStayCoveredUntilAllPause() {
        val tracker = ForegroundAppTracker()
        tracker.apply(
            listOf(
                ev(Kind.RESUMED, "com.social", 10, "Feed"),
                ev(Kind.RESUMED, "com.social", 11, "Chat"),
                ev(Kind.PAUSED, "com.social", 12, "Feed"),
            ),
            launchers,
        )
        assertTrue(tracker.shouldCover(selected, excluded))
        tracker.apply(listOf(ev(Kind.STOPPED, "com.social", 13, "Chat")), launchers)
        assertFalse(tracker.shouldCover(selected, excluded))
    }
}
