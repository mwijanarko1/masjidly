package com.mikhailspeaks.masjidly.features.prayerfocus

import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.DailyIqamahTimes
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.widget.WidgetPrayerDaySnapshot
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshot
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors iOS `PrayerFocusStart`. */
@Serializable
enum class PrayerFocusStart {
    @SerialName("adhan") ADHAN,
    @SerialName("iqamah") IQAMAH,
}

/** Mirrors iOS `PrayerFocusPrayer`. */
@Serializable
enum class PrayerFocusPrayer(val wireValue: String, val labelKey: String) {
    @SerialName("fajr") FAJR("fajr", "settings.notification.fajr"),
    @SerialName("dhuhr") DHUHR("dhuhr", "settings.notification.dhuhr_jummah"),
    @SerialName("asr") ASR("asr", "settings.notification.asr"),
    @SerialName("maghrib") MAGHRIB("maghrib", "settings.notification.maghrib"),
    @SerialName("isha") ISHA("isha", "settings.notification.isha"),
}

/**
 * Persisted Prayer Focus preferences. Selected packages stay on device; nothing is uploaded.
 * Mirrors iOS `PrayerFocusSettings`, with Android package names in place of Screen Time tokens.
 */
@Serializable
data class PrayerFocusSettings(
    val isEnabled: Boolean = false,
    val start: PrayerFocusStart = PrayerFocusStart.ADHAN,
    val durationMinutes: Int = 15,
    val prayers: Set<PrayerFocusPrayer> = PrayerFocusPrayer.entries.toSet(),
    val selectedPackages: Set<String> = emptySet(),
) {
    companion object {
        val durationOptions = listOf(15, 20, 30, 45, 60)
    }
}

@Serializable
data class PrayerFocusWindow(
    val startEpochMillis: Long,
    val endEpochMillis: Long,
    val prayer: PrayerFocusPrayer,
    /** Friday Dhuhr uses the Jummah label on the overlay. */
    val isFriday: Boolean = false,
) {
    fun contains(nowMillis: Long): Boolean = startEpochMillis <= nowMillis && nowMillis < endEpochMillis
}

object PrayerFocusScheduleBuilder {
    /** Matches the iOS minimum so both platforms offer the same durations. */
    const val MINIMUM_DURATION_MINUTES = 15

    /**
     * Builds bounded, non-overlapping windows from the active mosque's widget snapshot.
     * Timetable clock times are read in the timetable zone, so each window is an absolute instant
     * independent of the device zone. Overlapping windows are merged so one window ending can never
     * clear another. Missing or non-clock times are skipped, never substituted.
     */
    fun windows(
        snapshot: WidgetPrayerSnapshot,
        settings: PrayerFocusSettings,
        now: Instant,
        suppressedUntil: Instant? = null,
        zone: ZoneId = PrayerTimesEngine.sheffieldTimeZone,
    ): List<PrayerFocusWindow> {
        val durationMillis = maxOf(settings.durationMinutes, MINIMUM_DURATION_MINUTES) * 60_000L
        val preference = AsrIqamahPreference.fromWire(snapshot.asrIqamahPreference)
        val nowMillis = now.toEpochMilli()
        val suppressedMillis = suppressedUntil?.toEpochMilli() ?: Long.MIN_VALUE

        data class Start(val millis: Long, val prayer: PrayerFocusPrayer, val isFriday: Boolean)

        val starts = mutableListOf<Start>()
        for (day in snapshot.days) {
            val civilDay = runCatching { LocalDate.parse(day.date) }.getOrNull() ?: continue
            val isFriday = civilDay.dayOfWeek == DayOfWeek.FRIDAY
            val dayStart = civilDay.atStartOfDay(zone).toInstant()
            for (prayer in PrayerFocusPrayer.entries) {
                if (prayer !in settings.prayers) continue
                val adhan = adhanTime(prayer, day)
                val time = when (settings.start) {
                    PrayerFocusStart.ADHAN -> adhan
                    PrayerFocusStart.IQAMAH -> iqamahTime(prayer, day, adhan, isFriday, snapshot.mosque.slug, dayStart, preference)
                }
                val start = instant(time, civilDay, zone) ?: continue
                starts += Start(start.toEpochMilli(), prayer, isFriday && prayer == PrayerFocusPrayer.DHUHR)
            }
        }

        val merged = mutableListOf<PrayerFocusWindow>()
        for (item in starts.sortedBy { it.millis }) {
            val end = item.millis + durationMillis
            if (end <= nowMillis || end <= suppressedMillis) continue
            val last = merged.lastOrNull()
            if (last != null && item.millis <= last.endEpochMillis) {
                // Keep the earlier prayer's identity while the merged window is active.
                merged[merged.lastIndex] = last.copy(endEpochMillis = maxOf(last.endEpochMillis, end))
            } else {
                merged += PrayerFocusWindow(item.millis, end, item.prayer, item.isFriday)
            }
        }
        return merged
    }

    /** Next instant at which the active state can change: a window start or end after [nowMillis]. */
    fun nextBoundary(windows: List<PrayerFocusWindow>, nowMillis: Long): Long? =
        windows.asSequence()
            .flatMap { sequenceOf(it.startEpochMillis, it.endEpochMillis) }
            .filter { it > nowMillis }
            .minOrNull()

    fun activeWindow(windows: List<PrayerFocusWindow>, nowMillis: Long): PrayerFocusWindow? =
        windows.firstOrNull { it.contains(nowMillis) }

    private fun adhanTime(prayer: PrayerFocusPrayer, day: WidgetPrayerDaySnapshot): String = when (prayer) {
        PrayerFocusPrayer.FAJR -> day.prayers.fajr
        PrayerFocusPrayer.DHUHR -> day.prayers.dhuhr
        PrayerFocusPrayer.ASR -> day.prayers.asr
        PrayerFocusPrayer.MAGHRIB -> day.prayers.maghrib
        PrayerFocusPrayer.ISHA -> day.prayers.isha
    }

    private fun iqamahTime(
        prayer: PrayerFocusPrayer,
        day: WidgetPrayerDaySnapshot,
        adhan: String,
        isFriday: Boolean,
        slug: String,
        dayStart: Instant,
        preference: AsrIqamahPreference,
    ): String {
        val iq = DailyIqamahTimes(
            fajr = day.iqamah.fajr,
            dhuhr = day.iqamah.dhuhr,
            asr = day.iqamah.asr,
            maghrib = day.iqamah.maghrib,
            isha = day.iqamah.isha,
            jummah = day.iqamah.jummah,
        )
        if (prayer == PrayerFocusPrayer.ASR) {
            return PrayerTimesEngine.selectAsrIqamahTime(iq.asr, adhan, preference)
        }
        if (prayer == PrayerFocusPrayer.DHUHR && isFriday) {
            PrayerTimesEngine.splitJummahIqamahTimes(iq.jummah).firstOrNull()?.let { return it }
        }
        return PrayerTimesEngine.getDisplayIqamah(
            prayer = prayer.wireValue,
            adhanTime = adhan,
            iqamahTimes = iq,
            mosqueSlug = slug,
            date = dayStart,
            maghribAdhan = day.prayers.maghrib,
        )
    }

    private fun instant(hhmm: String, civilDay: LocalDate, zone: ZoneId): Instant? {
        val parts = hhmm.trim().split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return civilDay.atTime(hour, minute).atZone(zone).toInstant()
    }
}
