package com.mikhailspeaks.masjidly.features.compare

import com.mikhailspeaks.masjidly.domain.AsrIqamahPreference
import com.mikhailspeaks.masjidly.domain.CachedPrayerDataVersions
import com.mikhailspeaks.masjidly.domain.IqamahTimeRange
import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.PrayerDataVersions
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.domain.PrayerTime
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import com.mikhailspeaks.masjidly.domain.RamadanPrayerDay
import java.net.ConnectException
import java.net.NoRouteToHostException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.time.DayOfWeek
import java.time.Instant
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Integration fallback: repository/cache -> Compare store -> view model -> real prayer engine.
 * The Android UI and SettingsStore require Context; no JVM UI fixture seam is configured.
 * Exhausting published timetable variations through a device UI is disproportionate.
 * Only the network, cache storage, settings storage, and clock boundaries are substituted.
 * Settings reuse below proves the view model's persistence contract, not SharedPreferences I/O.
 */
class CompareIntegrationTest {
    private val date = noon("2026-01-15")
    private val first = AsrIqamahPreference.FIRST
    private val second = AsrIqamahPreference.SECOND
    private val v1 = PrayerDataVersions(1.0, 1.0, 1.0, 1.0)
    private val v2 = PrayerDataVersions(1.0, 2.0, 1.0, 1.0)

    @Test fun publishedRelativeTimesAndAsrPreferencesMatchHomeThroughLoadedRows() = runBlocking {
        val mosque = mosque("published")
        val monthly = month(iq = iq(
            fajr = "adhan + 20", dhuhr = "15 minutes after adhan",
            asr = "15:45 / 16:15", maghrib = "sunset", isha = "Straight after Maghrib",
        ))
        val repo = Repository().apply { payloads[mosque.slug] = monthly }
        val store = CompareDataStore(repo, MemoryCache())
        for ((preference, homeAsr, adhanAsr) in listOf(
            Triple(first, "15:45", "15:00"), Triple(second, "16:15", "15:40"),
        )) {
            val vm = model(listOf(mosque), store, settings = Settings(listOf(mosque.id), preference))
            vm.loadMasjids()
            val times = requireNotNull(vm.rows.single().times)
            assertFalse(times.isJummah)
            assertEquals(listOf("06:20", "12:15", homeAsr, "17:00", "17:00"), homeClocks(times))
            assertEquals(listOf("15:45", "16:15"), times.iqamah[ComparePrayer.ASR]!!.map { it.raw })
            assertEquals(listOf(945, 975), times.iqamah[ComparePrayer.ASR]!!.map { it.minutes })
            assertEquals(adhanAsr, times.adhan[ComparePrayer.ASR])
            assertHomeParity(times, mosque, date, monthly, null, preference)
        }
    }

    @Test fun fridayUsesEveryJummahSlotAndMonthlyFallbackThenDhuhrAdhanWhenAbsent() = runBlocking {
        val friday = noon("2026-01-16")
        val mosque = mosque("friday")
        for ((rawJummah, expected) in listOf(
            "12:45 / 13:30" to listOf("12:45", "13:30"), "" to listOf("12:00"),
        )) {
            // Blank range Jummah must inherit the monthly Jummah, not ordinary Dhuhr iqamah.
            val monthly = month(iq = iq(dhuhr = "12:20", jummah = ""), jummah = rawJummah)
            val repo = Repository().apply { payloads[mosque.slug] = monthly }
            val vm = model(listOf(mosque), CompareDataStore(repo, MemoryCache()),
                initialDate = friday, settings = Settings(listOf(mosque.id)))
            vm.loadMasjids()
            val times = requireNotNull(vm.rows.single().times)
            assertTrue(times.isJummah)
            assertEquals(expected, times.iqamah[ComparePrayer.DHUHR]!!.map { it.raw })
            assertEquals(expected.first(), times.homeIqamah[ComparePrayer.DHUHR]!!.raw)
            assertEquals("12:00", times.adhan[ComparePrayer.DHUHR])
            assertHomeParity(times, mosque, friday, monthly, null, first)
        }
    }

    @Test fun ramadanOverridesMonthlyInBothModesAndKeepsAllSlots() = runBlocking {
        val ramadanDate = noon("2026-02-20")
        val mosque = mosque("ramadan")
        val monthly = month(MonthName.FEBRUARY)
        val ramadan = RamadanPrayerData(
            month = "Ramadan", gregorianStart = "2026-02-18", gregorianEnd = "2026-03-19",
            prayerTimes = listOf(RamadanPrayerDay(3, "2026-02-20", "05:03", "06:03", "12:03",
                "15:03", "15:23", "17:03", "19:03")),
            iqamahTimes = listOf(iq(fajr = "05:33", dhuhr = "12:33", asr = "15:33 / 16:03",
                maghrib = "17:33", isha = "19:33", jummah = "12:43 / 13:13").copy(dateRange = "1-30")),
            jummahIqamah = "12:43 / 13:13",
        )
        val cache = MemoryCache()
        val repo = Repository().apply {
            payloads[mosque.slug] = monthly
            ramadanPayloads[mosque.slug] = ramadan
        }
        val vm = model(listOf(mosque), CompareDataStore(repo, cache), initialDate = ramadanDate,
            settings = Settings(listOf(mosque.id), second))
        vm.loadMasjids()
        val times = requireNotNull(vm.rows.single().times)
        assertTrue(times.isJummah)
        assertEquals(listOf("05:33", "12:43", "16:03", "17:33", "19:33"), homeClocks(times))
        assertEquals("15:23", times.adhan[ComparePrayer.ASR])
        assertHomeParity(times, mosque, ramadanDate, monthly, ramadan, second)
        vm.query = CompareFindQuery(ComparePrayer.DHUHR, CompareTimeType.JAMAAT, CompareDirection.AFTER, 760)
        vm.loadFind()
        assertEquals(listOf("ramadan.dhuhr.12:43", "ramadan.dhuhr.13:13"), vm.findResult.hits.map { it.id })
        assertEquals(ramadan, cache.loadRamadan(mosque.slug, "2026-02-20"))
    }

