package com.mikhailspeaks.masjidly.widget

import android.content.Context
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.domain.DailyIqamahTimes
import com.mikhailspeaks.masjidly.domain.DailyPrayerTimes
import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * Mirrors iOS `WidgetPrayerSnapshotService` — builds a 7-day snapshot and refreshes Glance widgets.
 */
class WidgetPrayerSnapshotService(
    private val context: Context,
    private val repository: PrayerRepository,
    private val settings: SettingsStore,
    private val diskCache: PrayerTimesDiskCache,
    private val store: WidgetSnapshotStore = WidgetSnapshotStore(context),
) {
    suspend fun refreshSnapshot(mosque: Mosque, days: Int = 7) {
        if (days <= 0) return
        runCatching {
            val snapshot = buildSnapshot(mosque, days)
            store.writeSnapshot(snapshot)
            updateAllMasjidlyWidgets(context)
        }
    }

    suspend fun refreshSnapshots(mosques: List<Mosque>, selectedMosque: Mosque?, days: Int = 7) {
        if (days <= 0) return
        val visible = MosqueSelection.visibleMosques(mosques)
        runCatching {
            store.writeMosqueDirectory(
                visible.map { mosque ->
                    WidgetMosqueSnapshot(
                        id = mosque.id,
                        name = mosque.name,
                        slug = mosque.slug,
                        citySlug = mosque.citySlug,
                        cityName = mosque.cityName,
                        countryCode = mosque.countryCode,
                        countryName = mosque.countryName,
                    )
                },
            )
        }

        selectedMosque?.let { refreshSnapshot(it, days) }

        for (mosque in visible) {
            if (mosque.id == selectedMosque?.id) continue
            runCatching {
                val snapshot = buildSnapshot(mosque, days)
                store.writeSnapshot(snapshot, updateDefault = false)
            }
        }

        updateAllMasjidlyWidgets(context)
    }

    private suspend fun buildSnapshot(mosque: Mosque, days: Int): WidgetPrayerSnapshot {
        val now = Instant.now()
        val dstCalendar = fetchUkDstCalendar()
        val dst = dstCalendar?.ukDstDates.orEmpty()
        val monthlyCache = mutableMapOf<String, com.mikhailspeaks.masjidly.domain.MonthPrayerData?>()
        val daySnapshots = mutableListOf<WidgetPrayerDaySnapshot>()

        for (offset in 0 until days) {
            val date = resolveDate(offsetByDays = offset, from = now)
            val parts = PrayerTimesEngine.getDateInSheffield(date)
            val monthName = MonthName.from(parts.month) ?: continue
            val monthCacheKey = "${mosque.slug}-${parts.year}-${monthName.rawValue}"
            val monthly = monthlyCache.getOrPut(monthCacheKey) {
                fetchMonthly(mosqueSlug = mosque.slug, month = monthName, year = parts.year)
            }

            val dateString = PrayerTimesEngine.isoDateString(parts.year, parts.month, parts.day)
            val ramadan = fetchRamadan(mosqueSlug = mosque.slug, date = dateString)
            try {
                val raw = PrayerTimesEngine.resolvePrayerTimes(
                    slug = mosque.slug,
                    on = date,
                    monthly = monthly,
                    ramadan = ramadan,
                    ukDst = dst,
                    asrTimingPreference = settings.asrIqamahPreference,
                )
                val displayed = PrayerTimesEngine.getDisplayedPrayerTimes(raw, date = date, mosqueSlug = mosque.slug)
                val iqamah = PrayerTimesEngine.resolveIqamahTimesWithDstMapping(
                    slug = mosque.slug,
                    on = date,
                    monthly = monthly,
                    ramadan = ramadan,
                    ukDst = dst,
                )
                daySnapshots += WidgetPrayerDaySnapshot(
                    date = dateString,
                    prayers = displayed.toWidgetDailyPrayerTimes(),
                    iqamah = iqamah.toWidgetDailyIqamahTimes(),
                )
            } catch (error: Throwable) {
                if (offset == 0) throw error
                break
            }
        }

        return WidgetPrayerSnapshot(
            schemaVersion = WidgetPrayerSnapshot.CURRENT_SCHEMA_VERSION,
            generatedAt = DateTimeFormatter.ISO_INSTANT.format(now.atOffset(ZoneOffset.UTC)),
            mosque = WidgetMosqueSnapshot(
                id = mosque.id,
                name = mosque.name,
                slug = mosque.slug,
                citySlug = mosque.citySlug,
                cityName = mosque.cityName,
                countryCode = mosque.countryCode,
                countryName = mosque.countryName,
            ),
            days = daySnapshots,
            uses24HourTime = settings.uses24HourTime,
            appLanguageRawValue = settings.appLanguage.wireValue,
            asrIqamahPreference = settings.asrIqamahPreference.wireValue,
        )
    }

    private suspend fun fetchUkDstCalendar() = runCatching {
        repository.getUkDstDates()?.also { diskCache.saveUkDst(it) }
    }.getOrNull() ?: diskCache.loadUkDst()

    private suspend fun fetchMonthly(
        mosqueSlug: String,
        month: MonthName,
        year: Int,
    ) = runCatching {
        repository.getMonthlyPrayerTimes(mosqueSlug, month, year)?.also {
            diskCache.saveMonthly(mosqueSlug, month.rawValue, year, it)
        }
    }.getOrNull() ?: diskCache.loadMonthly(mosqueSlug, month.rawValue, year)

    private suspend fun fetchRamadan(mosqueSlug: String, date: String) = runCatching {
        repository.getRamadanTimetable(mosqueSlug, date)?.also {
            diskCache.saveRamadan(mosqueSlug, date, it)
        }
    }.getOrNull() ?: diskCache.loadRamadan(mosqueSlug, date)

    private fun resolveDate(offsetByDays: Int, from: Instant): Instant {
        val zoned = from.atZone(PrayerTimesEngine.sheffieldTimeZone).plusDays(offsetByDays.toLong())
        return zoned.toInstant()
    }

    private fun DailyPrayerTimes.toWidgetDailyPrayerTimes() = WidgetDailyPrayerTimes(
        date = date,
        fajr = fajr,
        sunrise = sunrise,
        dhuhr = dhuhr,
        asr = asr,
        maghrib = maghrib,
        isha = isha,
    )

    private fun DailyIqamahTimes.toWidgetDailyIqamahTimes() = WidgetDailyIqamahTimes(
        fajr = fajr,
        dhuhr = dhuhr,
        asr = asr,
        maghrib = maghrib,
        isha = isha,
        jummah = jummah,
    )
}
