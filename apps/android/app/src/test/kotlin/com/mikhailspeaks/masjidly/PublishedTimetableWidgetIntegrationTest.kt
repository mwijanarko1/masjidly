package com.mikhailspeaks.masjidly

import com.mikhailspeaks.masjidly.domain.DailyIqamahTimes
import com.mikhailspeaks.masjidly.domain.DailyPrayerTimes
import com.mikhailspeaks.masjidly.domain.HeroCountdownLabelKind
import com.mikhailspeaks.masjidly.domain.IqamahTimeRange
import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.PrayerTime
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import com.mikhailspeaks.masjidly.domain.RamadanPrayerDay
import com.mikhailspeaks.masjidly.widget.WidgetDailyIqamahTimes
import com.mikhailspeaks.masjidly.widget.WidgetDailyPrayerTimes
import com.mikhailspeaks.masjidly.widget.WidgetMosqueSnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerDaySnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerState
import com.mikhailspeaks.masjidly.widget.WidgetResolver
import com.mikhailspeaks.masjidly.widget.WidgetStateKind
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.hamcrest.CoreMatchers.equalTo
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.ErrorCollector

/**
 * Integration fallback: timetable resolution -> persisted widget payload -> widget UI state.
 * Home and the snapshot/notification services require Android Context and read Instant.now().
 * No Robolectric or controllable Main dispatcher is configured in this JVM target.
 * Resolution below is setup at the same seam used by WidgetPrayerSnapshotService, not
 * an isolated engine test.
 */
class PublishedTimetableWidgetIntegrationTest {
    @get:Rule val errors = ErrorCollector()
    private val london = ZoneId.of("Europe/London")
    private val json = Json { encodeDefaults = true }

    @Test fun october23DisplaysPublishedRowWithoutSubtractingAnHour() {
        val snapshot = publishedSnapshot("2026-10-23")
        expectPublishedClocks(snapshot)
        val state = WidgetResolver.resolve(snapshot, pinned("2026-10-23"))
        expectAdhanRows(state, listOf("06:01", "16:04", "18:05", "20:06"))
    }

    @Test fun october27UsesOctoberRangeNotMappedDay3OrNovember() {
        // Put a distinct November payload through the same serialization boundary.
        // The October request must still use the October calendar day's late range.
        val november = publishedSnapshot("2026-11-03")
        assertEquals("07:44", november.days.single().iqamah.fajr)
        val snapshot = publishedSnapshot("2026-10-27")
        val state = WidgetResolver.resolve(snapshot, pinned("2026-10-27"))
        errors.checkThat("October 27 iqamah", state.rows.map { it.iqamahs.single() },
            equalTo(listOf("06:32", "13:32", "16:32", "18:32", "20:32")))
    }

    @Test fun march23DisplaysPublishedRowAndRange() = checkMarch("2026-03-23", "test-masjid", false)
    @Test fun march30DisplaysPublishedRowAndRange() = checkMarch("2026-03-30", "test-masjid", true)
    @Test fun risalahMarch23DoesNotReplacePublishedIqamah() = checkMarch("2026-03-23", "masjid-risalah", false)
    @Test fun risalahMarch30DoesNotReplacePublishedIqamah() = checkMarch("2026-03-30", "masjid-risalah", true)

    @Test fun alHudaOctober24DisplaysCalendarRow24NotShiftedRow22() {
        val snapshot = publishedSnapshot("2026-10-24", "masjid-al-huda-sheffield")
        val prayers = snapshot.days.single().prayers
        errors.checkThat("calendar day 24 payload", clocks(prayers),
            equalTo(listOf("06:24", "07:24", "12:10", "15:24", "17:24", "19:24")))
        val state = WidgetResolver.resolve(snapshot, pinned("2026-10-24"))
        errors.checkThat("calendar day 24 widget", state.rows.map { it.adhan },
            equalTo(listOf("06:24", "12:10", "15:24", "17:24", "19:24")))
    }

