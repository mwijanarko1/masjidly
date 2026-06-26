package com.mikhailspeaks.masjidly.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import java.time.LocalDateTime

class PrayerTimesEngineCountdownTest {
    private val daily = DailyPrayerTimes(
        date = "2026-06-15",
        fajr = "04:00",
        sunrise = "05:00",
        dhuhr = "13:00",
        asr = "18:00",
        maghrib = "21:00",
        isha = "22:30",
    )

    private val iqamah = DailyIqamahTimes(
        fajr = "04:30",
        dhuhr = "13:20",
        asr = "18:10",
        maghrib = "21:05",
        isha = "22:45",
        jummah = "13:25",
    )

    private fun sheffieldInstant(year: Int, month: Int, day: Int, hour: Int, minute: Int) =
        LocalDateTime.of(year, month, day, hour, minute)
            .atZone(PrayerTimesEngine.sheffieldTimeZone)
            .toInstant()

    @Test
    fun heroCountdownLabelAdhanInBeforeFirstAdhan() {
        val now = sheffieldInstant(2026, 6, 15, 3, 0)
        val presentation = PrayerTimesEngine.heroCountdownPresentation(
            prayerTimes = daily,
            iqamahTimes = iqamah,
            mosqueSlug = "x",
            now = now,
        )

        assertNotNull(presentation)
        assertEquals(HeroCountdownLabelKind.ADHAN_IN, presentation!!.labelKind)
        assertEquals(3600, presentation.remainingSeconds(now))
    }

    @Test
    fun heroCountdownLabelNextPrayerAfterFajrWindow() {
        val now = sheffieldInstant(2026, 6, 15, 12, 0)
        val presentation = PrayerTimesEngine.heroCountdownPresentation(
            prayerTimes = daily,
            iqamahTimes = iqamah,
            mosqueSlug = "x",
            now = now,
        )

        assertNotNull(presentation)
        assertEquals(HeroCountdownLabelKind.NEXT_PRAYER, presentation!!.labelKind)
    }

    @Test
    fun heroCountdownIqamahPhase() {
        val now = sheffieldInstant(2026, 6, 15, 13, 5)
        val presentation = PrayerTimesEngine.heroCountdownPresentation(
            prayerTimes = daily,
            iqamahTimes = iqamah,
            mosqueSlug = "x",
            now = now,
        )

        assertNotNull(presentation)
        assertEquals(HeroCountdownLabelKind.IQAMAH_IN, presentation!!.labelKind)
        assertEquals(15 * 60, presentation.remainingSeconds(now))
    }

    @Test
    fun formatHeroCountdownClock() {
        assertEquals("-1:23:44", PrayerTimesEngine.formatHeroCountdownClock(5024))
        assertEquals("-18:42", PrayerTimesEngine.formatHeroCountdownClock(1122))
        assertEquals("-9:05", PrayerTimesEngine.formatHeroCountdownClock(545))
        assertEquals("-0:00", PrayerTimesEngine.formatHeroCountdownClock(0))
    }

    @Test
    fun duhaWindowFifteenMinutesAfterSunriseUntilBeforeDhuhr() {
        val window = PrayerTimesEngine.duhaWindow("05:00", "13:00")
        assertNotNull(window)
        assertEquals("05:15", window!!.start)
        assertEquals("12:45", window.end)
    }
}
