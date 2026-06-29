package com.mikhailspeaks.masjidly.data.cache

import android.content.Context
import com.mikhailspeaks.masjidly.domain.CachedPrayerDataVersions
import com.mikhailspeaks.masjidly.domain.DataRevision
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerDataVersions
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import com.mikhailspeaks.masjidly.domain.UkDstCalendar
import java.io.File
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * JSON file cache — mirrors iOS `PrayerTimesDiskCache.swift`.
 */
class PrayerTimesDiskCache(context: Context) {
    private val cacheDir = File(context.applicationContext.filesDir, "PrayerTimesCache").also { it.mkdirs() }
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private fun file(name: String) = File(cacheDir, name)

    private fun safe(component: String): String =
        component.replace("/", "_").replace("\\", "_").replace(".", "_")

    private inline fun <reified T> load(name: String): T? {
        val f = file(name)
        if (!f.exists()) return null
        return runCatching { json.decodeFromString<T>(f.readText()) }.getOrNull()
    }

    private inline fun <reified T> save(name: String, value: T) {
        val target = file(name)
        val tmp = File(cacheDir, ".tmp_${System.nanoTime()}")
        tmp.writeText(json.encodeToString(value))
        if (target.exists()) target.delete()
        tmp.renameTo(target)
    }

    fun loadMosques(): List<Mosque>? =
        load<List<MosqueCache>>(MOSQUES_FILE)?.map { it.toDomain() }

    fun saveMosques(mosques: List<Mosque>) {
        save(MOSQUES_FILE, mosques.map { it.toCache() })
    }

    fun loadDataRevision(): DataRevision? =
        load<DataRevision>(DATA_REVISION_FILE)

    fun saveDataRevision(revision: DataRevision) {
        save(DATA_REVISION_FILE, revision)
    }

    fun loadUkDst(): UkDstCalendar? =
        load<UkDstCalendarCache>(UK_DST_FILE)?.toDomain()

    fun saveUkDst(dst: UkDstCalendar) {
        save(UK_DST_FILE, dst.toCache())
    }

    fun loadVersions(slug: String, month: String, year: Int): CachedPrayerDataVersions? =
        load<CachedPrayerDataVersions>(versionsFilename(slug, month, year))

    fun saveVersions(slug: String, month: String, year: Int, versions: PrayerDataVersions) {
        save(versionsFilename(slug, month, year), CachedPrayerDataVersions(versions, System.currentTimeMillis()))
    }

    fun loadMonthly(slug: String, month: String, year: Int): MonthPrayerData? {
        val name = monthlyFilename(slug, month, year)
        return load<MonthPrayerDataCache>(name)?.toDomain()
    }

    fun saveMonthly(slug: String, month: String, year: Int, data: MonthPrayerData) {
        save(monthlyFilename(slug, month, year), data.toCache())
    }

    fun removeMonthly(slug: String, month: String, year: Int) {
        file(monthlyFilename(slug, month, year)).delete()
    }

    fun loadRamadan(slug: String, date: String): RamadanPrayerData? {
        val name = ramadanFilename(slug, date)
        return load<RamadanPrayerDataCache>(name)?.toDomain()
    }

    fun saveRamadan(slug: String, date: String, data: RamadanPrayerData) {
        save(ramadanFilename(slug, date), data.toCache())
    }

    private fun monthlyFilename(slug: String, month: String, year: Int) =
        "monthly_${safe(slug)}_${month}_$year.json"

    private fun versionsFilename(slug: String, month: String, year: Int) =
        "versions_${safe(slug)}_${month}_$year.json"

    private fun ramadanFilename(slug: String, date: String) =
        "ramadan_${safe(slug)}_${safe(date)}.json"

    companion object {
        private const val MOSQUES_FILE = "mosques.json"
        private const val DATA_REVISION_FILE = "data_revision.json"
        private const val UK_DST_FILE = "uk_dst.json"
    }
}