    @Test fun ordinaryJanuaryDateIsUnchanged() {
        val snapshot = publishedSnapshot("2026-01-15")
        expectPublishedClocks(snapshot)
        val state = WidgetResolver.resolve(snapshot, pinned("2026-01-15"))
        assertEquals(WidgetStateKind.CONTENT, state.kind)
        assertEquals(listOf("06:01", "13:03", "16:04", "18:05", "20:06"), state.rows.map { it.adhan })
        assertEquals(listOf("06:22", "13:22", "16:22", "18:22", "20:22"), state.rows.map { it.iqamahs.single() })
    }

    @Test fun ramadanDateSelectsRamadanRowsInsteadOfMonthlyRows() {
        val snapshot = publishedSnapshot("2026-02-20")
        val state = WidgetResolver.resolve(snapshot, pinned("2026-02-20"))
        assertEquals(listOf("05:03", "06:03", "12:03", "15:03", "17:03", "19:03"), clocks(snapshot.days.single().prayers))
        assertEquals(WidgetStateKind.CONTENT, state.kind)
        // February 20 is Friday: Dhuhr is presented as Jummah by the real widget.
        assertEquals(listOf("05:03", "12:43", "15:03", "17:03", "19:03"), state.rows.map { it.adhan })
        assertEquals(listOf("05:33", "12:43", "15:33", "17:33", "19:33"), state.rows.map { it.iqamahs.single() })
    }

    @Test fun publishedWidgetEventsKeepLondonOffsetsAcrossBothClockChanges() {
        // Notification scheduler has no pinned-date entry point. These are the
        // real widget's event instants, not evidence of AlarmManager submission.
        val examples = listOf(
            Triple("2026-10-24", "2026-10-24T05:00:00Z", "2026-10-24T05:20:00Z"),
            Triple("2026-10-26", "2026-10-26T06:00:00Z", "2026-10-26T06:20:00Z"),
            Triple("2026-03-28", "2026-03-28T06:00:00Z", "2026-03-28T06:20:00Z"),
            Triple("2026-03-30", "2026-03-30T05:00:00Z", "2026-03-30T05:20:00Z"),
        )
        for ((date, expectedAdhan, expectedIqamah) in examples) {
            val snapshot = roundTrip(snapshot(date, "test-masjid",
                DailyPrayerTimes(date, "06:00", "07:00", "13:00", "16:00", "18:00", "20:00"),
                DailyIqamahTimes("06:20", "13:20", "16:20", "18:20", "20:20", "13:40")))
            val beforeAdhan = WidgetResolver.resolve(snapshot, Instant.parse(expectedAdhan).minusSeconds(1))
            assertEquals("Fajr", beforeAdhan.prayerName)
            assertEquals("06:00", beforeAdhan.adhanTime)
            assertEquals(Instant.parse(expectedAdhan).toEpochMilli(), beforeAdhan.targetDateEpochMillis)
            val afterAdhan = WidgetResolver.resolve(snapshot, Instant.parse(expectedAdhan).plusSeconds(1))
            assertEquals("Fajr", afterAdhan.prayerName)
            assertEquals("06:20", afterAdhan.iqamahTime)
            assertEquals(HeroCountdownLabelKind.IQAMAH_IN, afterAdhan.countdownLabelKind)
            assertEquals(Instant.parse(expectedIqamah).toEpochMilli(), afterAdhan.targetDateEpochMillis)
            val afterIqamah = WidgetResolver.resolve(snapshot, Instant.parse(expectedIqamah).plusSeconds(1))
            assertEquals("Dhuhr", afterIqamah.prayerName)
        }
    }

    private fun checkMarch(date: String, slug: String, late: Boolean) {
        val snapshot = publishedSnapshot(date, slug)
        expectPublishedClocks(snapshot)
        val state = WidgetResolver.resolve(snapshot, pinned(date))
        expectAdhanRows(state, listOf("06:01", "16:04", "18:05", "20:06"))
        errors.checkThat("$slug $date iqamah", state.rows.map { it.iqamahs.single() },
            equalTo(if (late) listOf("06:32", "13:32", "16:32", "18:32", "20:32")
                else listOf("06:22", "13:22", "16:22", "18:22", "20:22")))
    }

    private fun expectPublishedClocks(snapshot: WidgetPrayerSnapshot) {
        errors.checkThat("published snapshot adhan and sunrise", clocks(snapshot.days.single().prayers),
            equalTo(listOf("06:01", "07:02", "13:03", "16:04", "18:05", "20:06")))
    }

