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
        /** Letter-picker index for the upcoming (or post-Isha) prayer when viewing today; null otherwise. */
        val currentPrayerIndex: Int? = null,
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

    private fun defaultMosque(mosques: List<Mosque> = _uiState.value.mosques): Mosque? =
        MosqueSelection.resolveSelectedMosque(mosques, settings.selectedMosqueId, settings.selectedMosqueSlug)

    private fun displayedMosque(mosques: List<Mosque>): Mosque? =
        mosques.firstOrNull { it.id == settings.activeMosqueTabId && it.id in settings.openMosqueTabIds }
            ?: defaultMosque(mosques)

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(loadState = LoadState.LOADING, lastError = null) }

            val cachedMosques = diskCache.loadMosques()
            if (cachedMosques != null) {
                val mosque = displayedMosque(cachedMosques)
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
                refreshPrayerPayload(mosque, checkVersions = true)
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
            if (_uiState.value.selectedMosque?.id != displayedMosque(_uiState.value.mosques)?.id) {
                clearDisplayedPrayerTimes()
                _uiState.update { it.copy(monthData = null) }
            }
            diskCache.loadMosques()?.let { cached ->
                val mosque = displayedMosque(cached)
                _uiState.update { it.copy(mosques = cached, selectedMosque = mosque) }
                mosque?.let { hydrateFromCache(it) }
            }

            val mosque = displayedMosque(_uiState.value.mosques) ?: return@launch

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
        refreshPrayerPayload(mosque, checkVersions = true)
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
            runNetworkRefresh()
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
            val cachedRevision = diskCache.loadDataRevision()
            val revision = runCatching { repository.getDataRevision() }.getOrNull()
            val cachedMosques = diskCache.loadMosques()
            val revisionUnchanged = revision != null && cachedRevision == revision && cachedMosques != null
            val list = if (revisionUnchanged) cachedMosques!! else repository.listMosques()
            val visible = MosqueSelection.visibleMosques(list)
            if (!revisionUnchanged) diskCache.saveMosques(visible)

            val mosque = displayedMosque(visible)
            if (mosque == null) {
                _uiState.update { it.copy(loadState = LoadState.EMPTY, mosques = visible) }
                return
            }

            // Only persist a resolved mosque once the user has finished onboarding.
            // Writing the default (MWHS) here blocked closest-mosque prefill.
            if (settings.hasCompletedOnboarding) {
                defaultMosque(visible)?.let { default ->
                    settings.selectedMosqueId = default.id
                    settings.selectedMosqueSlug = default.slug
                    settings.selectedCityGroupingKey = default.cityGroupingKey
                    settings.selectedCountryGroupingKey = MosqueSelection.countryGroupingKey(default)
                }
            }

            _uiState.update { it.copy(mosques = visible, selectedMosque = mosque) }
            refreshPrayerPayload(mosque, checkVersions = !revisionUnchanged)
            if (revision != null) diskCache.saveDataRevision(revision)
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
        val mosque = defaultMosque()
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

    private suspend fun refreshPrayerPayload(mosque: Mosque, checkVersions: Boolean = true) {
        val now = Instant.now()
        val sh = PrayerTimesEngine.getDateInSheffield(now)
        val monthName = MonthName.from(sh.month) ?: return
        val isoDate = PrayerTimesEngine.isoDateString(sh.year, sh.month, sh.day)
        val cachedMonthly = diskCache.loadMonthly(mosque.slug, monthName.rawValue, sh.year)
        val cachedRamadan = diskCache.loadRamadan(mosque.slug, isoDate)
        val cachedDst = diskCache.loadUkDst()
        val cachedVersions = diskCache.loadVersions(mosque.slug, monthName.rawValue, sh.year)

        if (!checkVersions && cachedMonthly != null) {
            if (_uiState.value.selectedMosque?.id != mosque.id) return
            _uiState.update {
                it.copy(
                    monthData = cachedMonthly,
                    ramadanData = cachedRamadan,
                    ukDst = cachedDst?.ukDstDates ?: emptyList(),
                    lastPrayerPayloadRefreshAt = Instant.now(),
                )
            }
            loadedMonthNumber = sh.month
            loadedMonthYear = sh.year
            applyPrayerTimes(_uiState.value.displayedDate, mosque)
            defaultMosque()?.let { widgetSnapshotService.refreshSnapshot(it) }
            return
        }

        val versions = runCatching { repository.getPrayerDataVersions(mosque.slug, monthName, sh.year) }.getOrNull()
        if (versions != null && cachedVersions?.versions == versions && cachedMonthly != null) {
            if (_uiState.value.selectedMosque?.id != mosque.id) return
            diskCache.saveVersions(mosque.slug, monthName.rawValue, sh.year, versions)
            _uiState.update {
                it.copy(
                    monthData = cachedMonthly,
                    ramadanData = cachedRamadan,
                    ukDst = cachedDst?.ukDstDates ?: emptyList(),
                    lastPrayerPayloadRefreshAt = Instant.now(),
                )
            }
            loadedMonthNumber = sh.month
            loadedMonthYear = sh.year
            applyPrayerTimes(_uiState.value.displayedDate, mosque)
            defaultMosque()?.let { widgetSnapshotService.refreshSnapshot(it) }
            return
        }

        val monthly = repository.getMonthlyPrayerTimes(mosque.slug, monthName, sh.year)
        val ramadan = repository.getRamadanTimetable(mosque.slug, isoDate)
        val dstCalendar = repository.getUkDstDates()

        if (_uiState.value.selectedMosque?.id != mosque.id) return

        if (monthly != null && monthly.prayerTimes.isNotEmpty()) {
            diskCache.saveMonthly(mosque.slug, monthName.rawValue, sh.year, monthly)
        } else {
            diskCache.removeMonthly(mosque.slug, monthName.rawValue, sh.year)
        }
        ramadan?.let { diskCache.saveRamadan(mosque.slug, isoDate, it) }
        dstCalendar?.let { diskCache.saveUkDst(it) }
        versions?.let { diskCache.saveVersions(mosque.slug, monthName.rawValue, sh.year, it) }

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
        defaultMosque()?.let { widgetSnapshotService.refreshSnapshot(it) }
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
            if (_uiState.value.selectedMosque?.slug != mosque.slug) return
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
        val countdownResolved: Boolean
        val countdown = if (isToday && displayed != null && iqamah != null) {
            countdownResolved = true
            PrayerTimesEngine.getNextPrayerAndCountdown(
                prayerTimes = displayed,
                iqamahTimes = iqamah,
                mosqueSlug = mosque.slug,
                now = now,
                asrIqamahPreference = settings.asrIqamahPreference,
                includeTomorrowFajr = false,
            )
        } else {
            countdownResolved = false
            null
        }

        val currentIndex = PrayerTimesEngine.homeCurrentPrayerIndex(
            nextName = countdown?.nextName,
            isToday = isToday,
            countdownResolved = countdownResolved,
        )

        _uiState.update {
            val previousCurrent = it.currentPrayerIndex
            it.copy(
                displayedPrayerTimes = displayed,
                iqamahTimes = iqamah,
                nextCountdown = countdown,
                hasAvailablePrayerTimesFallback = lastAvailablePrayerDate != null,
                currentPrayerIndex = currentIndex,
                selectedPrayerIndex = if (currentIndex != null && currentIndex != previousCurrent) {
                    currentIndex
                } else {
                    it.selectedPrayerIndex
                },
            )
        }
    }

    private fun clearDisplayedPrayerTimes() {
        _uiState.update {
            it.copy(
                displayedPrayerTimes = null,
                iqamahTimes = null,
                nextCountdown = null,
                currentPrayerIndex = null,
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
}
