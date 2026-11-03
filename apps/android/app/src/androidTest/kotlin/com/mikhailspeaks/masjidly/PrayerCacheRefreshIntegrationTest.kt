package com.mikhailspeaks.masjidly

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import androidx.lifecycle.viewModelScope
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.domain.*
import com.mikhailspeaks.masjidly.features.home.HomeViewModel
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshotService
import java.io.File
import java.io.IOException
import java.time.Instant
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

// Device integration uses the real home model, Android settings and disk cache.
// Only the remote backend is controlled, avoiding writes to production Convex.
@RunWith(AndroidJUnit4::class)
class PrayerCacheRefreshIntegrationTest {
    @Test fun cachedTabRevalidatesAfterAnotherMosqueConsumedGlobalRevision() = runBlocking {
        val fixture = Fixture("masjid-risalah")
        try {
            fixture.backend.publishMWHS()
            fixture.cache.saveDataRevision(DataRevision(2.0, 2.0))
            val home = fixture.start()
            withContext(Dispatchers.Main) {
                fixture.settings.activeMosqueTabId = "muslim-welfare-house"
                home.applySelectionFromSettings(tabSwitch = true)
            }
            fixture.awaitIsha("19:30")
            assertEquals("muslim-welfare-house", home.uiState.value.selectedMosque?.slug)
            assertEquals("19:30", fixture.cachedMWHS()?.iqamahTimes?.first()?.isha)
        } finally { fixture.close() }
    }

    @Test fun foregroundInsideFiveMinutesFetchesChangedTimetable() = runBlocking {
        val fixture = Fixture()
        try {
            val home = fixture.start()
            assertEquals("20:15", home.uiState.value.iqamahTimes?.isha)
            fixture.backend.publishMWHS()
            withContext(Dispatchers.Main) { home.refreshFromNetworkIfStale() }
            fixture.awaitIsha("19:30")
            assertEquals("19:30", fixture.cachedMWHS()?.iqamahTimes?.first()?.isha)
        } finally { fixture.close() }
    }

    @Test fun relaunchRevalidatesMosqueEvenWhenGlobalRevisionMatches() = runBlocking {
        val fixture = Fixture()
        try {
            fixture.backend.publishMWHS()
            fixture.cache.saveDataRevision(DataRevision(2.0, 2.0))
            fixture.start()
            fixture.awaitIsha("19:30")
        } finally { fixture.close() }
    }

    @Test fun unchangedMosqueVersionAvoidsFullMonthlyDownload() = runBlocking {
        val fixture = Fixture()
        try {
            val home = fixture.start()
            withContext(Dispatchers.Main) { home.refreshFromNetworkIfStale() }
            assertEquals("20:15", home.uiState.value.iqamahTimes?.isha)
            assertEquals(0, fixture.backend.currentMonthRequests.get())
        } finally { fixture.close() }
    }

    @Test fun offlineActivationKeepsCachedTimetableVisible() = runBlocking {
        val fixture = Fixture("masjid-risalah")
        try {
            val home = fixture.start()
            fixture.backend.offline = true
            withContext(Dispatchers.Main) {
                fixture.settings.activeMosqueTabId = "muslim-welfare-house"
                home.applySelectionFromSettings(tabSwitch = true)
            }
            withTimeout(5_000) {
                home.uiState.first { it.selectedMosque?.slug == "muslim-welfare-house" && it.iqamahTimes != null }
            }
            assertEquals("20:15", home.uiState.value.iqamahTimes?.isha)
            assertNotNull(home.uiState.value.displayedPrayerTimes)
            assertEquals(HomeViewModel.LoadState.LOADED, home.uiState.value.loadState)
        } finally { fixture.close() }
    }

    private class Fixture(selected: String = "muslim-welfare-house") {
        val context = IsolatedContext(InstrumentationRegistry.getInstrumentation().targetContext)
        val backend = RefreshBackend()
        val settings = SettingsStore(context).apply {
            selectedMosqueId = selected
            selectedMosqueSlug = selected
            activeMosqueTabId = selected
            openMosqueTabIds = backend.mosques.map { it.id }
            hasCompletedOnboarding = true
            notifications = NotificationSettings(masterEnabled = false)
        }
        val cache = PrayerTimesDiskCache(context)
        val parts = PrayerTimesEngine.getDateInSheffield(Instant.now())
        val month = requireNotNull(MonthName.from(parts.month))
        private var home: HomeViewModel? = null

