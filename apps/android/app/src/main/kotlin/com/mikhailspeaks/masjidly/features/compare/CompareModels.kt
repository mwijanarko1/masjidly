package com.mikhailspeaks.masjidly.features.compare

import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.CachedPrayerDataVersions
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerDataVersions
import com.mikhailspeaks.masjidly.domain.PrayerEngineError
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import java.time.DayOfWeek
import java.time.Instant
import kotlin.math.abs
import kotlin.math.min

/** Mirrors iOS `ComparePrayer`. */
enum class ComparePrayer {
    FAJR, DHUHR, ASR, MAGHRIB, ISHA;

    val key: String get() = name.lowercase()

    /** Canonical English name used for localization lookups. */
    fun canonicalName(isJummah: Boolean): String = when (this) {
        FAJR -> "Fajr"
        DHUHR -> if (isJummah) "Jummah" else "Dhuhr"
        ASR -> "Asr"
        MAGHRIB -> "Maghrib"
        ISHA -> "Isha"
    }
}

enum class CompareMode(val wire: String) {
    MASJIDS("masjids"),
    BY_TIME("byTime"),
    ;

    companion object {
        fun fromWire(value: String?): CompareMode = entries.firstOrNull { it.wire == value } ?: MASJIDS
    }
}

enum class CompareTimeType { JAMAAT, ADHAN }

enum class CompareDirection { AFTER, BEFORE }

/** Persisted Compare preferences. `SettingsStore` implements this. */
interface CompareSettings {
    var compareMosqueIds: List<String>
    var compareMode: CompareMode
    val asrIqamahPreference: AsrIqamahPreference
    val selectedCityGroupingKey: String? get() = null
}

/** The cache calls Compare needs. `PrayerTimesDiskCache` implements this. */
interface CompareCache {
    fun loadMonthly(slug: String, month: String, year: Int): MonthPrayerData?
    fun saveMonthly(slug: String, month: String, year: Int, data: MonthPrayerData)
    fun removeMonthly(slug: String, month: String, year: Int)
    fun loadVersions(slug: String, month: String, year: Int): CachedPrayerDataVersions?
    fun saveVersions(slug: String, month: String, year: Int, versions: PrayerDataVersions)
    fun loadRamadan(slug: String, date: String): RamadanPrayerData?
    fun saveRamadan(slug: String, date: String, data: RamadanPrayerData)
}

data class CompareSlot(val raw: String, val minutes: Int?) {
    companion object {
        private val clock = Regex("""^\d{1,2}:\d{2}$""")

        /** Builds a slot from an engine value. Null for empty or "no iqamah" values. */
        fun fromEngineValue(value: String): CompareSlot? {
            val trimmed = value.trim()
            if (trimmed.isEmpty() || trimmed == "-" || trimmed.lowercase() == "no iqamah") return null
            val minutes = if (clock.matches(trimmed)) PrayerTimesEngine.timeToMinutes(trimmed) else null
            return CompareSlot(trimmed, minutes)
        }
    }
}

data class CompareDayTimes(
    val isJummah: Boolean,
    val iqamah: Map<ComparePrayer, List<CompareSlot>>,
    val adhan: Map<ComparePrayer, String>,
    val homeIqamah: Map<ComparePrayer, CompareSlot>,
)

