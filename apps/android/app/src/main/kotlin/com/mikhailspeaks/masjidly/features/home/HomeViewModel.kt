package com.mikhailspeaks.masjidly.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mikhailspeaks.masjidly.data.SettingsStore
import com.mikhailspeaks.masjidly.data.cache.PrayerTimesDiskCache
import com.mikhailspeaks.masjidly.domain.DailyIqamahTimes
import com.mikhailspeaks.masjidly.domain.DailyPrayerTimes
import com.mikhailspeaks.masjidly.domain.MonthName
import com.mikhailspeaks.masjidly.domain.MonthPrayerData
import com.mikhailspeaks.masjidly.domain.Mosque
import com.mikhailspeaks.masjidly.domain.MosqueSelection
import com.mikhailspeaks.masjidly.domain.NextPrayerCountdownResult
import com.mikhailspeaks.masjidly.domain.PrayerRepository
import com.mikhailspeaks.masjidly.domain.PrayerTimesEngine
import com.mikhailspeaks.masjidly.domain.RamadanPrayerData
import com.mikhailspeaks.masjidly.domain.UkDstYear
import com.mikhailspeaks.masjidly.features.notifications.PrayerNotificationScheduler
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import com.mikhailspeaks.masjidly.widget.WidgetPrayerSnapshotService
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Android counterpart to iOS `HomeViewModel.swift` — same observable state fields and load flow.
 */
