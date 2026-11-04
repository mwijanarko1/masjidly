package com.mikhailspeaks.masjidly

import com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind
import com.mikhailspeaks.masjidly.widget.WidgetDailyIqamahTimes
import com.mikhailspeaks.masjidly.widget.WidgetDailyPrayerTimes
import com.mikhailspeaks.masjidly.widget.WidgetMosqueSnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerDaySnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshot
import com.mikhailspeaks.masjidly.widget.WidgetResolver
import com.mikhailspeaks.masjidly.widget.WidgetStateKind
import java.time.Instant
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Integration fallback: persisted widget snapshot -> resolver -> lock screen state.
 * The widget UI requires an Android launcher host. This JVM seam reaches the real
 * resolver with pinned time; the lead verifies the lock screen on-device.
 */
class LockScreenWidgetStateIntegrationTest {
    private val json = Json { encodeDefaults = true }

    @Test fun sunriseIsLocalizedAndSeparateFromPrayerRowsAtItsWallClockBoundary() {
        for ((language, name) in listOf(
            "english" to "Sunrise",
            "arabic" to "الشروق",
            "urdu" to "طلوع آفتاب",
            "indonesian" to "Terbit",
        )) {
            val snapshot = snapshot(language)
            for ((now, passed) in listOf(
                "2026-07-06T05:59:59Z" to false,
                "2026-07-06T06:00:00Z" to true,
                "2026-07-06T06:00:01Z" to true,
            )) {
                val state = WidgetResolver.resolve(snapshot, Instant.parse(now))
                assertEquals(WidgetStateKind.CONTENT, state.kind)
                assertEquals(listOf("fajr", "dhuhr", "asr", "maghrib", "isha"), state.rows.map { it.id })
                val sunrise = state.sunriseRow
                assertNotNull("$language sunrise at $now", sunrise)
                requireNotNull(sunrise)
                assertEquals("sunrise", sunrise.id)
                assertEquals(name, sunrise.name)
                assertEquals("07:00", sunrise.adhan)
                assertEquals(emptyList<String>(), sunrise.iqamahs)
                assertFalse(sunrise.isNext)
                assertEquals("$language sunrise passed at $now", passed, sunrise.isPassed)
            }
        }
    }

    @Test fun sunriseUsesTheResolvedDayWhenFullTimetableRollsToTomorrow() {
        val state = WidgetResolver.resolve(
            snapshot(), Instant.parse("2026-07-06T20:00:00Z"), includeTomorrowFajr = false,
        )
        assertEquals(WidgetStateKind.CONTENT, state.kind)
        assertEquals(Instant.parse("2026-07-06T23:00:00Z").toEpochMilli(), state.displayDateEpochMillis)
        val sunrise = state.sunriseRow
        assertNotNull(sunrise)
        requireNotNull(sunrise)
        assertEquals("07:05", sunrise.adhan)
        assertFalse(sunrise.isPassed)
        assertFalse(state.rows.any { it.id == "sunrise" })
        assertFalse(state.rows.any { it.isTomorrow })
    }

    @Test fun onlyFajrIsMarkedTomorrowWhenTheNextEventIsTomorrowsFajr() {
        val snapshot = snapshot()
        val beforeIsha = WidgetResolver.resolve(snapshot, Instant.parse("2026-07-06T18:59:00Z"))
        assertEquals("isha", beforeIsha.prayerId)
        assertFalse(beforeIsha.rows.any { it.isTomorrow })

        val beforeIshaIqamah = WidgetResolver.resolve(snapshot, Instant.parse("2026-07-06T19:10:00Z"))
        assertEquals(HeroCountdownLabelKind.IQAMAH_IN, beforeIshaIqamah.countdownLabelKind)
        assertFalse(beforeIshaIqamah.rows.any { it.isTomorrow })

        val wrapped = WidgetResolver.resolve(
            snapshot, Instant.parse("2026-07-06T19:21:00Z"), includeTomorrowFajr = true,
        )
        assertEquals(WidgetStateKind.CONTENT, wrapped.kind)
        assertEquals("fajr", wrapped.prayerId)
        assertEquals("06:05", wrapped.adhanTime)
        assertEquals(listOf("fajr"), wrapped.rows.filter { it.isTomorrow }.map { it.id })
        assertEquals("06:05", wrapped.rows.single { it.id == "fajr" }.adhan)

        val notWrapped = WidgetResolver.resolve(
            snapshot, Instant.parse("2026-07-06T19:21:00Z"), includeTomorrowFajr = false,
        )
        assertEquals(WidgetStateKind.CONTENT, notWrapped.kind)
        assertEquals("isha", notWrapped.prayerId)
        assertFalse(notWrapped.rows.any { it.isTomorrow })
    }