        init {
            cache.saveMosques(backend.mosques)
            cache.saveDataRevision(DataRevision(1.0, 1.0))
            backend.mosques.forEach {
                cache.saveMonthly(it.slug, month.rawValue, parts.year, RefreshBackend.monthly(month, "20:15"))
                cache.saveVersions(it.slug, month.rawValue, parts.year, backend.versions(it.slug))
            }
        }

        suspend fun start(): HomeViewModel {
            val model = withContext(Dispatchers.Main) {
                HomeViewModel(backend, settings, cache, PrayerNotificationScheduler(context, backend, cache),
                    WidgetPrayerSnapshotService(context, backend, settings, cache))
            }
            home = model
            withTimeout(10_000) { model.uiState.first { it.loadState == HomeViewModel.LoadState.LOADED } }
            return model
        }

        suspend fun awaitIsha(expected: String) {
            withTimeout(5_000) { requireNotNull(home).uiState.first { it.iqamahTimes?.isha == expected } }
        }

        fun cachedMWHS() = cache.loadMonthly("muslim-welfare-house", month.rawValue, parts.year)

        suspend fun close() {
            withContext(Dispatchers.Main) { home?.viewModelScope?.cancel() }
            context.cleanUp()
        }
    }

    private class IsolatedContext(base: Context) : ContextWrapper(base) {
        private val prefix = "cache-refresh-${UUID.randomUUID()}"
        private val directory = File(base.cacheDir, prefix).also { it.mkdirs() }
        private val preferenceNames = mutableSetOf<String>()
        override fun getApplicationContext(): Context = this
        override fun getFilesDir(): File = directory
        override fun getSharedPreferences(name: String, mode: Int): SharedPreferences {
            val isolatedName = "$prefix-$name"
            preferenceNames += isolatedName
            return super.getSharedPreferences(isolatedName, mode)
        }
        fun cleanUp() {
            preferenceNames.forEach { baseContext.deleteSharedPreferences(it) }
            directory.deleteRecursively()
        }
    }

    private class RefreshBackend : PrayerRepository {
        @Volatile var revision = 1.0
        @Volatile var offline = false
        val currentMonthRequests = AtomicInteger()
        val mosques = listOf("masjid-risalah", "muslim-welfare-house").map {
            Mosque(it, it, "", 53.38, -1.47, it, citySlug = "sheffield", timezone = "Europe/London")
        }
        fun publishMWHS() { revision = 2.0 }
        fun versions(slug: String) = PrayerDataVersions(1.0, if (slug == "muslim-welfare-house") revision else 1.0, 1.0, 1.0)
        private fun requireOnline() { if (offline) throw IOException("Backend unavailable") }
        override suspend fun listMosques(): List<Mosque> { requireOnline(); return mosques }
        override suspend fun getDataRevision(): DataRevision { requireOnline(); return DataRevision(revision, revision) }
        override suspend fun getPrayerDataVersions(mosqueSlug: String, month: MonthName, year: Int): PrayerDataVersions {
            requireOnline()
            return versions(mosqueSlug)
        }
        override suspend fun getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int): MonthPrayerData {
            requireOnline()
            val today = PrayerTimesEngine.getDateInSheffield(Instant.now())
            if (year == today.year && month == MonthName.from(today.month)) currentMonthRequests.incrementAndGet()
            return monthly(month, if (mosqueSlug == "muslim-welfare-house" && revision == 2.0) "19:30" else "20:15")
        }
        override suspend fun getRamadanTimetable(mosqueSlug: String, date: String?): RamadanPrayerData? {
            requireOnline()
            return null
        }
        companion object {
            fun monthly(month: MonthName, isha: String) = MonthPrayerData(month.rawValue,
                (1..31).map { PrayerTime(it, "05:04", "06:50", "11:50", "14:15", maghrib = "16:49", isha = "18:36") },
                listOf(IqamahTimeRange("1-31", "05:45", "13:10", "14:30", "16:49", isha, "12:45")), "12:45")
        }
    }
}
