package com.mikhailspeaks.masjidly.features.prayerfocus

import com.mikhailspeaks.masjidly.widget.WidgetDailyIqamahTimes
import com.mikhailspeaks.masjidly.widget.WidgetDailyPrayerTimes
import com.mikhailspeaks.masjidly.widget.WidgetMosqueSnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerDaySnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshot
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerFocusScheduleTest {
    private val london = ZoneId.of("Europe/London")

    private fun at(iso: String): Instant = LocalDateTime.parse(iso).atZone(london).toInstant()

    private fun day(
        date: String,
        fajr: String = "05:00",
        dhuhr: String = "13:00",
        asr: String = "16:00",
        maghrib: String = "19:00",
        isha: String = "20:30",
        iqamah: WidgetDailyIqamahTimes = WidgetDailyIqamahTimes(
            fajr = "05:20",
            dhuhr = "13:30",
            asr = "16:15",
            maghrib = "sunset",
            isha = "21:00",
            jummah = "13:15, 14:00",
        ),
    ) = WidgetPrayerDaySnapshot(
        date = date,
        prayers = WidgetDailyPrayerTimes(date, fajr, "06:30", dhuhr, asr, maghrib, isha),
        iqamah = iqamah,
    )

    private fun snapshot(vararg days: WidgetPrayerDaySnapshot) = WidgetPrayerSnapshot(
        schemaVersion = WidgetPrayerSnapshot.CURRENT_SCHEMA_VERSION,
        generatedAt = "2026-10-07T00:00:00Z",
        mosque = WidgetMosqueSnapshot(id = "m1", name = "Test Masjid", slug = "test-masjid"),
        days = days.toList(),
        uses24HourTime = true,
        appLanguageRawValue = "english",
        asrIqamahPreference = "first",
    )

    @Test
    fun buildsOneWindowPerSelectedPrayerFromAdhan() {
        val windows = PrayerFocusScheduleBuilder.windows(
            snapshot = snapshot(day("2026-10-07")),
            settings = PrayerFocusSettings(isEnabled = true, durationMinutes = 20),
            now = at("2026-10-07T00:00"),
            zone = london,
        )
        assertEquals(5, windows.size)
        assertEquals(at("2026-10-07T05:00").toEpochMilli(), windows[0].startEpochMillis)
        assertEquals(at("2026-10-07T05:20").toEpochMilli(), windows[0].endEpochMillis)
        assertEquals(PrayerFocusPrayer.ISHA, windows.last().prayer)
    }

    @Test
    fun usesIqamahAndJummahOnFriday() {
        // 2026-10-09 is a Friday.
        val windows = PrayerFocusScheduleBuilder.windows(
            snapshot = snapshot(day("2026-10-09")),
            settings = PrayerFocusSettings(
                isEnabled = true,
                start = PrayerFocusStart.IQAMAH,
                prayers = setOf(PrayerFocusPrayer.FAJR, PrayerFocusPrayer.DHUHR, PrayerFocusPrayer.MAGHRIB),
            ),
            now = at("2026-10-09T00:00"),
            zone = london,
        )
        assertEquals(
            listOf(at("2026-10-09T05:20"), at("2026-10-09T13:15"), at("2026-10-09T19:00")).map { it.toEpochMilli() },
            windows.map { it.startEpochMillis },
        )
        assertTrue(windows[1].isFriday)
    }

    @Test
    fun skipsMissingAndNonClockTimesWithoutSubstituting() {
        val windows = PrayerFocusScheduleBuilder.windows(
            snapshot = snapshot(
                day(
                    "2026-10-07",
                    fajr = "",
                    isha = "--:--",
                    iqamah = WidgetDailyIqamahTimes("", "13:30", "16:15", "sunset", "After Maghrib", ""),
                ),
                day("not-a-date"),
            ),
            settings = PrayerFocusSettings(isEnabled = true, start = PrayerFocusStart.IQAMAH),
            now = at("2026-10-07T00:00"),
            zone = london,
        )
        val prayers = windows.map { it.prayer }
        assertEquals(listOf(PrayerFocusPrayer.DHUHR, PrayerFocusPrayer.ASR, PrayerFocusPrayer.MAGHRIB), prayers)
    }

    @Test
    fun mergesOverlapsKeepingEarlierPrayer() {
        val windows = PrayerFocusScheduleBuilder.windows(
            snapshot = snapshot(day("2026-10-07", maghrib = "19:00", isha = "19:30")),
            settings = PrayerFocusSettings(
                isEnabled = true,
                durationMinutes = 45,
                prayers = setOf(PrayerFocusPrayer.MAGHRIB, PrayerFocusPrayer.ISHA),
            ),
            now = at("2026-10-07T00:00"),
            zone = london,
        )
        assertEquals(1, windows.size)
        assertEquals(PrayerFocusPrayer.MAGHRIB, windows[0].prayer)
        assertEquals(at("2026-10-07T20:15").toEpochMilli(), windows[0].endEpochMillis)
    }

    @Test
    fun dropsExpiredAndSuppressedWindowsButKeepsTheActiveOne() {
        val snap = snapshot(day("2026-10-07"))
        val settings = PrayerFocusSettings(isEnabled = true)
        val now = at("2026-10-07T13:05")

        val active = PrayerFocusScheduleBuilder.windows(snap, settings, now, zone = london)
        assertEquals(PrayerFocusPrayer.DHUHR, active.first().prayer)
        assertEquals(active.first(), PrayerFocusScheduleBuilder.activeWindow(active, now.toEpochMilli()))

        // Stop ends only the current window; later prayers still apply.
        val stopped = PrayerFocusScheduleBuilder.windows(snap, settings, now, suppressedUntil = at("2026-10-07T13:15"), zone = london)
        assertEquals(PrayerFocusPrayer.ASR, stopped.first().prayer)
        assertNull(PrayerFocusScheduleBuilder.activeWindow(stopped, now.toEpochMilli()))
    }

    @Test
    fun enforcesMinimumDurationAndReturnsNothingWithNoPrayers() {
        val snap = snapshot(day("2026-10-07"))
        val short = PrayerFocusScheduleBuilder.windows(
            snap,
            PrayerFocusSettings(isEnabled = true, durationMinutes = 1, prayers = setOf(PrayerFocusPrayer.ASR)),
            at("2026-10-07T00:00"),
            zone = london,
        )
        assertEquals(15 * 60_000L, short.single().endEpochMillis - short.single().startEpochMillis)

        val none = PrayerFocusScheduleBuilder.windows(
            snap,
            PrayerFocusSettings(isEnabled = true, prayers = emptySet()),
            at("2026-10-07T00:00"),
            zone = london,
        )
        assertTrue(none.isEmpty())
    }

    @Test
    fun windowsAreTimetableInstantsAcrossDstAndDeviceZones() {
        // 2026-10-25 is the UK clock change; 05:00 is GMT that morning, BST the day before.
        val windows = PrayerFocusScheduleBuilder.windows(
            snapshot = snapshot(day("2026-10-24"), day("2026-10-25")),
            settings = PrayerFocusSettings(isEnabled = true, prayers = setOf(PrayerFocusPrayer.FAJR)),
            now = at("2026-10-24T00:00"),
            zone = london,
        )
        assertEquals(Instant.parse("2026-10-24T04:00:00Z").toEpochMilli(), windows[0].startEpochMillis)
        assertEquals(Instant.parse("2026-10-25T05:00:00Z").toEpochMilli(), windows[1].startEpochMillis)
    }

    @Test
    fun nextBoundaryIsTheNearestFutureStartOrEnd() {
        val windows = listOf(
            PrayerFocusWindow(100, 200, PrayerFocusPrayer.FAJR),
            PrayerFocusWindow(300, 400, PrayerFocusPrayer.DHUHR),
        )
        assertEquals(100L, PrayerFocusScheduleBuilder.nextBoundary(windows, 50))
        assertEquals(200L, PrayerFocusScheduleBuilder.nextBoundary(windows, 150))
        assertEquals(300L, PrayerFocusScheduleBuilder.nextBoundary(windows, 200))
        assertNull(PrayerFocusScheduleBuilder.nextBoundary(windows, 400))
    }
}
