package com.mikhailspeaks.masjidly.domain

import java.time.Duration
import java.time.Instant
import kotlin.math.floor

/** Default mosque slug (matches iOS `MosqueDefaults.defaultSlug`). */
object MosqueDefaults {
    const val DEFAULT_MOSQUE_SLUG = "muslim-welfare-house"
}

data class Mosque(
    val id: String,
    val name: String,
    val address: String,
    val lat: Double,
    val lng: Double,
    val slug: String,
    val citySlug: String? = null,
    val cityName: String? = null,
    val countryCode: String? = null,
    val countryName: String? = null,
    val timezone: String? = null,
    val website: String? = null,
    val isHidden: Boolean? = null,
) {
    val isHiddenResolved: Boolean get() = isHidden ?: false
    val cityDisplayName: String get() = cityName ?: "Sheffield"

    /** Groups mosques for city pickers; stable for settings `selectedCityGroupingKey`. */
    val cityGroupingKey: String
        get() {
            val s = citySlug
            if (!s.isNullOrEmpty()) return "slug:$s"
            val label = cityName ?: cityDisplayName
            return "name:${label.lowercase()}"
        }
}

data class PrayerTime(
    val date: Int,
    val fajr: String,
    val shurooq: String,
    val dhuhr: String,
    val asr: String,
    val asrMithl2: String? = null,
    val maghrib: String,
    val isha: String,
)

data class IqamahTimeRange(
    val dateRange: String,
    val fajr: String,
    val dhuhr: String,
    val asr: String,
    val maghrib: String? = null,
    val isha: String,
    val jummah: String? = null,
)

data class MonthPrayerData(
    val month: String,
    val prayerTimes: List<PrayerTime>,
    val iqamahTimes: List<IqamahTimeRange>,
    val jummahIqamah: String,
)

data class RamadanPrayerDay(
    val ramadanDay: Int,
    val gregorian: String,
    val fajr: String,
    val shurooq: String,
    val dhuhr: String,
    val asr: String,
    val asrMithl2: String? = null,
    val maghrib: String,
    val isha: String,
)

data class RamadanPrayerData(
    val month: String,
    val gregorianStart: String,
    val gregorianEnd: String,
    val prayerTimes: List<RamadanPrayerDay>,
    val iqamahTimes: List<IqamahTimeRange>,
    val jummahIqamah: String,
)

data class DailyPrayerTimes(
    var date: String,
    var fajr: String,
    var sunrise: String,
    var dhuhr: String,
    var asr: String,
    var maghrib: String,
    var isha: String,
)

data class DailyIqamahTimes(
    var fajr: String,
    var dhuhr: String,
    var asr: String,
    var maghrib: String,
    var isha: String,
    var jummah: String,
)

data class UkDstYear(
    val year: Int,
    val startDate: String,
    val endDate: String,
)

data class UkDstCalendar(
    val ukDstDates: List<UkDstYear>,
)

enum class AsrIqamahPreference {
    FIRST,
    SECOND,
    ;

    companion object {
        fun fromWire(value: String?): AsrIqamahPreference =
            when (value?.lowercase()) {
                "second" -> SECOND
                else -> FIRST
            }
    }

    val wireValue: String
        get() = when (this) {
            FIRST -> "first"
            SECOND -> "second"
        }
}

typealias AsrTimingPreference = AsrIqamahPreference

data class NextPrayerCountdownResult(
    val nextName: String,
    val nextTime: String,
    val totalSeconds: Int,
    val isIqamah: Boolean,
    val isJummah: Boolean,
) {
    val hours: Int get() = totalSeconds / 3600
    val minutes: Int get() = (totalSeconds % 3600) / 60
    val seconds: Int get() = totalSeconds % 60
}

enum class HeroCountdownLabelKind {
    ADHAN_IN,
    IQAMAH_IN,
    NEXT_PRAYER,
    ;

    val wireValue: String
        get() = when (this) {
            ADHAN_IN -> "adhanIn"
            IQAMAH_IN -> "iqamahIn"
            NEXT_PRAYER -> "nextPrayer"
        }
}

/** Widget-aligned interval for the home hero progress ring (`MasjidlyWidgetResolver` semantics). */
data class HeroCountdownPresentation(
    val labelKind: HeroCountdownLabelKind,
    val targetDate: Instant,
    val progressStartDate: Instant,
) {
    fun remainingSeconds(at: Instant): Int =
        maxOf(0, floor(Duration.between(at, targetDate).toMillis() / 1000.0).toInt())

    /** Elapsed fraction of `[progressStartDate, targetDate]` — matches accessory widget ring. */
    fun progress01(at: Instant): Double {
        val spanMillis = Duration.between(progressStartDate, targetDate).toMillis().toDouble()
        if (spanMillis <= 0) return 0.0
        val elapsedMillis = Duration.between(progressStartDate, at).toMillis().toDouble()
        val t = elapsedMillis / spanMillis
        return minOf(1.0, maxOf(0.0, t))
    }
}

sealed class PrayerEngineError : Exception() {
    data class NoIqamahRange(val day: Int) : PrayerEngineError() {
        override val message: String = "No iqamah range found for day $day"
    }

    data object MissingMonthly : PrayerEngineError() {
        private fun readResolve(): Any = MissingMonthly
        override val message: String = "missingMonthly"
    }

    data object MissingDayRow : PrayerEngineError() {
        private fun readResolve(): Any = MissingDayRow
        override val message: String = "missingDayRow"
    }

    data object MissingRamadanRow : PrayerEngineError() {
        private fun readResolve(): Any = MissingRamadanRow
        override val message: String = "missingRamadanRow"
    }
}