    @Test fun progressStartsAtAdhanPreviousPrayerIshaOrLondonMidnight() {
        val snapshot = snapshot()
        // July is BST: these literal UTC instants must preserve London's +01:00 offset.
        val cases = listOf(
            Triple("2026-07-06T15:10:00Z", "asr", "2026-07-06T15:00:00Z"),
            Triple("2026-07-06T14:00:00Z", "asr", "2026-07-06T12:00:00Z"),
            Triple("2026-07-06T19:21:00Z", "fajr", "2026-07-06T19:00:00Z"),
            Triple("2026-07-06T04:00:00Z", "fajr", "2026-07-05T23:00:00Z"),
        )
        for ((now, prayerId, expectedStart) in cases) {
            val state = WidgetResolver.resolve(snapshot, Instant.parse(now))
            assertEquals(WidgetStateKind.CONTENT, state.kind)
            assertEquals("next prayer at $now", prayerId, state.prayerId)
            assertEquals(
                "progress start at $now",
                Instant.parse(expectedStart).toEpochMilli(), state.progressStartEpochMillis,
            )
        }
        val duringAsr = WidgetResolver.resolve(snapshot, Instant.parse("2026-07-06T15:10:00Z"))
        assertEquals(HeroCountdownLabelKind.IQAMAH_IN, duringAsr.countdownLabelKind)
        assertEquals(Instant.parse("2026-07-06T15:20:00Z").toEpochMilli(), duringAsr.targetDateEpochMillis)
    }

    @Test fun iqamahInstantUsesTheNextPrayersLondonDayAndIsNullForUnparseableTime() {
        val snapshot = snapshot()
        val normalDay = WidgetResolver.resolve(snapshot, Instant.parse("2026-07-06T14:00:00Z"))
        assertEquals("asr", normalDay.prayerId)
        assertEquals("16:20", normalDay.iqamahTime)
        assertEquals(Instant.parse("2026-07-06T15:20:00Z").toEpochMilli(), normalDay.iqamahEpochMillis)

        val tomorrow = WidgetResolver.resolve(snapshot, Instant.parse("2026-07-06T19:21:00Z"))
        assertEquals("fajr", tomorrow.prayerId)
        assertEquals("06:25", tomorrow.iqamahTime)
        assertEquals(Instant.parse("2026-07-07T05:25:00Z").toEpochMilli(), tomorrow.iqamahEpochMillis)

        val unparseable = roundTrip(snapshot.copy(days = snapshot.days.map { day ->
            if (day.date == "2026-07-06") day.copy(iqamah = day.iqamah.copy(asr = "Various")) else day
        }))
        val unknownIqamah = WidgetResolver.resolve(unparseable, Instant.parse("2026-07-06T14:00:00Z"))
        assertEquals("asr", unknownIqamah.prayerId)
        assertNull(unknownIqamah.iqamahEpochMillis)
    }

    private fun roundTrip(value: WidgetPrayerSnapshot) =
        json.decodeFromString<WidgetPrayerSnapshot>(json.encodeToString(value))

    private fun snapshot(language: String = "english") = roundTrip(WidgetPrayerSnapshot(
        schemaVersion = 1,
        generatedAt = "2026-07-06T00:00:00Z",
        mosque = WidgetMosqueSnapshot("lock-screen", "Lock Screen Masjid", "test-masjid"),
        days = listOf(
            WidgetPrayerDaySnapshot(
                date = "2026-07-06",
                prayers = WidgetDailyPrayerTimes("2026-07-06", "06:00", "07:00", "13:00", "16:00", "18:00", "20:00"),
                iqamah = WidgetDailyIqamahTimes("06:20", "13:20", "16:20", "18:20", "20:20", "13:40"),
            ),
            WidgetPrayerDaySnapshot(
                date = "2026-07-07",
                prayers = WidgetDailyPrayerTimes("2026-07-07", "06:05", "07:05", "13:05", "16:05", "18:05", "20:05"),
                iqamah = WidgetDailyIqamahTimes("06:25", "13:25", "16:25", "18:25", "20:25", "13:45"),
            ),
        ),
        uses24HourTime = true,
        appLanguageRawValue = language,
        asrIqamahPreference = "first",
    ))
}