object CompareDayResolver {
    fun resolve(
        mosque: Mosque,
        date: Instant,
        monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?,
        asrPreference: AsrIqamahPreference,
    ): CompareDayTimes? {
        val daily: com.mikhailspeaks.masjidly.domain.DailyPrayerTimes
        val iq: com.mikhailspeaks.masjidly.domain.DailyIqamahTimes
        try {
            daily = PrayerTimesEngine.resolvePrayerTimes(date, monthly, ramadan, asrPreference)
            iq = PrayerTimesEngine.resolveIqamahTimes(date, monthly, ramadan)
        } catch (_: PrayerEngineError) {
            return null
        }
        val slug = mosque.slug
        val isJummah = isFridayInSheffield(date)

        fun display(prayer: String, adhan: String) =
            PrayerTimesEngine.getDisplayIqamah(prayer, adhan, iq, slug, date, daily.maghrib)

        val fajrValue = PrayerTimesEngine.getIqamahTime("fajr", daily.fajr, iq)
        val maghribValue = display("maghrib", daily.maghrib)
        val ishaValue = PrayerTimesEngine.resolveIshaIqamahForDisplay(slug, date, daily.isha, iq, daily.maghrib)
        val asrValue = PrayerTimesEngine.selectAsrIqamahTime(iq.asr, daily.asr, asrPreference)

        val jummahSlots = PrayerTimesEngine.splitJummahIqamahTimes(iq.jummah)
        val dhuhrHome: String
        val dhuhrSlots: List<String>
        if (isJummah) {
            dhuhrSlots = jummahSlots.ifEmpty { listOf(daily.dhuhr) }
            dhuhrHome = dhuhrSlots[0]
        } else {
            dhuhrHome = display("dhuhr", daily.dhuhr)
            dhuhrSlots = PrayerTimesEngine.splitIqamahTimes(dhuhrHome)
        }

        val rawSlots = mapOf(
            ComparePrayer.FAJR to PrayerTimesEngine.splitIqamahTimes(fajrValue),
            ComparePrayer.DHUHR to dhuhrSlots,
            ComparePrayer.ASR to PrayerTimesEngine.getAsrIqamahSlots(iq.asr, daily.asr),
            ComparePrayer.MAGHRIB to PrayerTimesEngine.splitIqamahTimes(maghribValue),
            ComparePrayer.ISHA to PrayerTimesEngine.splitIqamahTimes(ishaValue),
        )
        val homeValues = mapOf(
            ComparePrayer.FAJR to fajrValue,
            ComparePrayer.DHUHR to dhuhrHome,
            ComparePrayer.ASR to asrValue,
            ComparePrayer.MAGHRIB to maghribValue,
            ComparePrayer.ISHA to ishaValue,
        )

        val iqamah = mutableMapOf<ComparePrayer, List<CompareSlot>>()
        val home = mutableMapOf<ComparePrayer, CompareSlot>()
        for (prayer in ComparePrayer.entries) {
            iqamah[prayer] = (rawSlots[prayer] ?: emptyList()).mapNotNull { CompareSlot.fromEngineValue(it) }
            homeValues[prayer]?.let { value -> CompareSlot.fromEngineValue(value)?.let { home[prayer] = it } }
        }

        return CompareDayTimes(
            isJummah = isJummah,
            iqamah = iqamah,
            adhan = mapOf(
                ComparePrayer.FAJR to daily.fajr,
                ComparePrayer.DHUHR to daily.dhuhr,
                ComparePrayer.ASR to daily.asr,
                ComparePrayer.MAGHRIB to daily.maghrib,
                ComparePrayer.ISHA to daily.isha,
            ),
            homeIqamah = home,
        )
    }

    fun isFridayInSheffield(date: Instant): Boolean =
        date.atZone(PrayerTimesEngine.sheffieldTimeZone).dayOfWeek == DayOfWeek.FRIDAY
}

object CompareDelta {
    fun minutes(yours: CompareSlot?, other: List<CompareSlot>): Int? {
        val base = yours?.minutes ?: return null
        val earliest = other.mapNotNull { it.minutes }.minOrNull() ?: return null
        return earliest - base
    }

    fun label(minutes: Int): String {
        if (minutes == 0) return "0"
        val sign = if (minutes > 0) "+" else "-"
        val magnitude = abs(minutes)
        if (magnitude < 60) return "$sign$magnitude"
        val hours = magnitude / 60
        val rest = magnitude % 60
        return if (rest == 0) "$sign${hours}h" else "$sign${hours}h" + "%02d".format(rest)
    }

    /** Visible form: "+15m" under an hour, otherwise the same as [label]. */
    fun displayLabel(minutes: Int): String =
        if (abs(minutes) in 1..59) label(minutes) + "m" else label(minutes)