    @Test fun summerRulesEntryTimeAndMissingValuesMatchHomeWithoutInventingClockTimes() = runBlocking {
        val summer = noon("2026-07-06")
        val monthly = month(MonthName.JULY, iq(fajr = "Various", asr = "Entry Time", isha = "20:30"))
        for ((slug, expectedIsha) in listOf(
            "muslim-welfare-house" to "After Maghrib", "masjid-risalah" to "19:00",
        )) {
            val mosque = mosque(slug)
            val repo = Repository().apply { payloads[slug] = monthly }
            val vm = model(listOf(mosque), CompareDataStore(repo, MemoryCache()), initialDate = summer,
                settings = Settings(listOf(mosque.id), second))
            vm.loadMasjids()
            val times = requireNotNull(vm.rows.single().times)
            assertEquals(listOf("06:00", "12:20", "15:40", "17:20", expectedIsha), homeClocks(times))
            assertEquals(listOf("15:40"), times.iqamah[ComparePrayer.ASR]!!.map { it.raw })
            assertEquals(if (slug == "muslim-welfare-house") null else 1140,
                times.homeIqamah[ComparePrayer.ISHA]!!.minutes)
            assertHomeParity(times, mosque, summer, monthly, null, second)
        }
        val mosque = mosque("missing")
        val missing = month(iq = iq(fajr = "", dhuhr = "-", asr = "No Iqamah", isha = "After Maghrib"))
        val repo = Repository().apply { payloads[mosque.slug] = missing }
        val vm = model(listOf(mosque), CompareDataStore(repo, MemoryCache()), settings = Settings(listOf(mosque.id)))
        vm.loadMasjids()
        val times = requireNotNull(vm.rows.single().times)
        for (prayer in listOf(ComparePrayer.FAJR, ComparePrayer.DHUHR, ComparePrayer.ASR)) {
            assertEquals(emptyList<CompareSlot>(), times.iqamah[prayer])
            assertNull(times.homeIqamah[prayer])
        }
        assertNull(times.iqamah[ComparePrayer.ISHA]!!.single().minutes)
        assertNull(CompareDayResolver.resolve(mosque, date, null, null, first))
    }

    @Test fun finderUsesInclusiveBoundariesEverySlotAndNameTiesNotAdhanForJamaat() = runBlocking {
        val alpha = mosque("alpha", name = "Alpha")
        val beta = mosque("beta", name = "Beta")
        val text = mosque("text")
        val mixed = mosque("mixed")
        val empty = mosque("empty")
        val repo = Repository().apply {
            payloads[alpha.slug] = month(iq = iq(asr = "15:45 / 16:15", isha = "19:00"))
            payloads[beta.slug] = month(iq = iq(asr = "15:45 / 16:00", isha = "19:00"))
            payloads[text.slug] = month(iq = iq(asr = "After Maghrib", isha = "After Maghrib"))
            payloads[mixed.slug] = month(iq = iq(asr = "After Maghrib / 16:30"))
            payloads[empty.slug] = month(iq = iq(asr = "No Iqamah"))
        }
        val vm = model(listOf(beta, text, mixed, empty, alpha), CompareDataStore(repo, MemoryCache()))
        vm.loadFind()
        vm.query = CompareFindQuery(ComparePrayer.ASR, CompareTimeType.JAMAAT, CompareDirection.AFTER, 945)
        assertEquals(listOf("alpha.asr.15:45", "beta.asr.15:45", "beta.asr.16:00",
            "alpha.asr.16:15", "mixed.asr.16:30"), vm.findResult.hits.map { it.id })
        assertEquals(listOf(945, 945, 960, 975, 990), vm.findResult.hits.map { it.minutes })
        assertEquals(1, vm.findResult.noFixedTimeCount)
        vm.query = vm.query.copy(direction = CompareDirection.BEFORE, minutes = 960)
        assertEquals(listOf("beta.asr.16:00", "alpha.asr.15:45", "beta.asr.15:45"), vm.findResult.hits.map { it.id })
        vm.query = vm.query.copy(type = CompareTimeType.ADHAN, minutes = 900)
        assertEquals(listOf("alpha", "beta", "empty", "mixed", "text"), vm.findResult.hits.map { it.mosque.id })
        assertEquals(listOf(900, 900, 900, 900, 900), vm.findResult.hits.map { it.minutes })
        assertEquals(0, vm.findResult.noFixedTimeCount)
        vm.query = CompareFindQuery(null, CompareTimeType.JAMAAT, CompareDirection.AFTER, 1140)
        assertEquals(listOf("alpha.isha.19:00", "beta.isha.19:00", "empty.isha.19:20", "mixed.isha.19:20"),
            vm.findResult.hits.map { it.id })
        assertEquals("count mosques, not text-only prayers", 1, vm.findResult.noFixedTimeCount)
        val betaHit = vm.findResult.hits.single { it.mosque.id == "beta" }
        assertTrue(vm.add(betaHit.mosque))
        assertEquals(listOf("beta"), vm.listedMosques.map { it.id })
    }

