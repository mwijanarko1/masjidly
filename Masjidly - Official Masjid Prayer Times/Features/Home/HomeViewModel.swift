import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private let repository: any PrayerRepository
    private let settings: SettingsStore
    private let notificationScheduler: any PrayerNotificationScheduling
    private let widgetSnapshotWriter: (any WidgetPrayerSnapshotWriting)?
    private let diskCache: PrayerTimesDiskCache

    var mosques: [Mosque] = []
    var selectedMosque: Mosque?
    var monthData: MonthPrayerData?
    var ramadanData: RamadanPrayerData?
    var ukDst: [UkDstYear] = []

    private var loadedMonthNumber: Int?
    private var loadedMonthYear: Int?
    private var lastAvailablePrayerDate: Date?

    var hasAvailablePrayerTimesFallback: Bool { lastAvailablePrayerDate != nil }

    var displayedPrayerTimes: DailyPrayerTimes?
    var iqamahTimes: DailyIqamahTimes?
    var nextCountdown: NextPrayerCountdownResult?

    /// Which prayer is shown on the home hero; drives sky / glass theme (shared with chrome like `AdhanMiniPlayerBar`).
    var selectedPrayerIndex: Int = 0

    /// The date currently displayed on the home screen. Changed by left/right arrow navigation.
    var displayedDate: Date = Date()

    var loadState: LoadState = .idle
    /// True while fetching prayer payload for a newly navigated month/day.
    private(set) var isLoadingDisplayedDate = false
    var lastError: String?

    private var activeDisplayedDateLoads = 0

    /// Last time a full prayer payload network refresh succeeded (UTC). Used for foreground throttle.
    private(set) var lastPrayerPayloadRefreshAt: Date?

    enum LoadState: Equatable {
        case idle, loading, loaded, empty
    }

    /// Single-flight token — non-nil while a network refresh is in flight.
    private var refreshTask: Task<Void, Never>?

    init(
        repository: any PrayerRepository,
        settings: SettingsStore,
        notificationScheduler: any PrayerNotificationScheduling,
        widgetSnapshotWriter: (any WidgetPrayerSnapshotWriting)? = nil,
        diskCache: PrayerTimesDiskCache
    ) {
        self.repository = repository
        self.settings = settings
        self.notificationScheduler = notificationScheduler
        self.widgetSnapshotWriter = widgetSnapshotWriter
        self.diskCache = diskCache
    }

    // MARK: - Load (SWR)

    func load() async {
        loadState = .loading
        lastError = nil

        // 1. Hydrate from cache first for instant first paint.
        let cachedMosques = diskCache.loadMosques()
        if let cachedMosques {
            mosques = cachedMosques
            selectedMosque = MosqueDefaults.resolveSelectedMosque(
                mosques: cachedMosques,
                selectedId: settings.selectedMosqueId,
                selectedSlug: settings.selectedMosqueSlug
            )
            if let m = selectedMosque {
                hydrateFromCache(for: m)
            }
        }

        // 2. Full network refresh (overwrites in-memory state on success).
        await runNetworkRefresh()
    }

    // MARK: - Refresh prayer payload

    func refreshPrayerPayload(for mosque: Mosque) async throws {
        let now = Date()
        let sh = PrayerTimesEngine.getDateInSheffield(now)
        guard let monthName = MonthName.from(monthNumber: sh.month) else { return }
        async let monthly = repository.getMonthlyPrayerTimes(mosqueSlug: mosque.slug, month: monthName, year: sh.year)
        async let ramadan = repository.getRamadanTimetable(
            mosqueSlug: mosque.slug,
            date: PrayerTimesEngine.isoDateString(year: sh.year, month: sh.month, day: sh.day)
        )
        async let dst = repository.getUkDstDates()
        let monthData = try await monthly
        let ramadanData = try await ramadan
        let dstCalendar = try await dst
        let ukDst = dstCalendar?.ukDstDates ?? []

        let isoDate = PrayerTimesEngine.isoDateString(year: sh.year, month: sh.month, day: sh.day)

        // Persist to disk cache on success. If the backend has no usable current-month
        // timetable, remove any stale cache so Home and Timetable agree.
        if let monthData, !monthData.prayerTimes.isEmpty {
            try? diskCache.saveMonthly(slug: mosque.slug, month: monthName.rawValue, year: sh.year, data: monthData)
        } else {
            diskCache.removeMonthly(slug: mosque.slug, month: monthName.rawValue, year: sh.year)
        }
        if let ramadanData {
            try? diskCache.saveRamadan(slug: mosque.slug, date: isoDate, data: ramadanData)
        }
        if let dstCalendar {
            try? diskCache.saveUkDst(dstCalendar)
        }

        self.monthData = monthData
        self.ramadanData = ramadanData
        self.ukDst = ukDst
        self.loadedMonthNumber = sh.month
        self.loadedMonthYear = sh.year

        applyPrayerTimes(for: displayedDate, mosque: mosque)

        lastPrayerPayloadRefreshAt = Date()
    }

    func manualRefresh() async {
        guard let m = selectedMosque else { return }
        loadState = .loading
        do {
            try await refreshPrayerPayload(for: m)
            await refreshWidgetSnapshot(for: m)
            lastError = nil
            loadState = .loaded
        } catch {
            lastError = error.localizedDescription
            loadState = .loaded
        }
    }

    // MARK: - Date navigation

    /// Navigate to the previous day (resolves prayer times from cached monthly data).
    func goToPreviousDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: displayedDate) else { return }
        displayedDate = newDate
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    /// Navigate to the next day (resolves prayer times from cached monthly data, fetching the next month if needed).
    func goToNextDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: displayedDate) else { return }
        displayedDate = newDate
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    /// Reset the displayed date back to today.
    func goToToday() {
        displayedDate = Date()
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    /// Jump to a specific calendar day (e.g. from the native date picker).
    func goToDate(_ date: Date) {
        let parts = PrayerTimesEngine.getDateInSheffield(date)
        displayedDate = PrayerTimesEngine.sheffieldNoonUTC(year: parts.year, month: parts.month, day: parts.day)
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    /// Return to the most recent date that successfully displayed prayer times.
    func goToLastAvailablePrayerDate() {
        guard let lastAvailablePrayerDate else { return }
        displayedDate = lastAvailablePrayerDate
        loadOrApplyPrayerTimesForDisplayedDate()
    }

    /// Resolve prayer times and iqamah times for the given date using the currently loaded monthly data.
    /// Only shows countdown when viewing today.
    private func applyPrayerTimes(for date: Date, mosque: Mosque?) {
        guard let mosque, let monthly = monthData, loadedMonthMatches(date) else {
            clearDisplayedPrayerTimes()
            return
        }
        do {
            let raw = try PrayerTimesEngine.resolvePrayerTimes(
                slug: mosque.slug,
                on: date,
                monthly: monthly,
                ramadan: ramadanData,
                ukDst: ukDst,
                asrTimingPreference: settings.asrIqamahPreference
            )
            displayedPrayerTimes = PrayerTimesEngine.getDisplayedPrayerTimes(raw, date: date, mosqueSlug: mosque.slug)
            lastAvailablePrayerDate = date
        } catch {
            displayedPrayerTimes = nil
        }
        if let iq = try? PrayerTimesEngine.resolveIqamahTimesWithDstMapping(
            slug: mosque.slug,
            on: date,
            monthly: monthly,
            ramadan: ramadanData,
            ukDst: ukDst
        ) {
            iqamahTimes = iq
        } else {
            iqamahTimes = nil
        }
        var sheffieldCal = Calendar(identifier: .gregorian)
        sheffieldCal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let isToday = sheffieldCal.isDate(date, inSameDayAs: Date())
        if isToday, let d = displayedPrayerTimes, let iq = iqamahTimes {
            nextCountdown = PrayerTimesEngine.getNextPrayerAndCountdown(
                prayerTimes: d,
                iqamahTimes: iq,
                mosqueSlug: mosque.slug,
                now: Date(),
                asrIqamahPreference: settings.asrIqamahPreference,
                includeTomorrowFajr: false
            )
        } else {
            nextCountdown = nil
        }
    }

    private func loadOrApplyPrayerTimesForDisplayedDate() {
        guard let mosque = selectedMosque else {
            clearDisplayedPrayerTimes()
            return
        }
        let targetDate = displayedDate
        if loadedMonthMatches(targetDate) {
            applyPrayerTimes(for: targetDate, mosque: mosque)
            return
        }

        if hydrateMonthFromCache(for: targetDate, mosque: mosque) {
            return
        }

        activeDisplayedDateLoads += 1
        isLoadingDisplayedDate = true
        clearDisplayedPrayerTimes()
        Task { [weak self] in
            guard let self else { return }
            defer { self.finishDisplayedDateLoad() }
            await self.loadPrayerPayload(for: targetDate, mosque: mosque)
        }
    }

    private func finishDisplayedDateLoad() {
        activeDisplayedDateLoads = max(0, activeDisplayedDateLoads - 1)
        isLoadingDisplayedDate = activeDisplayedDateLoads > 0
    }

    private func loadedMonthMatches(_ date: Date) -> Bool {
        let parts = PrayerTimesEngine.getDateInSheffield(date)
        return loadedMonthNumber == parts.month && loadedMonthYear == parts.year
    }

    private func clearDisplayedPrayerTimes() {
        displayedPrayerTimes = nil
        iqamahTimes = nil
        nextCountdown = nil
    }

    private func loadPrayerPayload(for date: Date, mosque: Mosque) async {
        let parts = PrayerTimesEngine.getDateInSheffield(date)
        guard let monthName = MonthName.from(monthNumber: parts.month) else { return }
        let isoDate = PrayerTimesEngine.isoDateString(year: parts.year, month: parts.month, day: parts.day)

        do {
            async let monthly = repository.getMonthlyPrayerTimes(mosqueSlug: mosque.slug, month: monthName, year: parts.year)
            async let ramadan = repository.getRamadanTimetable(mosqueSlug: mosque.slug, date: isoDate)
            async let dst = repository.getUkDstDates()
            let fetchedMonthly = try await monthly
            let fetchedRamadan = try await ramadan
            let dstCalendar = try await dst

            if let fetchedMonthly, !fetchedMonthly.prayerTimes.isEmpty {
                try? diskCache.saveMonthly(slug: mosque.slug, month: monthName.rawValue, year: parts.year, data: fetchedMonthly)
            } else {
                diskCache.removeMonthly(slug: mosque.slug, month: monthName.rawValue, year: parts.year)
            }
            if let fetchedRamadan { try? diskCache.saveRamadan(slug: mosque.slug, date: isoDate, data: fetchedRamadan) }
            if let dstCalendar { try? diskCache.saveUkDst(dstCalendar) }

            guard PrayerTimesEngine.getDateInSheffield(displayedDate).month == parts.month,
                  PrayerTimesEngine.getDateInSheffield(displayedDate).year == parts.year,
                  selectedMosque?.slug == mosque.slug else { return }

            monthData = fetchedMonthly
            ramadanData = fetchedRamadan
            ukDst = dstCalendar?.ukDstDates ?? ukDst
            loadedMonthNumber = parts.month
            loadedMonthYear = parts.year
            applyPrayerTimes(for: displayedDate, mosque: mosque)
        } catch {
            if let cached = diskCache.loadMonthly(slug: mosque.slug, month: monthName.rawValue, year: parts.year) {
                monthData = cached
                ramadanData = diskCache.loadRamadan(slug: mosque.slug, date: isoDate)
                ukDst = diskCache.loadUkDst()?.ukDstDates ?? ukDst
                loadedMonthNumber = parts.month
                loadedMonthYear = parts.year
                applyPrayerTimes(for: displayedDate, mosque: mosque)
            }
        }
    }

    func applySelectionFromSettings() async {
        // Hydrate from cache for the new mosque first.
        if let cachedMosques = diskCache.loadMosques(),
           let m = MosqueDefaults.resolveSelectedMosque(
            mosques: cachedMosques,
            selectedId: settings.selectedMosqueId,
            selectedSlug: settings.selectedMosqueSlug
           ) {
            selectedMosque = m
            mosques = cachedMosques
            hydrateFromCache(for: m)
        }

        // Then network refresh.
        if let m = MosqueDefaults.resolveSelectedMosque(
            mosques: mosques,
            selectedId: settings.selectedMosqueId,
            selectedSlug: settings.selectedMosqueSlug
        ) {
            selectedMosque = m
            do {
                try await refreshPrayerPayload(for: m)
                await refreshWidgetSnapshot(for: m)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Stale-while-revalidate helper

    /// Called on foreground transition — silently re-fetches if last refresh is stale.
    func refreshFromNetworkIfStale() async {
        let stalenessInterval: TimeInterval = 5 * 60 // 5 minutes
        if let last = lastPrayerPayloadRefreshAt, Date().timeIntervalSince(last) < stalenessInterval {
            return
        }
        guard let m = selectedMosque else { return }
        // Single-flight: skip if a refresh is already running.
        if refreshTask != nil { return }
        refreshTask = Task {
            defer { refreshTask = nil }
            do {
                try await refreshPrayerPayload(for: m)
                await refreshWidgetSnapshot(for: m)
            } catch {
                // Silent — don't disturb the user with errors on foreground resume.
            }
        }
        _ = await refreshTask?.value
    }

    // MARK: - Private helpers

    /// Runs full network refresh (mosques + prayer payload) and saves cached state.
    private func runNetworkRefresh() async {
        do {
            let list = try await repository.listMosques()
            mosques = MosqueDefaults.visibleMosques(list)
            try? diskCache.saveMosques(mosques)

            selectedMosque = MosqueDefaults.resolveSelectedMosque(
                mosques: list,
                selectedId: settings.selectedMosqueId,
                selectedSlug: settings.selectedMosqueSlug
            )
            guard let mosque = selectedMosque else {
                loadState = .empty
                return
            }
            settings.selectedMosqueId = mosque.id
            settings.selectedMosqueSlug = mosque.slug
            settings.selectedCityGroupingKey = mosque.cityGroupingKey
            settings.selectedCountryGroupingKey = MosqueDefaults.countryGroupingKey(for: mosque)
            try await refreshPrayerPayload(for: mosque)
            await refreshWidgetSnapshot(for: mosque)
            refreshWidgetSnapshotsInBackground(selected: mosque)
            loadState = .loaded
        } catch {
            lastError = error.localizedDescription
            loadState = mosques.isEmpty ? .empty : .loaded
        }
    }

    /// Fill in-memory state from disk cache for the given mosque (no-op if cache miss).
    private func hydrateFromCache(for mosque: Mosque) {
        if hydrateMonthFromCache(for: displayedDate, mosque: mosque) {
            loadState = .loaded
        }
    }

    @discardableResult
    private func hydrateMonthFromCache(for date: Date, mosque: Mosque) -> Bool {
        let sh = PrayerTimesEngine.getDateInSheffield(date)
        guard let monthName = MonthName.from(monthNumber: sh.month) else { return false }

        let isoDate = PrayerTimesEngine.isoDateString(year: sh.year, month: sh.month, day: sh.day)
        guard let monthly = diskCache.loadMonthly(slug: mosque.slug, month: monthName.rawValue, year: sh.year) else {
            return false
        }

        monthData = monthly
        ramadanData = diskCache.loadRamadan(slug: mosque.slug, date: isoDate)
        ukDst = diskCache.loadUkDst()?.ukDstDates ?? ukDst
        loadedMonthNumber = sh.month
        loadedMonthYear = sh.year
        applyPrayerTimes(for: date, mosque: mosque)
        return displayedPrayerTimes != nil
    }

    func refreshWidgetSnapshotForCurrentMosque() async {
        guard let selectedMosque else { return }
        await refreshWidgetSnapshot(for: selectedMosque)
    }

    func resyncNotificationsIfNeeded() async {
        let n = settings.notifications
        guard n.masterEnabled, let mosque = selectedMosque else {
            await notificationScheduler.cancelAllPrayerNotifications()
            return
        }
        try? await notificationScheduler.rescheduleUpcomingPrayerNotifications(
            mosque: mosque,
            days: 7,
            settings: n,
            locale: settings.resolvedLocale,
            asrIqamahPreference: settings.asrIqamahPreference
        )
    }

    func fetchMonthData(mosqueSlug: String, month: Int, year: Int) async -> MonthPrayerData? {
        guard let monthName = MonthName.from(monthNumber: month) else { return nil }

        do {
            let data = try await repository.getMonthlyPrayerTimes(mosqueSlug: mosqueSlug, month: monthName, year: year)
            if let data, !data.prayerTimes.isEmpty {
                try? diskCache.saveMonthly(slug: mosqueSlug, month: monthName.rawValue, year: year, data: data)
                return data
            }
            diskCache.removeMonthly(slug: mosqueSlug, month: monthName.rawValue, year: year)
            return data
        } catch {
            return diskCache.loadMonthly(slug: mosqueSlug, month: monthName.rawValue, year: year)
        }
    }

    private func refreshWidgetSnapshot(for mosque: Mosque) async {
        await widgetSnapshotWriter?.refreshSnapshot(for: mosque, days: 7)
    }

    private func refreshWidgetSnapshotsInBackground(selected mosque: Mosque) {
        let visibleMosques = mosques
        let writer = widgetSnapshotWriter
        Task { @MainActor in
            await writer?.refreshSnapshots(for: visibleMosques, selectedMosque: mosque, days: 7)
        }
    }
}