class HomeViewModel(
    private val repository: PrayerRepository,
    private val settings: SettingsStore,
    private val diskCache: PrayerTimesDiskCache,
    private val notificationScheduler: PrayerNotificationScheduler,
    private val widgetSnapshotService: WidgetPrayerSnapshotService,
) : ViewModel() {

    enum class LoadState {
        IDLE,
        LOADING,
        LOADED,
        EMPTY,
    }

    data class UiState(
        val loadState: LoadState = LoadState.IDLE,
        val mosques: List<Mosque> = emptyList(),
        val selectedMosque: Mosque? = null,
        val monthData: MonthPrayerData? = null,
        val ramadanData: RamadanPrayerData? = null,
        val ukDst: List<UkDstYear> = emptyList(),
        val displayedPrayerTimes: DailyPrayerTimes? = null,
        val iqamahTimes: DailyIqamahTimes? = null,
        val nextCountdown: NextPrayerCountdownResult? = null,
        val selectedPrayerIndex: Int = 0,
        val displayedDate: Instant = Instant.now(),
        val lastError: String? = null,
        val hasAvailablePrayerTimesFallback: Boolean = false,
        val lastPrayerPayloadRefreshAt: Instant? = null,
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var loadedMonthNumber: Int? = null
    private var loadedMonthYear: Int? = null
    private var lastAvailablePrayerDate: Instant? = null
    private var refreshTask: Job? = null

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(loadState = LoadState.LOADING, lastError = null) }

            val cachedMosques = diskCache.loadMosques()
            if (cachedMosques != null) {
                val mosque = MosqueSelection.resolveSelectedMosque(
                    mosques = cachedMosques,
                    selectedId = settings.selectedMosqueId,
                    selectedSlug = settings.selectedMosqueSlug,
                )
                _uiState.update {
                    it.copy(mosques = cachedMosques, selectedMosque = mosque)
                }
                mosque?.let { hydrateFromCache(it) }
            }

            runNetworkRefresh()
        }
    }

    fun manualRefresh() {
        val mosque = _uiState.value.selectedMosque ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(loadState = LoadState.LOADING) }
            try {
                refreshPrayerPayload(mosque)
                _uiState.update { it.copy(loadState = LoadState.LOADED, lastError = null) }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(loadState = LoadState.LOADED, lastError = e.localizedMessage)
                }
            }
        }
    }

    fun applySelectionFromSettings() {
        viewModelScope.launch {
            diskCache.loadMosques()?.let { cached ->
                val mosque = MosqueSelection.resolveSelectedMosque(
                    mosques = cached,
                    selectedId = settings.selectedMosqueId,
                    selectedSlug = settings.selectedMosqueSlug,
                )
                _uiState.update { it.copy(mosques = cached, selectedMosque = mosque) }
                mosque?.let { hydrateFromCache(it) }
            }

            val mosque = MosqueSelection.resolveSelectedMosque(
                mosques = _uiState.value.mosques,
                selectedId = settings.selectedMosqueId,
                selectedSlug = settings.selectedMosqueSlug,
            ) ?: return@launch

            _uiState.update { it.copy(selectedMosque = mosque) }
            try {
                refreshPrayerPayload(mosque)
            } catch (e: Exception) {
                _uiState.update { it.copy(lastError = e.localizedMessage) }
            }
        }
    }

    /** Used by onboarding mosque selection — mirrors iOS `selectMosque`. */
    suspend fun switchToMosque(mosque: Mosque) {
        _uiState.update { it.copy(selectedMosque = mosque, lastError = null) }
        refreshPrayerPayload(mosque)
        _uiState.update { it.copy(loadState = LoadState.LOADED) }
    }

    fun setLastError(message: String?) {
        _uiState.update { it.copy(lastError = message) }
    }

    fun refreshFromNetworkIfStale() {
        val stalenessSeconds = 5 * 60L
        val last = _uiState.value.lastPrayerPayloadRefreshAt
        if (last != null && Instant.now().epochSecond - last.epochSecond < stalenessSeconds) return
        val mosque = _uiState.value.selectedMosque ?: return
        if (refreshTask?.isActive == true) return

        refreshTask = viewModelScope.launch {
            try {
                refreshPrayerPayload(mosque)
            } catch (_: Exception) {
                // Silent on foreground resume.
            }
        }
    }

    fun selectPrayerIndex(index: Int) {
        _uiState.update { it.copy(selectedPrayerIndex = index.coerceIn(0, 5)) }
    }

    fun goToPreviousDay() {
        // Match iOS `Calendar.current.date(byAdding: .day, …)` — local calendar day, not Sheffield.
        val zone = ZoneId.systemDefault()
        val newDate = ZonedDateTime.ofInstant(_uiState.value.displayedDate, zone)
            .minusDays(1)
            .toInstant()
        _uiState.update { it.copy(displayedDate = newDate) }
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    fun goToNextDay() {
        val zone = ZoneId.systemDefault()
        val newDate = ZonedDateTime.ofInstant(_uiState.value.displayedDate, zone)
            .plusDays(1)
            .toInstant()
        _uiState.update { it.copy(displayedDate = newDate) }
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    fun goToToday() {
        _uiState.update { it.copy(displayedDate = Instant.now()) }
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    fun goToLastAvailablePrayerDate() {
        val last = lastAvailablePrayerDate ?: return
        _uiState.update { it.copy(displayedDate = last) }
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    suspend fun fetchMonthData(mosqueSlug: String, month: Int, year: Int): MonthPrayerData? {
        val monthName = MonthName.from(month) ?: return null
        return try {
            val data = repository.getMonthlyPrayerTimes(mosqueSlug, monthName, year)
            if (data != null && data.prayerTimes.isNotEmpty()) {
                diskCache.saveMonthly(mosqueSlug, monthName.rawValue, year, data)
                data
            } else {
                diskCache.removeMonthly(mosqueSlug, monthName.rawValue, year)
                data
            }
        } catch (_: Exception) {
            diskCache.loadMonthly(mosqueSlug, monthName.rawValue, year)
        }
    }

    private suspend fun runNetworkRefresh() {
        try {
            val list = repository.listMosques()
            val visible = MosqueSelection.visibleMosques(list)
            diskCache.saveMosques(visible)

            val mosque = MosqueSelection.resolveSelectedMosque(
                mosques = list,
                selectedId = settings.selectedMosqueId,
                selectedSlug = settings.selectedMosqueSlug,
            )
            if (mosque == null) {
                _uiState.update { it.copy(loadState = LoadState.EMPTY, mosques = visible) }
                return
            }

            settings.selectedMosqueId = mosque.id
            settings.selectedMosqueSlug = mosque.slug
            settings.selectedCityGroupingKey = mosque.cityGroupingKey
            settings.selectedCountryGroupingKey = MosqueSelection.countryGroupingKey(mosque)

            _uiState.update { it.copy(mosques = visible, selectedMosque = mosque) }
            refreshPrayerPayload(mosque)
            _uiState.update { it.copy(loadState = LoadState.LOADED, lastError = null) }
        } catch (e: Exception) {
            val mosques = _uiState.value.mosques
            _uiState.update {
                it.copy(
                    loadState = if (mosques.isEmpty()) LoadState.EMPTY else LoadState.LOADED,
                    lastError = e.localizedMessage,
                )
            }
        }
    }

    suspend fun resyncNotificationsIfNeeded() {
        val n = settings.notifications
        val mosque = _uiState.value.selectedMosque
        if (!n.masterEnabled || mosque == null) {
            notificationScheduler.cancelAllPrayerNotifications()
            return
        }
        notificationScheduler.rescheduleUpcomingPrayerNotifications(
            mosque = mosque,
            days = 7,
            settings = n,
            language = settings.appLanguage,
            asrIqamahPreference = settings.asrIqamahPreference,
        )
    }

    private suspend fun refreshPrayerPayload(mosque: Mosque) {
        val now = Instant.now()
        val sh = PrayerTimesEngine.getDateInSheffield(now)
        val monthName = MonthName.from(sh.month) ?: return
        val isoDate = PrayerTimesEngine.isoDateString(sh.year, sh.month, sh.day)

        val monthly = repository.getMonthlyPrayerTimes(mosque.slug, monthName, sh.year)
        val ramadan = repository.getRamadanTimetable(mosque.slug, isoDate)
        val dstCalendar = repository.getUkDstDates()

        if (monthly != null && monthly.prayerTimes.isNotEmpty()) {
            diskCache.saveMonthly(mosque.slug, monthName.rawValue, sh.year, monthly)
        } else {
            diskCache.removeMonthly(mosque.slug, monthName.rawValue, sh.year)
        }
        ramadan?.let { diskCache.saveRamadan(mosque.slug, isoDate, it) }
        dstCalendar?.let { diskCache.saveUkDst(it) }

        _uiState.update {
            it.copy(
                monthData = monthly,
                ramadanData = ramadan,
                ukDst = dstCalendar?.ukDstDates ?: emptyList(),
                lastPrayerPayloadRefreshAt = Instant.now(),
            )
        }
        loadedMonthNumber = sh.month
        loadedMonthYear = sh.year
        applyPrayerTimes(_uiState.value.displayedDate, mosque)
        resyncNotificationsIfNeeded()
        widgetSnapshotService.refreshSnapshot(mosque)
    }

    private fun hydrateFromCache(mosque: Mosque) {
        val date = _uiState.value.displayedDate
        val sh = PrayerTimesEngine.getDateInSheffield(date)
        val monthName = MonthName.from(sh.month) ?: return
        val isoDate = PrayerTimesEngine.isoDateString(sh.year, sh.month, sh.day)
        val monthly = diskCache.loadMonthly(mosque.slug, monthName.rawValue, sh.year) ?: return

        _uiState.update {
            it.copy(
                monthData = monthly,
                ramadanData = diskCache.loadRamadan(mosque.slug, isoDate),
                ukDst = diskCache.loadUkDst()?.ukDstDates ?: emptyList(),
                loadState = LoadState.LOADED,
            )
        }
        loadedMonthNumber = sh.month
        loadedMonthYear = sh.year
        applyPrayerTimes(date, mosque)
    }

    private fun loadOrApplyPrayerTimesForDisplayedDate() {
        val mosque = _uiState.value.selectedMosque ?: run {
            clearDisplayedPrayerTimes()
            return
        }
        val target = _uiState.value.displayedDate
        if (loadedMonthMatches(target)) {
            applyPrayerTimes(target, mosque)
            return
        }
        clearDisplayedPrayerTimes()
        viewModelScope.launch { loadPrayerPayloadForDate(target, mosque) }
    }

    private suspend fun loadPrayerPayloadForDate(date: Instant, mosque: Mosque) {
        val parts = PrayerTimesEngine.getDateInSheffield(date)
        val monthName = MonthName.from(parts.month) ?: return
        val isoDate = PrayerTimesEngine.isoDateString(parts.year, parts.month, parts.day)

        try {
            val monthly = repository.getMonthlyPrayerTimes(mosque.slug, monthName, parts.year)
            val ramadan = repository.getRamadanTimetable(mosque.slug, isoDate)
            val dst = repository.getUkDstDates()

            if (monthly != null && monthly.prayerTimes.isNotEmpty()) {
                diskCache.saveMonthly(mosque.slug, monthName.rawValue, parts.year, monthly)
            } else {
                diskCache.removeMonthly(mosque.slug, monthName.rawValue, parts.year)
            }
            ramadan?.let { diskCache.saveRamadan(mosque.slug, isoDate, it) }
            dst?.let { diskCache.saveUkDst(it) }

            val displayedParts = PrayerTimesEngine.getDateInSheffield(_uiState.value.displayedDate)
            if (_uiState.value.selectedMosque?.slug != mosque.slug) return
            if (displayedParts.month != parts.month || displayedParts.year != parts.year) return

            _uiState.update {
                it.copy(
                    monthData = monthly,
                    ramadanData = ramadan,
                    ukDst = dst?.ukDstDates ?: it.ukDst,
                    lastPrayerPayloadRefreshAt = Instant.now(),
                )
            }
            loadedMonthNumber = parts.month
            loadedMonthYear = parts.year
            applyPrayerTimes(_uiState.value.displayedDate, mosque)
        } catch (_: Exception) {
            val cached = diskCache.loadMonthly(mosque.slug, monthName.rawValue, parts.year)
            if (cached != null) {
                _uiState.update {
                    it.copy(
                        monthData = cached,
                        ramadanData = diskCache.loadRamadan(mosque.slug, isoDate),
                        ukDst = diskCache.loadUkDst()?.ukDstDates ?: it.ukDst,
                    )
                }
                loadedMonthNumber = parts.month
                loadedMonthYear = parts.year
                applyPrayerTimes(_uiState.value.displayedDate, mosque)
            }
        }
    }

    private fun applyPrayerTimes(date: Instant, mosque: Mosque?) {
        val state = _uiState.value
        if (mosque == null || state.monthData == null || !loadedMonthMatches(date)) {
            clearDisplayedPrayerTimes()
            return
        }
        val monthly = state.monthData
        val displayed = try {
            val raw = PrayerTimesEngine.resolvePrayerTimes(
                slug = mosque.slug,
                on = date,
                monthly = monthly,
                ramadan = state.ramadanData,
                ukDst = state.ukDst,
                asrTimingPreference = settings.asrIqamahPreference,
            )
            PrayerTimesEngine.getDisplayedPrayerTimes(raw, date = date, mosqueSlug = mosque.slug)
        } catch (_: Exception) {
            null
        }
        val iqamah = try {
            PrayerTimesEngine.resolveIqamahTimesWithDstMapping(
                slug = mosque.slug,
                on = date,
                monthly = monthly,
                ramadan = state.ramadanData,
                ukDst = state.ukDst,
            )
        } catch (_: Exception) {
            null
        }

        if (displayed != null) {
            lastAvailablePrayerDate = date
        }

        val now = Instant.now()
        val isToday = isSameSheffieldDay(date, now)
        val countdown = if (isToday && displayed != null && iqamah != null) {
            PrayerTimesEngine.getNextPrayerAndCountdown(
                prayerTimes = displayed,
                iqamahTimes = iqamah,
                mosqueSlug = mosque.slug,
                now = now,
                asrIqamahPreference = settings.asrIqamahPreference,
                includeTomorrowFajr = false,
            )
        } else {
            null
        }

        val selectedIndex = state.selectedPrayerIndex
        val autoIndex = countdown?.nextName?.let { name ->
            HOME_PRAYER_CANONICAL.indexOfFirst { it.equals(name, ignoreCase = true) }
                .takeIf { it >= 0 }
        }

        _uiState.update {
            it.copy(
                displayedPrayerTimes = displayed,
                iqamahTimes = iqamah,
                nextCountdown = countdown,
                hasAvailablePrayerTimesFallback = lastAvailablePrayerDate != null,
                selectedPrayerIndex = autoIndex ?: selectedIndex,
            )
        }
    }

    private fun clearDisplayedPrayerTimes() {
        _uiState.update {
            it.copy(
                displayedPrayerTimes = null,
                iqamahTimes = null,
                nextCountdown = null,
            )
        }
    }

    private fun loadedMonthMatches(date: Instant): Boolean {
        val parts = PrayerTimesEngine.getDateInSheffield(date)
        return loadedMonthNumber == parts.month && loadedMonthYear == parts.year
    }

    private fun isSameSheffieldDay(a: Instant, b: Instant): Boolean {
        val left = PrayerTimesEngine.getDateInSheffield(a)
        val right = PrayerTimesEngine.getDateInSheffield(b)
        return left.year == right.year && left.month == right.month && left.day == right.day
    }

    companion object {
        private val HOME_PRAYER_CANONICAL = listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha", "Jummah")
    }
}