    @Test fun deltasUseHomePreferredSlotEarliestOtherSlotAndComparableZonesOnly() = runBlocking {
        val home = mosque("home")
        val earlier = mosque("earlier")
        val later = mosque("later")
        val equal = mosque("equal")
        val hourEarlier = mosque("hour-earlier")
        val foreign = mosque("foreign").copy(timezone = "Asia/Jakarta", countryCode = "GB")
        val fallback = mosque("fallback").copy(timezone = null, countryCode = "gb")
        val unknown = mosque("unknown").copy(timezone = null, countryCode = null)
        val text = mosque("text")
        val all = listOf(earlier, later, equal, hourEarlier, foreign, fallback, unknown, text, home)
        val repo = Repository().apply {
            payloads[home.slug] = month(iq = iq(asr = "15:30 / 16:15", isha = "After Maghrib"))
            payloads[earlier.slug] = month(iq = iq(asr = "16:45 / 16:05"))
            payloads[later.slug] = month(iq = iq(asr = "17:25 / 18:00"))
            payloads[equal.slug] = month(iq = iq(asr = "16:15"))
            payloads[hourEarlier.slug] = month(iq = iq(asr = "15:15"))
            payloads[fallback.slug] = month(iq = iq(asr = "16:30"))
            payloads[text.slug] = month(iq = iq(asr = "After Maghrib"))
        }
        val settings = Settings(all.map { it.id }, second)
        val vm = model(all, CompareDataStore(repo, MemoryCache()), home, settings)
        vm.loadMasjids()
        val rows = vm.rows.associateBy { it.mosque.id }
        assertTrue(rows.getValue("home").isYours)
        assertTrue(rows.getValue("home").deltas.isEmpty())
        assertEquals(-10, rows.getValue("earlier").deltas[ComparePrayer.ASR])
        assertEquals(70, rows.getValue("later").deltas[ComparePrayer.ASR])
        assertEquals(0, rows.getValue("equal").deltas[ComparePrayer.ASR])
        assertEquals(-60, rows.getValue("hour-earlier").deltas[ComparePrayer.ASR])
        assertEquals(15, rows.getValue("fallback").deltas[ComparePrayer.ASR])
        assertTrue(rows.getValue("foreign").deltas.isEmpty())
        assertTrue(rows.getValue("unknown").deltas.isEmpty())
        assertFalse(rows.getValue("text").deltas.containsKey(ComparePrayer.ASR))
        assertFalse(rows.getValue("later").deltas.containsKey(ComparePrayer.ISHA))
        for ((id, label) in listOf("fallback" to "+15m", "earlier" to "-10m", "equal" to "0",
            "later" to "+1h10", "hour-earlier" to "-1h")) {
            assertEquals(label, CompareDelta.displayLabel(rows.getValue(id).deltas.getValue(ComparePrayer.ASR)))
        }
        for ((minutes, label) in listOf(0 to "0", 15 to "+15", -10 to "-10", 70 to "+1h10",
            65 to "+1h05", 60 to "+1h", -70 to "-1h10")) {
            assertEquals(label, CompareDelta.label(minutes))
        }
        assertTrue(CompareDelta.isComparable(home, fallback))
        assertFalse(CompareDelta.isComparable(home, foreign))
        assertFalse(CompareDelta.isComparable(home, unknown))
        val storedIds = settings.compareMosqueIds.toList()
        val listedIds = vm.listedMosques.map { it.id }
        vm.remove(home)
        assertEquals(storedIds, settings.compareMosqueIds)
        assertEquals(listedIds, vm.listedMosques.map { it.id })
        assertEquals("home", vm.listedMosques.first().id)
        assertTrue(vm.isListed(home))
        assertEquals(rows.mapValues { it.value.deltas }, vm.rows.associate { it.mosque.id to it.deltas })
    }

