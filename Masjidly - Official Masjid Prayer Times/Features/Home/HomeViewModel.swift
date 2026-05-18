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

    var displayedPrayerTimes: DailyPrayerTimes?
    var iqamahTimes: DailyIqamahTimes?
    var nextCountdown: NextPrayerCountdownResult?

    /// Which prayer is shown on the home hero; drives sky / glass theme (shared with chrome like `AdhanMiniPlayerBar`).
    var selectedPrayerIndex: Int = 0

    var loadState: LoadState = .idle
    var lastError: String?

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

        // Persist to disk cache on success.
        if let monthData {
            try? diskCache.saveMonthly(slug: mosque.slug, month: monthName.rawValue, year: sh.year, data: monthData)
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

        let raw = try PrayerTimesEngine.resolvePrayerTimes(
            slug: mosque.slug,
            on: now,
            monthly: monthData,
            ramadan: ramadanData,
            ukDst: ukDst
        )
        displayedPrayerTimes = PrayerTimesEngine.getDisplayedPrayerTimes(raw, date: now, mosqueSlug: mosque.slug)
        iqamahTimes = try PrayerTimesEngine.resolveIqamahTimesWithDstMapping(
            slug: mosque.slug,
            on: now,
            monthly: monthData,
            ramadan: ramadanData,
            ukDst: ukDst
        )
        if let d = displayedPrayerTimes, let iq = iqamahTimes {
            nextCountdown = PrayerTimesEngine.getNextPrayerAndCountdown(
                prayerTimes: d,
                iqamahTimes: iq,
                mosqueSlug: mosque.slug,
                now: now
            )
        }

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
            try await refreshPrayerPayload(for: mosque)
            await refreshWidgetSnapshot(for: mosque)
            loadState = .loaded
        } catch {
            lastError = error.localizedDescription
            loadState = mosques.isEmpty ? .empty : .loaded
        }
    }

    /// Fill in-memory state from disk cache for the given mosque (no-op if cache miss).
    private func hydrateFromCache(for mosque: Mosque) {
        let now = Date()
        let sh = PrayerTimesEngine.getDateInSheffield(now)
        guard let monthName = MonthName.from(monthNumber: sh.month) else { return }

        let isoDate = PrayerTimesEngine.isoDateString(year: sh.year, month: sh.month, day: sh.day)
        let cachedMonthly = diskCache.loadMonthly(slug: mosque.slug, month: monthName.rawValue, year: sh.year)
        let cachedRamadan = diskCache.loadRamadan(slug: mosque.slug, date: isoDate)
        let cachedDst = diskCache.loadUkDst()

        guard let monthly = cachedMonthly else { return }

        monthData = monthly
        ramadanData = cachedRamadan
        ukDst = cachedDst?.ukDstDates ?? []

        if let raw = try? PrayerTimesEngine.resolvePrayerTimes(
            slug: mosque.slug,
            on: now,
            monthly: monthly,
            ramadan: cachedRamadan,
            ukDst: ukDst
        ) {
            displayedPrayerTimes = PrayerTimesEngine.getDisplayedPrayerTimes(raw, date: now, mosqueSlug: mosque.slug)
        }
        if let iq = try? PrayerTimesEngine.resolveIqamahTimesWithDstMapping(
            slug: mosque.slug,
            on: now,
            monthly: monthly,
            ramadan: cachedRamadan,
            ukDst: ukDst
        ) {
            iqamahTimes = iq
        }
        if let d = displayedPrayerTimes, let iq = iqamahTimes {
            nextCountdown = PrayerTimesEngine.getNextPrayerAndCountdown(
                prayerTimes: d,
                iqamahTimes: iq,
                mosqueSlug: mosque.slug,
                now: now
            )
        }
        loadState = .loaded
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
            locale: settings.resolvedLocale
        )
    }

    func fetchMonthData(mosqueSlug: String, month: Int, year: Int) async -> MonthPrayerData? {
        guard let monthName = MonthName.from(monthNumber: month) else { return nil }

        // Return cached data immediately if available.
        if let cached = diskCache.loadMonthly(slug: mosqueSlug, month: monthName.rawValue, year: year) {
            return cached
        }

        // Fetch from network and cache on success.
        if let data = try? await repository.getMonthlyPrayerTimes(mosqueSlug: mosqueSlug, month: monthName, year: year) {
            try? diskCache.saveMonthly(slug: mosqueSlug, month: monthName.rawValue, year: year, data: data)
            return data
        }
        return nil
    }

    private func refreshWidgetSnapshot(for mosque: Mosque) async {
        await widgetSnapshotWriter?.refreshSnapshot(for: mosque, days: 7)
    }
}
