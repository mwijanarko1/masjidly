package com.mikhailspeaks.masjidly.features.compare

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import java.time.Instant
import java.time.ZoneOffset
import kotlin.math.max
import kotlin.math.min

/**
 * State for the Compare screen. Plain class with Compose state so the screen recomposes on change.
 * Payload changes come from [CompareDataStore.revision], which the screen observes.
 */
class CompareViewModel(
    mosques: List<Mosque>,
    private val homeMosque: Mosque?,
    private val settings: CompareSettings,
    private val store: CompareDataStore,
    initialDate: Instant,
    private val now: () -> Instant = { Instant.now() },
) {
    companion object {
        const val MAX_MASJIDS = 10
    }

    data class Row(
        val mosque: Mosque,
        val isYours: Boolean,
        val state: CompareState,
        val times: CompareDayTimes?,
        val deltas: Map<ComparePrayer, Int>,
    )

    private val mosques: List<Mosque> = MosqueSelection.visibleMosques(mosques)

    var date: Instant by mutableStateOf(normalized(initialDate))
        private set

    var sort: Pair<ComparePrayer, Boolean>? by mutableStateOf(null)
        private set

    /** Which time the Masjids grid emphasises, sorts by and diffs against yours. */
    var gridTimeType: CompareTimeType by mutableStateOf(CompareTimeType.JAMAAT)

    private var listVersion by mutableIntStateOf(0)
    private var modeState by mutableStateOf(settings.compareMode)

    var cityKey: String by mutableStateOf(initialCityKey())

    private var autoMinutes = CompareFindQuery.defaultMinutes(isToday = isToday, now = now())
    private var minutesCustomized = false
    private var queryValue by mutableStateOf(
        CompareFindQuery(null, CompareTimeType.JAMAAT, CompareDirection.AFTER, autoMinutes),
    )

    var query: CompareFindQuery
        get() = queryValue
        set(value) {
            queryValue = value
            if (value.minutes != autoMinutes) minutesCustomized = true
        }

    private fun initialCityKey(): String {
        val options = MosqueSelection.cityOptions(mosques)
        settings.selectedCityGroupingKey?.let { key -> if (options.any { it.first == key }) return key }
        homeMosque?.cityGroupingKey?.let { key -> if (options.any { it.first == key }) return key }
        return options.firstOrNull()?.first.orEmpty()
    }

    private fun normalized(date: Instant): Instant {
        val p = PrayerTimesEngine.getDateInSheffield(date)
        return PrayerTimesEngine.sheffieldNoonUTC(p.year, p.month, p.day)
    }

    var mode: CompareMode
        get() = modeState
        set(value) {
            settings.compareMode = value
            modeState = value
        }

    val yoursId: String? get() = homeMosque?.id

    // region Day

    val isToday: Boolean get() = sameSheffieldDay(date, now())

    val isFriday: Boolean get() = CompareDayResolver.isFridayInSheffield(date)

    fun stepDay(delta: Int) {
        date = date.atOffset(ZoneOffset.UTC).plusDays(delta.toLong()).toInstant()
        if (!minutesCustomized) {
            val minutes = CompareFindQuery.defaultMinutes(isToday = isToday, now = now())
            autoMinutes = minutes
            queryValue = queryValue.copy(minutes = minutes)
        }
    }

    private fun sameSheffieldDay(a: Instant, b: Instant): Boolean {
        val zone = PrayerTimesEngine.sheffieldTimeZone
        return a.atZone(zone).toLocalDate() == b.atZone(zone).toLocalDate()
    }

    // endregion

    // region Masjids mode

    /** Your home masjid is always first and always present. The masjids you add follow it. */
    val listedMosques: List<Mosque>
        get() {
            listVersion
            val byId = mosques.associateBy { it.id }
            val seen = mutableSetOf<String>()
            val ordered = mutableListOf<Mosque>()
            homeMosque?.let {
                seen += it.id
                ordered += it
            }
            for (id in settings.compareMosqueIds) {
                val mosque = byId[id] ?: continue
                if (seen.add(id)) ordered += mosque
            }
            return ordered
        }

    fun isYours(mosque: Mosque): Boolean = mosque.id == homeMosque?.id

    val canAddMore: Boolean get() = listedMosques.size < MAX_MASJIDS

    fun add(mosque: Mosque): Boolean {
        val current = listedMosques.map { it.id }
        if (mosque.id in current) return true
        if (current.size >= MAX_MASJIDS) return false
        val stored = settings.compareMosqueIds.filter { id -> mosques.any { it.id == id } }
        settings.compareMosqueIds = stored + mosque.id
        listVersion += 1
        return true
    }

    fun remove(mosque: Mosque) {
        if (isYours(mosque)) return
        settings.compareMosqueIds = settings.compareMosqueIds.filter { it != mosque.id }
        listVersion += 1
    }

    fun isListed(mosque: Mosque): Boolean {
        listVersion
        return isYours(mosque) || mosque.id in settings.compareMosqueIds
    }

    fun tapHeader(prayer: ComparePrayer) {
        val current = sort
        sort = when {
            current == null || current.first != prayer -> prayer to true
            current.second -> prayer to false
            else -> null
        }
    }

    private class Resolved(val mosque: Mosque, val state: CompareState, val times: CompareDayTimes?)

    private fun resolveTimes(mosque: Mosque): Resolved {
        val state = store.state(mosque, date)
        val times = (state as? CompareState.Loaded)?.let {
            CompareDayResolver.resolve(mosque, date, it.monthly, it.ramadan, settings.asrIqamahPreference)
        }
        return Resolved(mosque, state, times)
    }

    val rows: List<Row>
        get() {
            var resolved = listedMosques.map { resolveTimes(it) }
            val activeSort = sort
            if (activeSort != null) {
                val pinned = resolved.filter { it.mosque.id == yoursId }
                val rest = resolved.filter { it.mosque.id != yoursId }
                val keyed = rest.mapIndexed { index, row ->
                    Triple(index, row.times?.let { sortMinutes(it, activeSort.first) }, row)
                }
                val ordered = keyed.sortedWith { a, b ->
                    val x = a.second
                    val y = b.second
                    when {
                        x != null && y != null ->
                            if (x != y) (if (activeSort.second) x.compareTo(y) else y.compareTo(x)) else a.first.compareTo(b.first)
                        x == null && y == null -> a.first.compareTo(b.first)
                        x != null -> -1
                        else -> 1
                    }
                }
                resolved = pinned + ordered.map { it.third }
            }

            val yours = resolved.firstOrNull { it.mosque.id == yoursId }
            return resolved.map { entry ->
                val deltas = mutableMapOf<ComparePrayer, Int>()
                val yoursTimes = yours?.times
                val times = entry.times
                if (yours != null && yoursTimes != null && times != null &&
                    entry.mosque.id != yours.mosque.id &&
                    CompareDelta.isComparable(yours.mosque, entry.mosque)
                ) {
                    for (prayer in ComparePrayer.entries) {
                        deltaMinutes(yoursTimes, times, prayer)?.let { deltas[prayer] = it }
                    }
                }
                Row(entry.mosque, entry.mosque.id == yoursId, entry.state, entry.times, deltas)
            }
        }

    /** Masjids with the latest jamaat clock time per prayer, when at least two rows have one. */
    val highlightedMosqueIds: Map<ComparePrayer, Set<String>>
        get() {
            val loaded = rows
            val result = mutableMapOf<ComparePrayer, Set<String>>()
            for (prayer in ComparePrayer.entries) {
                val latest = loaded.mapNotNull { row ->
                    row.times?.iqamah?.get(prayer)?.mapNotNull { it.minutes }?.maxOrNull()?.let { row.mosque.id to it }
                }
                if (latest.size < 2) continue
                val top = latest.maxOf { it.second }
                result[prayer] = latest.filter { it.second == top }.map { it.first }.toSet()
            }
            return result
        }

    private fun adhanMinutes(times: CompareDayTimes, prayer: ComparePrayer): Int? =
        times.adhan[prayer]?.let { CompareSlot.fromEngineValue(it) }?.minutes

    private fun sortMinutes(times: CompareDayTimes, prayer: ComparePrayer): Int? = when (gridTimeType) {
        CompareTimeType.JAMAAT -> times.iqamah[prayer]?.mapNotNull { it.minutes }?.minOrNull()
        CompareTimeType.ADHAN -> adhanMinutes(times, prayer)
    }

    private fun deltaMinutes(yours: CompareDayTimes, other: CompareDayTimes, prayer: ComparePrayer): Int? =
        when (gridTimeType) {
            CompareTimeType.JAMAAT -> CompareDelta.minutes(yours.homeIqamah[prayer], other.iqamah[prayer].orEmpty())
            CompareTimeType.ADHAN -> {
                val base = adhanMinutes(yours, prayer)
                val value = adhanMinutes(other, prayer)
                if (base == null || value == null) null else value - base
            }
        }

    suspend fun loadMasjids() {
        store.load(listedMosques, date)
    }

    // endregion

    // region By time mode

    val cityOptions: List<Pair<String, String>> get() = MosqueSelection.cityOptions(mosques)

    val cityLabel: String get() = cityOptions.firstOrNull { it.first == cityKey }?.second.orEmpty()

    private val cityMosques: List<Mosque> get() = MosqueSelection.mosquesInCity(cityKey, mosques)

    val findResult: CompareFindResult
        get() {
            val entries = cityMosques.mapNotNull { mosque ->
                val state = store.state(mosque, date) as? CompareState.Loaded ?: return@mapNotNull null
                val times = CompareDayResolver.resolve(
                    mosque, date, state.monthly, state.ramadan, settings.asrIqamahPreference,
                ) ?: return@mapNotNull null
                CompareFinder.Entry(mosque, times)
            }
            return CompareFinder.search(query, entries)
        }

    val loadProgress: Pair<Int, Int>
        get() {
            val list = cityMosques
            return list.count { store.state(it, date) is CompareState.Loaded } to list.size
        }

    val failedCount: Int
        get() = cityMosques.count {
            val s = store.state(it, date)
            s == CompareState.Failed || s == CompareState.Offline
        }

    val isLoadingFind: Boolean
        get() = cityMosques.any {
            val s = store.state(it, date)
            s == CompareState.Idle || s == CompareState.Loading
        }

    /** The jamaat clock time Home shows for your masjid and [prayer] on the chosen day, when known. */
    fun yourJamaatMinutes(prayer: ComparePrayer): Int? {
        val home = homeMosque ?: return null
        val state = store.state(home, date) as? CompareState.Loaded ?: return null
        val times = CompareDayResolver.resolve(home, date, state.monthly, state.ramadan, settings.asrIqamahPreference)
        return times?.homeIqamah?.get(prayer)?.minutes
    }

    fun nudgeMinutes(delta: Int) {
        query = query.copy(minutes = min(1439, max(0, query.minutes + delta)))
    }

    /** Searches for jamaats strictly later than your masjid's for the chosen prayer. */
    fun searchLaterThanYours() {
        val prayer = query.prayer ?: return
        val yours = yourJamaatMinutes(prayer) ?: return
        query = query.copy(type = CompareTimeType.JAMAAT, direction = CompareDirection.AFTER, minutes = min(1439, yours + 1))
    }

    suspend fun loadFind() {
        store.load(cityMosques, date)
    }

    fun cancelLoading() {
        store.cancel()
    }

    /** Minutes between now and a hit on today's date; null on other days. */
    fun relativeMinutes(hit: CompareFindHit): Int? {
        if (!isToday) return null
        val local = now().atZone(PrayerTimesEngine.sheffieldTimeZone)
        return hit.minutes - (local.hour * 60 + local.minute)
    }

    // endregion
}