    @Test fun listLimitModeAndAddedOrderSurviveViewModelRecreationThroughSettings() {
        val all = (1..11).map { mosque("m$it", city = if (it == 2) "Leeds" else "Sheffield") }
        val settings = Settings()
        val store = CompareDataStore(Repository(), MemoryCache())
        val vm = model(all, store, settings = settings)
        assertEquals(10, CompareViewModel.MAX_MASJIDS)
        assertEquals(CompareMode.MASJIDS, vm.mode)
        assertTrue(vm.listedMosques.isEmpty())
        for (mosque in all.take(10)) assertTrue(vm.add(mosque))
        assertFalse(vm.canAddMore)
        assertFalse(vm.add(all.last()))
        assertTrue(vm.add(all.first()))
        assertEquals((1..10).map { "m$it" }, settings.compareMosqueIds)
        vm.mode = CompareMode.BY_TIME
        assertEquals(CompareMode.BY_TIME, settings.compareMode)
        val recreated = model(all, store, settings = settings)
        assertEquals(CompareMode.BY_TIME, recreated.mode)
        assertEquals((1..10).map { "m$it" }, recreated.listedMosques.map { it.id })
        recreated.remove(all[1])
        assertTrue(recreated.canAddMore)
        assertTrue(recreated.add(all.last()))
        assertEquals(listOf("m1", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11"),
            model(all, store, settings = settings).listedMosques.map { it.id })
    }

    @Test fun sortingCyclesKeepListedHomePinnedTextLastAndHighlightLatestTies() = runBlocking {
        val home = mosque("home")
        val late = mosque("late")
        val early = mosque("early")
        val tie = mosque("tie")
        val text = mosque("text")
        val empty = mosque("empty")
        val all = listOf(late, text, home, early, tie, empty)
        val repo = Repository().apply {
            payloads[home.slug] = month(iq = iq(asr = "16:15"))
            payloads[late.slug] = month(iq = iq(asr = "16:00 / 18:00"))
            payloads[early.slug] = month(iq = iq(asr = "15:45"))
            payloads[tie.slug] = month(iq = iq(asr = "17:00 / 18:00"))
            payloads[text.slug] = month(iq = iq(asr = "After Maghrib"))
            payloads[empty.slug] = month(iq = iq(asr = "-"))
        }
        val vm = model(all, CompareDataStore(repo, MemoryCache()), home, Settings(all.map { it.id }))
        vm.loadMasjids()
        assertEquals(listOf("home", "late", "text", "early", "tie", "empty"), vm.listedMosques.map { it.id })
        assertEquals(listOf("home", "late", "text", "early", "tie", "empty"), vm.rows.map { it.mosque.id })
        assertEquals(setOf("late", "tie"), vm.highlightedMosqueIds[ComparePrayer.ASR])
        vm.tapHeader(ComparePrayer.ASR)
        assertEquals(ComparePrayer.ASR to true, vm.sort)
        assertEquals(listOf("home", "early", "late", "tie", "text", "empty"), vm.rows.map { it.mosque.id })
        vm.tapHeader(ComparePrayer.ASR)
        assertEquals(ComparePrayer.ASR to false, vm.sort)
        assertEquals(listOf("home", "tie", "late", "early", "text", "empty"), vm.rows.map { it.mosque.id })
        vm.tapHeader(ComparePrayer.ASR)
        assertNull(vm.sort)
        assertEquals(listOf("home", "late", "text", "early", "tie", "empty"), vm.rows.map { it.mosque.id })
        vm.tapHeader(ComparePrayer.ASR)
        vm.tapHeader(ComparePrayer.FAJR)
        assertEquals(ComparePrayer.FAJR to true, vm.sort)
        val single = model(listOf(home), CompareDataStore(repo, MemoryCache()), settings = Settings(listOf(home.id)))
        single.loadMasjids()
        assertTrue(single.highlightedMosqueIds[ComparePrayer.ASR].isNullOrEmpty())
    }

    @Test fun implicitHomeIsFirstCountsTowardLimitAndCannotBeRemovedAcrossRecreation() = runBlocking {
        val all = (1..11).map { mosque("m$it") }
        val home = all.last()
        val settings = Settings(all.take(9).map { it.id })
        val repo = Repository()
        val store = CompareDataStore(repo, MemoryCache())
        val vm = model(all, store, home, settings)
        val initialIds = listOf(home.id) + all.take(9).map { it.id }
        assertFalse(settings.compareMosqueIds.contains(home.id))
        assertEquals(initialIds, vm.listedMosques.map { it.id })
        assertEquals(home.id, vm.yoursId)
        assertTrue(vm.isYours(home))
        assertTrue(vm.isListed(home))
        assertFalse(vm.canAddMore)
        assertFalse(vm.add(all[9]))
        assertTrue(vm.add(home))
        assertEquals(all.take(9).map { it.id }, settings.compareMosqueIds)
        vm.loadMasjids()
        assertEquals(initialIds, vm.rows.map { it.mosque.id })
        assertEquals(10, vm.rows.size)
        assertEquals(initialIds.toSet(), repo.calls.filter { it.kind == "monthly" }.map { it.slug }.toSet())
        vm.remove(home)
        assertEquals(initialIds, vm.listedMosques.map { it.id })
        assertEquals(all.take(9).map { it.id }, settings.compareMosqueIds)
        assertFalse(vm.canAddMore)
        val recreated = model(all, store, home, settings)
        assertEquals(initialIds, recreated.listedMosques.map { it.id })
        recreated.remove(all[2])
        assertTrue(recreated.canAddMore)
        assertTrue(recreated.add(all[9]))
        val expectedIds = listOf(home.id, "m1", "m2", "m4", "m5", "m6", "m7", "m8", "m9", "m10")
        // A legacy stored home ID must not duplicate the implicit, pinned home row.
        settings.compareMosqueIds = settings.compareMosqueIds + home.id
        val withStoredHome = model(all, store, home, settings)
        assertEquals(expectedIds, withStoredHome.listedMosques.map { it.id })
        assertFalse(withStoredHome.canAddMore)
        withStoredHome.remove(home)
        assertEquals(expectedIds, withStoredHome.listedMosques.map { it.id })
        assertTrue(settings.compareMosqueIds.contains(home.id))
    }

    @Test fun gridTimeTypeSwitchesLoadedRowSortingAndDeltasBetweenJamaatAndAdhan() = runBlocking {
        val home = mosque("home")
        val earlyJamaat = mosque("early-jamaat")
        val earlyAdhan = mosque("early-adhan")
        val all = listOf(earlyAdhan, home, earlyJamaat)
        val repo = Repository().apply {
            payloads[home.slug] = month(iq = iq(fajr = "06:40"))
            payloads[earlyJamaat.slug] = month(iq = iq(fajr = "06:30"), fajrAdhan = "06:15")
            payloads[earlyAdhan.slug] = month(iq = iq(fajr = "06:50"), fajrAdhan = "05:50")
        }
        val vm = model(all, CompareDataStore(repo, MemoryCache()), home, Settings(all.map { it.id }))
        vm.loadMasjids()
        assertEquals(CompareTimeType.JAMAAT, vm.gridTimeType)
        vm.tapHeader(ComparePrayer.FAJR)
        assertEquals(listOf("home", "early-jamaat", "early-adhan"), vm.rows.map { it.mosque.id })
        assertEquals(-10, vm.rows.single { it.mosque.id == earlyJamaat.id }.deltas[ComparePrayer.FAJR])
        assertEquals(10, vm.rows.single { it.mosque.id == earlyAdhan.id }.deltas[ComparePrayer.FAJR])
        val requestsBeforeSwitch = repo.calls.toList()
        vm.gridTimeType = CompareTimeType.ADHAN
        assertEquals(ComparePrayer.FAJR to true, vm.sort)
        assertEquals(listOf("home", "early-adhan", "early-jamaat"), vm.rows.map { it.mosque.id })
        assertEquals(15, vm.rows.single { it.mosque.id == earlyJamaat.id }.deltas[ComparePrayer.FAJR])
        assertEquals(-10, vm.rows.single { it.mosque.id == earlyAdhan.id }.deltas[ComparePrayer.FAJR])
        assertTrue(vm.rows.first().deltas.isEmpty())
        vm.tapHeader(ComparePrayer.FAJR)
        assertEquals(listOf("home", "early-jamaat", "early-adhan"), vm.rows.map { it.mosque.id })
        vm.gridTimeType = CompareTimeType.JAMAAT
        assertEquals(listOf("home", "early-adhan", "early-jamaat"), vm.rows.map { it.mosque.id })
        assertEquals(-10, vm.rows.single { it.mosque.id == earlyJamaat.id }.deltas[ComparePrayer.FAJR])
        assertEquals(10, vm.rows.single { it.mosque.id == earlyAdhan.id }.deltas[ComparePrayer.FAJR])
        assertEquals(requestsBeforeSwitch, repo.calls.toList())
    }

    @Test fun laterThanHomeSearchIsStrictAndNudgesClampWithoutChangingOtherFilters() = runBlocking {
        val home = mosque("home")
        val equal = mosque("equal")
        val later = mosque("later")
        val all = listOf(equal, later, home)
        val repo = Repository().apply {
            payloads[home.slug] = month(iq = iq(isha = "20:15"))
            payloads[equal.slug] = month(iq = iq(isha = "20:15"))
            payloads[later.slug] = month(iq = iq(isha = "20:16"))
        }
        val store = CompareDataStore(repo, MemoryCache())
        val vm = model(all, store, home)
        vm.loadFind()
        assertEquals(1215, vm.yourJamaatMinutes(ComparePrayer.ISHA))
        val originalQuery = CompareFindQuery(ComparePrayer.ISHA, CompareTimeType.ADHAN, CompareDirection.BEFORE, 500)
        vm.query = originalQuery
        vm.searchLaterThanYours()
        val laterQuery = CompareFindQuery(ComparePrayer.ISHA, CompareTimeType.JAMAAT, CompareDirection.AFTER, 1216)
        assertEquals(laterQuery, vm.query)
        assertEquals(listOf("later.isha.20:16"), vm.findResult.hits.map { it.id })
        vm.query = originalQuery.copy(prayer = null)
        vm.searchLaterThanYours()
        assertEquals(originalQuery.copy(prayer = null), vm.query)
        val unloaded = model(all, CompareDataStore(repo, MemoryCache()), home)
        val noHome = model(all, store)
        val textRepo = Repository().apply { payloads[home.slug] = month(iq = iq(isha = "After Maghrib")) }
        val textHome = model(all, CompareDataStore(textRepo, MemoryCache()), home)
        textHome.loadMasjids()
        for (unknownHome in listOf(unloaded, noHome, textHome)) {
            assertNull(unknownHome.yourJamaatMinutes(ComparePrayer.ISHA))
            unknownHome.query = originalQuery
            unknownHome.searchLaterThanYours()
            assertEquals(originalQuery, unknownHome.query)
        }
        vm.query = laterQuery.copy(minutes = 1435)
        vm.nudgeMinutes(15)
        assertEquals(laterQuery.copy(minutes = 1439), vm.query)
        assertTrue(vm.findResult.hits.isEmpty())
        vm.nudgeMinutes(-2000)
        assertEquals(laterQuery.copy(minutes = 0), vm.query)
        assertEquals(setOf(home.id, equal.id, later.id), vm.findResult.hits.map { it.mosque.id }.toSet())
        vm.nudgeMinutes(10)
        assertEquals(laterQuery.copy(minutes = 10), vm.query)
    }

    @Test fun relativeMinutesUsesSheffieldWallClockForLoadedHitsOnTodayOnly() = runBlocking {
        val early = mosque("early")
        val current = mosque("current")
        val later = mosque("later")
        val all = listOf(early, current, later)
        for ((day, monthName, clock) in listOf(
            Triple("2026-01-15", MonthName.JANUARY, "2026-01-15T12:30:59Z"),
            Triple("2026-07-06", MonthName.JULY, "2026-07-06T11:30:59Z"),
        )) {
            val repo = Repository().apply {
                payloads[early.slug] = month(monthName, iq(dhuhr = "12:20"))
                payloads[current.slug] = month(monthName, iq(dhuhr = "12:30"))
                payloads[later.slug] = month(monthName, iq(dhuhr = "12:45"))
            }
            val vm = model(all, CompareDataStore(repo, MemoryCache()), initialDate = noon(day),
                now = { Instant.parse(clock) })
            vm.query = CompareFindQuery(ComparePrayer.DHUHR, CompareTimeType.JAMAAT, CompareDirection.AFTER, 0)
            vm.loadFind()
            assertTrue(vm.isToday)
            val expected = mapOf(early.id to -10, current.id to 0, later.id to 15)
            assertEquals(expected, vm.findResult.hits.associate { it.mosque.id to vm.relativeMinutes(it) })
            for (step in listOf(1, -2)) {
                vm.stepDay(step)
                vm.loadFind()
                assertFalse(vm.isToday)
                assertEquals(3, vm.findResult.hits.size)
                vm.findResult.hits.forEach { assertNull(vm.relativeMinutes(it)) }
            }
            vm.stepDay(1)
            assertTrue(vm.isToday)
            assertEquals(expected, vm.findResult.hits.associate { it.mosque.id to vm.relativeMinutes(it) })
        }
    }

    @Test fun dayStepperLoadsTheNewMonthAndDefaultSearchUsesSheffieldClock() = runBlocking {
        val mosque = mosque("boundary")
        val repo = Repository().apply {
            monthPayloads[mosque.slug to "october"] = month(MonthName.OCTOBER, iq(fajr = "06:10"))
            monthPayloads[mosque.slug to "november"] = month(MonthName.NOVEMBER, iq(fajr = "07:10"))
        }
        val vm = model(listOf(mosque), CompareDataStore(repo, MemoryCache()),
            settings = Settings(listOf(mosque.id)), initialDate = noon("2026-10-31"),
            now = { Instant.parse("2026-10-31T09:05:00Z") })
        assertTrue(vm.isToday)
        assertEquals(550, vm.query.minutes)
        assertEquals(CompareTimeType.JAMAAT, vm.query.type)
        assertEquals(CompareDirection.AFTER, vm.query.direction)
        assertNull(vm.query.prayer)
        vm.loadMasjids()
        assertEquals("06:10", vm.rows.single().times!!.homeIqamah[ComparePrayer.FAJR]!!.raw)
        vm.stepDay(1)
        assertEquals(Instant.parse("2026-11-01T12:00:00Z"), vm.date)
        assertFalse(vm.isToday)
        assertEquals(CompareState.Idle, vm.rows.single().state)
        vm.loadMasjids()
        assertEquals("07:10", vm.rows.single().times!!.homeIqamah[ComparePrayer.FAJR]!!.raw)
        assertEquals(listOf("october", "november"), repo.calls.filter { it.kind == "monthly" }.map { it.period })
        vm.stepDay(-1)
        assertEquals(Instant.parse("2026-10-31T12:00:00Z"), vm.date)
        assertTrue(vm.isToday)
        // Strictly next multiple of five, BST wall clock, and end-of-day clamp.
        assertEquals(610, CompareFindQuery.defaultMinutes(true, Instant.parse("2026-07-06T09:05:00Z")))
        assertEquals(610, CompareFindQuery.defaultMinutes(true, Instant.parse("2026-07-06T09:09:59Z")))
        assertEquals(1435, CompareFindQuery.defaultMinutes(true, Instant.parse("2026-01-15T23:59:59Z")))
        assertEquals(720, CompareFindQuery.defaultMinutes(false, Instant.parse("2026-07-06T09:05:00Z")))
    }

    @Test fun warmCacheRendersBeforeVersionCheckAndOnlyStalePayloadIsReplaced() = runBlocking {
        val fresh = mosque("fresh")
        val stale = mosque("stale")
        val old = month(iq = iq(fajr = "06:10"))
        val updated = month(iq = iq(fajr = "06:40"))
        val cache = MemoryCache().apply {
            for (m in listOf(fresh, stale)) {
                saveMonthly(m.slug, "january", 2026, old)
                saveVersions(m.slug, "january", 2026, v1)
            }
        }
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val repo = Repository().apply {
            versions[stale.slug] = v2
            payloads[stale.slug] = updated
            onRequest = { call ->
                if (call.slug == stale.slug && call.kind == "monthly") {
                    entered.complete(Unit)
                    release.await()
                }
            }
        }
        val store = CompareDataStore(repo, cache)
        assertEquals(CompareState.Loaded(old, null), store.state(stale, date))
        assertTrue(repo.calls.isEmpty())
        val loading = launch { store.load(listOf(fresh, stale), date) }
        try {
            withTimeout(3000) { entered.await() }
            assertEquals(CompareState.Loaded(old, null), store.state(stale, date))
            release.complete(Unit)
            withTimeout(3000) { loading.join() }
            assertEquals(CompareState.Loaded(updated, null), store.state(stale, date))
            assertEquals(updated, cache.loadMonthly(stale.slug, "january", 2026))
            assertEquals(v2, cache.loadVersions(stale.slug, "january", 2026)!!.versions)
            assertEquals(CompareState.Loaded(old, null), store.state(fresh, date))
            assertEquals(listOf("stale"), repo.calls.filter { it.kind == "monthly" }.map { it.slug })
            assertEquals(setOf("fresh", "stale"), repo.calls.filter { it.kind == "versions" }.map { it.slug }.toSet())
        } finally {
            release.complete(Unit)
            loading.cancel()
            store.cancel()
        }
    }

    @Test fun offlineColdRowsAreDistinctFromFailuresAndWarmCacheSurvivesRefreshFailure() = runBlocking {
        val warm = mosque("warm")
        val errors = listOf(UnknownHostException("offline"), ConnectException("offline"),
            SocketTimeoutException("timed out"), NoRouteToHostException("offline"), IllegalStateException("bad payload"))
        val cold = errors.indices.map { mosque("cold$it") }
        val cached = month()
        val cache = MemoryCache().apply { saveMonthly(warm.slug, "january", 2026, cached) }
        val repo = Repository().apply {
            failures[warm.slug] = UnknownHostException("offline")
            cold.zip(errors).forEach { (m, error) -> failures[m.slug] = error }
        }
        val store = CompareDataStore(repo, cache)
        val vm = model(listOf(warm) + cold, store, settings = Settings((listOf(warm) + cold).map { it.id }))
        vm.loadMasjids()
        assertEquals(CompareState.Loaded(cached, null), store.state(warm, date))
        assertNotNull(vm.rows.single { it.mosque.id == "warm" }.times)
        cold.take(2).forEach { assertEquals(CompareState.Offline, store.state(it, date)) }
        assertEquals(CompareState.Failed, store.state(cold[2], date))
        assertEquals(CompareState.Offline, store.state(cold[3], date))
        assertEquals(CompareState.Failed, store.state(cold.last(), date))
        assertEquals(1 to 6, vm.loadProgress)
        assertEquals(5, vm.failedCount)
        assertEquals(cached, cache.loadMonthly(warm.slug, "january", 2026))
    }

    @Test fun coldCityLoadCapsAllRepositoryRequestsAtSixInFlight() = runBlocking {
        val mosques = (1..14).map { mosque("city$it") }
        val repo = Repository().apply {
            // Simulated network latency permits overlap without requiring exactly six workers.
            onRequest = { delay(20) }
        }
        val store = CompareDataStore(repo, MemoryCache())
        val vm = model(mosques, store)
        try {
            assertEquals(0 to 14, vm.loadProgress)
            withTimeout(5000) { vm.loadFind() }
            assertEquals(14 to 14, vm.loadProgress)
            assertEquals(0, vm.failedCount)
            assertEquals(14, repo.calls.count { it.kind == "monthly" })
            assertTrue("city loading runs in parallel", repo.peak.get() >= 2)
            assertTrue("includes Ramadan and version requests", repo.peak.get() <= 6)
        } finally {
            store.cancel()
        }
    }

    @Test fun cancelStopsInFlightAndQueuedFetchesButKeepsPreviouslySavedPayload() = runBlocking {
        val saved = mosque("saved")
        val blocked = mosque("blocked")
        val queued = mosque("queued")
        val cache = MemoryCache()
        val repo = Repository()
        val store = CompareDataStore(repo, cache, maxConcurrent = 1)
        store.load(listOf(saved), date)
        assertNotNull(cache.loadMonthly(saved.slug, "january", 2026))
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        repo.onRequest = { call ->
            if (call.kind == "monthly") {
                entered.complete(Unit)
                release.await()
            }
        }
        val vm = model(listOf(blocked, queued), store)
        val loading = launch(start = CoroutineStart.UNDISPATCHED) { vm.loadFind() }
        try {
            withTimeout(3000) { entered.await() }
            assertEquals(CompareState.Loading, store.state(blocked, date))
            vm.cancelLoading()
            withTimeout(3000) { loading.join() }
            assertEquals(1, repo.cancelled.get())
            assertFalse(repo.calls.any { it.slug == queued.slug })
            assertNull(cache.loadMonthly(blocked.slug, "january", 2026))
            assertNull(cache.loadMonthly(queued.slug, "january", 2026))
            assertEquals(CompareState.Idle, store.state(blocked, date))
            assertEquals(CompareState.Idle, store.state(queued, date))
            assertTrue(store.state(saved, date) is CompareState.Loaded)
            assertTrue(CompareDataStore(Repository(), cache).state(saved, date) is CompareState.Loaded)
        } finally {
            release.complete(Unit)
            loading.cancel()
            store.cancel()
        }
    }

    @Test fun cityOptionsExcludeHiddenAndProgressAndFailuresBelongToSelectedCity() = runBlocking {
        val home = mosque("home")
        val failed = mosque("failed")
        val offline = mosque("offline")
        val leeds = mosque("leeds", city = "Leeds")
        val hidden = mosque("hidden", city = "London").copy(isHidden = true)
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val repo = Repository().apply {
            failures[failed.slug] = IllegalStateException("bad response")
            failures[offline.slug] = UnknownHostException("offline")
            onRequest = { call ->
                if (call.slug == home.slug && call.kind == "monthly") {
                    entered.complete(Unit)
                    release.await()
                }
            }
        }
        val store = CompareDataStore(repo, MemoryCache())
        val vm = model(listOf(home, failed, offline, leeds, hidden), store, home)
        assertEquals(listOf("slug:leeds" to "Leeds", "slug:sheffield" to "Sheffield"), vm.cityOptions)
        assertEquals("slug:sheffield", vm.cityKey)
        assertEquals(0 to 3, vm.loadProgress)
        val loading = launch { vm.loadFind() }
        try {
            withTimeout(3000) { entered.await() }
            assertEquals(0 to 3, vm.loadProgress)
            release.complete(Unit)
            withTimeout(3000) { loading.join() }
            assertEquals(1 to 3, vm.loadProgress)
            assertEquals(2, vm.failedCount)
            assertFalse(repo.calls.any { it.slug == leeds.slug || it.slug == hidden.slug })
            vm.query = CompareFindQuery(ComparePrayer.ISHA, CompareTimeType.JAMAAT, CompareDirection.AFTER, 0)
            assertEquals(listOf("home.isha.19:20"), vm.findResult.hits.map { it.id })
            vm.cityKey = "slug:leeds"
            assertEquals(0 to 1, vm.loadProgress)
            assertEquals(0, vm.failedCount)
            vm.loadFind()
            assertEquals(1 to 1, vm.loadProgress)
            assertEquals(listOf("leeds.isha.19:20"), vm.findResult.hits.map { it.id })
        } finally {
            release.complete(Unit)
            loading.cancel()
            store.cancel()
        }
    }

    private fun model(
        mosques: List<Mosque>, store: CompareDataStore, home: Mosque? = null,
        settings: Settings = Settings(), initialDate: Instant = date,
        now: () -> Instant = { date },
    ) = CompareViewModel(mosques, home, settings, store, initialDate, now)

    private fun homeClocks(times: CompareDayTimes) = ComparePrayer.entries.map { times.homeIqamah[it]?.raw }

    // This is the published Home formula, not a second parser or a Compare implementation.
    private fun assertHomeParity(
        actual: CompareDayTimes, mosque: Mosque, date: Instant, monthly: MonthPrayerData?,
        ramadan: RamadanPrayerData?, preference: AsrIqamahPreference,
    ) {
        val daily = PrayerTimesEngine.resolvePrayerTimes(date, monthly, ramadan, preference)
        val iq = PrayerTimesEngine.resolveIqamahTimes(date, monthly, ramadan)
        val friday = date.atZone(PrayerTimesEngine.sheffieldTimeZone).dayOfWeek == DayOfWeek.FRIDAY
        val expected = listOf(
            PrayerTimesEngine.getIqamahTime("fajr", daily.fajr, iq),
            if (friday) PrayerTimesEngine.splitJummahIqamahTimes(iq.jummah).firstOrNull() ?: daily.dhuhr
            else PrayerTimesEngine.getDisplayIqamah("dhuhr", daily.dhuhr, iq, mosque.slug, date, daily.maghrib),
            PrayerTimesEngine.selectAsrIqamahTime(iq.asr, daily.asr, preference),
            PrayerTimesEngine.getDisplayIqamah("maghrib", daily.maghrib, iq, mosque.slug, date, daily.maghrib),
            PrayerTimesEngine.resolveIshaIqamahForDisplay(mosque.slug, date, daily.isha, iq, daily.maghrib),
        )
        assertEquals("Home parity: ${mosque.slug}, $date, $preference", expected, homeClocks(actual))
    }

    private fun noon(date: String) = Instant.parse("${date}T12:00:00Z")

    private fun mosque(id: String, name: String = id, city: String = "Sheffield") = Mosque(
        id, name, "Published timetable fixture", 53.38, -1.47, id,
        citySlug = city.lowercase(), cityName = city, countryCode = "GB", timezone = "Europe/London",
    )

    private fun iq(
        fajr: String = "06:20", dhuhr: String = "12:20", asr: String = "15:20",
        maghrib: String = "17:20", isha: String = "19:20", jummah: String = "12:45",
    ) = IqamahTimeRange("1-31", fajr, dhuhr, asr, maghrib, isha, jummah)

    private fun month(
        month: MonthName = MonthName.JANUARY, iq: IqamahTimeRange = iq(), jummah: String = "12:45",
        fajrAdhan: String = "06:00",
    ) = MonthPrayerData(month.rawValue, (1..31).map {
        PrayerTime(it, fajrAdhan, "07:00", "12:00", "15:00", "15:40", "17:00", "19:00")
    }, listOf(iq), jummah)

    private class Settings(
        override var compareMosqueIds: List<String> = emptyList(),
        override val asrIqamahPreference: AsrIqamahPreference = AsrIqamahPreference.FIRST,
    ) : CompareSettings {
        override var compareMode = CompareMode.MASJIDS
    }

    private class MemoryCache : CompareCache {
        private val monthly = ConcurrentHashMap<Triple<String, String, Int>, MonthPrayerData>()
        private val versions = ConcurrentHashMap<Triple<String, String, Int>, CachedPrayerDataVersions>()
        private val ramadan = ConcurrentHashMap<Pair<String, String>, RamadanPrayerData>()
        override fun loadMonthly(slug: String, month: String, year: Int) = monthly[Triple(slug, month, year)]
        override fun saveMonthly(slug: String, month: String, year: Int, data: MonthPrayerData) {
            monthly[Triple(slug, month, year)] = data
        }
        override fun removeMonthly(slug: String, month: String, year: Int) {
            monthly.remove(Triple(slug, month, year))
        }
        override fun loadVersions(slug: String, month: String, year: Int) = versions[Triple(slug, month, year)]
        override fun saveVersions(slug: String, month: String, year: Int, versions: PrayerDataVersions) {
            this.versions[Triple(slug, month, year)] = CachedPrayerDataVersions(versions, 0L)
        }
        override fun loadRamadan(slug: String, date: String) = ramadan[slug to date]
        override fun saveRamadan(slug: String, date: String, data: RamadanPrayerData) {
            ramadan[slug to date] = data
        }
    }

    private data class Call(val kind: String, val slug: String, val period: String, val year: Int = 2026)

    private inner class Repository : PrayerRepository {
        val payloads = mutableMapOf<String, MonthPrayerData>()
        val monthPayloads = mutableMapOf<Pair<String, String>, MonthPrayerData>()
        val ramadanPayloads = mutableMapOf<String, RamadanPrayerData>()
        val versions = mutableMapOf<String, PrayerDataVersions>()
        val failures = mutableMapOf<String, Exception>()
        val calls: MutableList<Call> = Collections.synchronizedList(mutableListOf())
        val active = AtomicInteger()
        val peak = AtomicInteger()
        val cancelled = AtomicInteger()
        var onRequest: suspend (Call) -> Unit = {}

        override suspend fun listMosques(): List<Mosque> = error("Compare must use the supplied mosque catalogue")

        override suspend fun getPrayerDataVersions(mosqueSlug: String, month: MonthName, year: Int) =
            request(Call("versions", mosqueSlug, month.rawValue, year)) { versions[mosqueSlug] ?: v1 }

        override suspend fun getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) =
            request(Call("monthly", mosqueSlug, month.rawValue, year)) {
                monthPayloads[mosqueSlug to month.rawValue] ?: payloads[mosqueSlug] ?: this@CompareIntegrationTest.month(month)
            }

        override suspend fun getRamadanTimetable(mosqueSlug: String, date: String?) =
            request(Call("ramadan", mosqueSlug, date.orEmpty())) { ramadanPayloads[mosqueSlug] }

        private suspend fun <T> request(call: Call, result: () -> T): T {
            calls.add(call)
            val count = active.incrementAndGet()
            peak.updateAndGet { maxOf(it, count) }
            try {
                onRequest(call)
                failures[call.slug]?.let { throw it }
                return result()
            } catch (error: CancellationException) {
                cancelled.incrementAndGet()
                throw error
            } finally {
                active.decrementAndGet()
            }
        }
    }
}