    private fun expectAdhanRows(state: WidgetPrayerState, expected: List<String>) {
        assertEquals(WidgetStateKind.CONTENT, state.kind)
        errors.checkThat("widget adhan rows", state.rows.filter { it.id != "dhuhr" }.map { it.adhan }, equalTo(expected))
    }

    private fun clocks(p: WidgetDailyPrayerTimes) = listOf(p.fajr, p.sunrise, p.dhuhr, p.asr, p.maghrib, p.isha)
    private fun pinned(date: String) = LocalDate.parse(date).atTime(3, 0).atZone(london).toInstant()
    private fun roundTrip(value: WidgetPrayerSnapshot) = json.decodeFromString<WidgetPrayerSnapshot>(json.encodeToString(value))

    private fun publishedSnapshot(date: String, slug: String = "test-masjid"): WidgetPrayerSnapshot {
        val month = LocalDate.parse(date).monthValue
        val monthly = monthly(month, slug)
        val ramadan = if (date == "2026-02-20") RamadanPrayerData(
            month = "Ramadan", gregorianStart = "2026-02-18", gregorianEnd = "2026-03-19",
            prayerTimes = listOf(RamadanPrayerDay(3, date, "05:03", "06:03", "12:03", "15:03", maghrib = "17:03", isha = "19:03")),
            iqamahTimes = listOf(IqamahTimeRange("1-30", "05:33", "12:33", "15:33", "17:33", "19:33", "12:43")),
            jummahIqamah = "12:43",
        ) else null
        // This is the snapshot service's resolution seam, which cannot be reached
        // with a pinned date on the current JVM setup.
        val prayers = PrayerTimesEngine.resolvePrayerTimes(pinned(date), monthly, ramadan)
        val iqamah = PrayerTimesEngine.resolveIqamahTimes(pinned(date), monthly, ramadan)
        return roundTrip(snapshot(date, slug, prayers, iqamah))
    }

    private fun snapshot(date: String, slug: String, prayers: DailyPrayerTimes, iqamah: DailyIqamahTimes) = WidgetPrayerSnapshot(
        schemaVersion = 1, generatedAt = "${date}T00:00:00Z",
        mosque = WidgetMosqueSnapshot("published", "Published", slug),
        days = listOf(WidgetPrayerDaySnapshot(date,
            WidgetDailyPrayerTimes(prayers.date, prayers.fajr, prayers.sunrise, prayers.dhuhr, prayers.asr, prayers.maghrib, prayers.isha),
            WidgetDailyIqamahTimes(iqamah.fajr, iqamah.dhuhr, iqamah.asr, iqamah.maghrib, iqamah.isha, iqamah.jummah))),
        uses24HourTime = true, appLanguageRawValue = "english", asrIqamahPreference = "first",
    )

    private fun monthly(month: Int, slug: String): MonthPrayerData {
        val rows = (1..31).map { day ->
            if (month == 10 && slug == "masjid-al-huda-sheffield") {
                PrayerTime(day, "06:%02d".format(Locale.ROOT, day), "07:%02d".format(Locale.ROOT, day), if (day < 23) "13:10" else "12:10",
                    "15:%02d".format(Locale.ROOT, day), maghrib = "17:%02d".format(Locale.ROOT, day), isha = "19:%02d".format(Locale.ROOT, day))
            } else PrayerTime(day, "06:01", "07:02", "13:03", "16:04", maghrib = "18:05", isha = "20:06")
        }
        val ranges = if (month == 11) listOf(
            IqamahTimeRange("1-30", "07:44", "14:44", "17:44", "19:44", "21:44", "14:54"),
        ) else listOf(
            IqamahTimeRange("1-10", "06:12", "13:12", "16:12", "18:12", "20:12", "13:42"),
            IqamahTimeRange("11-25", "06:22", "13:22", "16:22", "18:22", "20:22", "13:42"),
            IqamahTimeRange("26-31", "06:32", "13:32", "16:32", "18:32", "20:32", "13:42"),
        )
        return MonthPrayerData(MonthName.from(month)!!.rawValue, rows, ranges, "13:42")
    }
}