    fun isComparable(a: Mosque, b: Mosque): Boolean {
        val ta = a.timezone
        val tb = b.timezone
        if (!ta.isNullOrEmpty() && !tb.isNullOrEmpty()) return ta == tb
        val ca = a.countryCode
        val cb = b.countryCode
        if (!ca.isNullOrEmpty() && !cb.isNullOrEmpty()) return ca.equals(cb, ignoreCase = true)
        return false
    }
}

data class CompareFindQuery(
    val prayer: ComparePrayer?,
    val type: CompareTimeType,
    val direction: CompareDirection,
    val minutes: Int,
) {
    companion object {
        fun defaultMinutes(isToday: Boolean, now: Instant): Int {
            if (!isToday) return 720
            val local = now.atZone(PrayerTimesEngine.sheffieldTimeZone)
            val current = local.hour * 60 + local.minute
            return min(1435, (current / 5 + 1) * 5)
        }
    }
}

data class CompareFindHit(
    val mosque: Mosque,
    val prayer: ComparePrayer,
    val raw: String,
    val minutes: Int,
) {
    val id: String get() = "${mosque.id}.${prayer.key}.$raw"
}

/** [atTimeHits] are slots exactly at the chosen time. Only filled for "before", where they are excluded from [hits]. */
data class CompareFindResult(
    val hits: List<CompareFindHit>,
    val noFixedTimeCount: Int,
    val atTimeHits: List<CompareFindHit> = emptyList(),
)

object CompareFinder {
    data class Entry(val mosque: Mosque, val times: CompareDayTimes)

    fun search(query: CompareFindQuery, entries: List<Entry>): CompareFindResult {
        val scope = query.prayer?.let { listOf(it) } ?: ComparePrayer.entries
        val hits = mutableListOf<CompareFindHit>()
        val atTime = mutableListOf<CompareFindHit>()
        var noFixed = 0

        for (entry in entries) {
            var hasNoFixed = false
            for (prayer in scope) {
                val candidates: List<CompareSlot> = when (query.type) {
                    CompareTimeType.JAMAAT -> {
                        val slots = entry.times.iqamah[prayer].orEmpty()
                        val clocks = slots.filter { it.minutes != null }
                        if (slots.isNotEmpty() && clocks.isEmpty()) hasNoFixed = true
                        clocks
                    }
                    CompareTimeType.ADHAN ->
                        listOfNotNull(entry.times.adhan[prayer]?.let { CompareSlot.fromEngineValue(it) })
                }
                for (slot in candidates) {
                    val minutes = slot.minutes ?: continue
                    val matches = if (query.direction == CompareDirection.AFTER) minutes >= query.minutes else minutes < query.minutes
                    if (matches) {
                        hits += CompareFindHit(entry.mosque, prayer, slot.raw, minutes)
                    } else if (query.direction == CompareDirection.BEFORE && minutes == query.minutes) {
                        atTime += CompareFindHit(entry.mosque, prayer, slot.raw, minutes)
                    }
                }
            }
            if (hasNoFixed) noFixed += 1
        }

        val byName = compareBy<CompareFindHit, String>(String.CASE_INSENSITIVE_ORDER) { it.mosque.name }
        val comparator = Comparator<CompareFindHit> { a, b ->
            if (a.minutes != b.minutes) {
                if (query.direction == CompareDirection.AFTER) a.minutes.compareTo(b.minutes) else b.minutes.compareTo(a.minutes)
            } else {
                val name = byName.compare(a, b)
                if (name != 0) name else a.prayer.key.compareTo(b.prayer.key)
            }
        }
        val nameThenPrayer = Comparator<CompareFindHit> { a, b ->
            val name = byName.compare(a, b)
            if (name != 0) name else a.prayer.key.compareTo(b.prayer.key)
        }
        return CompareFindResult(hits.sortedWith(comparator), noFixed, atTime.sortedWith(nameThenPrayer))
    }
}
