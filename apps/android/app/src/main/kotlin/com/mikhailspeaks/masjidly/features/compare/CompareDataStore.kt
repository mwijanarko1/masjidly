package com.mikhailspeaks.masjidly.features.compare

import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerDataVersions
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import java.net.ConnectException
import java.net.NoRouteToHostException
import java.net.UnknownHostException
import java.time.Instant
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

sealed interface CompareState {
    data object Idle : CompareState
    data object Loading : CompareState
    data class Loaded(val monthly: MonthPrayerData?, val ramadan: RamadanPrayerData?) : CompareState
    data object Failed : CompareState
    data object Offline : CompareState
}

/**
 * Loads monthly and Ramadan payloads for many masjids with a concurrency cap.
 * Cached payloads render first; missing or stale ones are fetched and written to the cache.
 * Not thread safe: call it from one dispatcher (the main thread).
 */
class CompareDataStore(
    private val repository: PrayerRepository,
    private val cache: CompareCache,
    maxConcurrent: Int = 6,
) {
    private val permits = maxOf(1, maxConcurrent)

    private val _revision = MutableStateFlow(0)

    /** Bumped whenever any payload or status changes so observers re-read [state]. */
    val revision: StateFlow<Int> = _revision.asStateFlow()

    private val monthlyMemory = mutableMapOf<String, MonthPrayerData>()
    private val ramadanMemory = mutableMapOf<String, RamadanPrayerData>()
    private val ramadanChecked = mutableSetOf<String>()
    private val verifiedMonths = mutableSetOf<String>()
    private val statuses = mutableMapOf<String, CompareState>()
    private var loadTask: Job? = null

    private class DayParts(val monthName: MonthName, val year: Int, val iso: String, slug: String) {
        val monthKey = "$slug|$year|${monthName.rawValue}"
        val ramadanKey = "$slug|$iso"
        val dayKey = "$slug|$iso"
    }

    private fun parts(mosque: Mosque, date: Instant): DayParts? {
        val p = PrayerTimesEngine.getDateInSheffield(date)
        val monthName = MonthName.from(p.month) ?: return null
        return DayParts(monthName, p.year, PrayerTimesEngine.isoDateString(p.year, p.month, p.day), mosque.slug)
    }

    private fun bump() {
        _revision.value += 1
    }

    // region Reading

    fun state(mosque: Mosque, date: Instant): CompareState {
        val p = parts(mosque, date) ?: return CompareState.Failed
        cachedMonthly(mosque, p)?.let { return CompareState.Loaded(it, cachedRamadan(mosque, p)) }
        return statuses[p.dayKey] ?: CompareState.Idle
    }

    private fun cachedMonthly(mosque: Mosque, p: DayParts): MonthPrayerData? {
        monthlyMemory[p.monthKey]?.let { return it }
        val disk = cache.loadMonthly(mosque.slug, p.monthName.rawValue, p.year) ?: return null
        monthlyMemory[p.monthKey] = disk
        return disk
    }

    private fun cachedRamadan(mosque: Mosque, p: DayParts): RamadanPrayerData? {
        ramadanMemory[p.ramadanKey]?.let { return it }
        val disk = cache.loadRamadan(mosque.slug, p.iso) ?: return null
        ramadanMemory[p.ramadanKey] = disk
        return disk
    }

    // endregion

    // region Loading

    suspend fun load(mosques: List<Mosque>, date: Instant) {
        cancel()
        val jobs = mosques.filter { mosque ->
            val p = parts(mosque, date) ?: return@filter false
            if (!needsWork(mosque, p)) return@filter false
            if (state(mosque, date) !is CompareState.Loaded) statuses[p.dayKey] = CompareState.Loading
            true
        }
        bump()
        if (jobs.isEmpty()) return

        // A root job, so [cancel] stops the fetches without cancelling the caller.
        val scope = CoroutineScope(currentCoroutineContext().minusKey(Job))
        val task = scope.launch {
            val gate = Semaphore(permits)
            jobs.forEach { mosque ->
                launch { gate.withPermit { perform(mosque, date) } }
            }
        }
        loadTask = task
        try {
            task.join()
        } catch (e: CancellationException) {
            task.cancel()
            throw e
        } finally {
            if (loadTask === task) loadTask = null
        }
    }

    /** Stops fetches in flight. Payloads already saved stay in the cache. */
    fun cancel() {
        loadTask?.cancel()
        loadTask = null
        val hadLoading = statuses.values.any { it == CompareState.Loading }
        statuses.entries.removeAll { it.value == CompareState.Loading }
        if (hadLoading) bump()
    }

    private fun needsWork(mosque: Mosque, p: DayParts): Boolean {
        if (cachedMonthly(mosque, p) == null) return true
        if (p.monthKey !in verifiedMonths) return true
        return cachedRamadan(mosque, p) == null && p.ramadanKey !in ramadanChecked
    }

    private suspend fun perform(mosque: Mosque, date: Instant) {
        val p = parts(mosque, date) ?: return
        coroutineContext.ensureActive()

        var monthly = cachedMonthly(mosque, p)
        var fetchedEmptyMonthly = false

        if (monthly != null) {
            if (p.monthKey !in verifiedMonths) {
                val versions = try {
                    repository.getPrayerDataVersions(mosque.slug, p.monthName, p.year)
                } catch (e: CancellationException) {
                    throw e
                } catch (_: Exception) {
                    null
                }
                coroutineContext.ensureActive()
                val cached = cache.loadVersions(mosque.slug, p.monthName.rawValue, p.year)
                if (versions != null && cached != null && cached.versions == versions) {
                    verifiedMonths += p.monthKey
                } else {
                    // A failed refresh keeps the cached payload; it is retried on the next load.
                    try {
                        val fresh = repository.getMonthlyPrayerTimes(mosque.slug, p.monthName, p.year)
                        coroutineContext.ensureActive()
                        store(fresh, mosque, p, versions)
                        monthly = usable(fresh)
                        fetchedEmptyMonthly = monthly == null
                    } catch (e: CancellationException) {
                        throw e
                    } catch (_: Exception) {
                    }
                }
            }
        } else {
            try {
                val fresh = repository.getMonthlyPrayerTimes(mosque.slug, p.monthName, p.year)
                coroutineContext.ensureActive()
                store(fresh, mosque, p, null)
                monthly = usable(fresh)
                fetchedEmptyMonthly = monthly == null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                statuses[p.dayKey] = classify(e)
                bump()
                return
            }
        }

        var ramadan = cachedRamadan(mosque, p)
        if (ramadan == null && p.ramadanKey !in ramadanChecked) {
            try {
                val fetched = repository.getRamadanTimetable(mosque.slug, p.iso)
                coroutineContext.ensureActive()
                ramadanChecked += p.ramadanKey
                if (fetched != null) {
                    ramadan = fetched
                    runCatching { cache.saveRamadan(mosque.slug, p.iso, fetched) }
                    ramadanMemory[p.ramadanKey] = fetched
                }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
            }
        }

        if (monthly == null || fetchedEmptyMonthly) {
            statuses[p.dayKey] = CompareState.Loaded(null, ramadan)
        } else {
            statuses.remove(p.dayKey)
        }
        bump()
    }

    private fun store(monthly: MonthPrayerData?, mosque: Mosque, p: DayParts, versions: PrayerDataVersions?) {
        if (monthly != null && monthly.prayerTimes.isNotEmpty()) {
            runCatching { cache.saveMonthly(mosque.slug, p.monthName.rawValue, p.year, monthly) }
            monthlyMemory[p.monthKey] = monthly
            if (versions != null) {
                runCatching { cache.saveVersions(mosque.slug, p.monthName.rawValue, p.year, versions) }
            }
            verifiedMonths += p.monthKey
        } else {
            cache.removeMonthly(mosque.slug, p.monthName.rawValue, p.year)
            monthlyMemory.remove(p.monthKey)
        }
    }

    private fun usable(monthly: MonthPrayerData?): MonthPrayerData? =
        monthly?.takeIf { it.prayerTimes.isNotEmpty() }

    private fun classify(error: Exception): CompareState = when (error) {
        is UnknownHostException, is ConnectException, is NoRouteToHostException ->
            CompareState.Offline
        else -> CompareState.Failed
    }

    // endregion
}
