import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private let repository: any PrayerRepository
    private let settings: SettingsStore
    private let notificationScheduler: any PrayerNotificationScheduling
    private let widgetSnapshotWriter: (any WidgetPrayerSnapshotWriting)?

    var mosques: [Mosque] = []
    var selectedMosque: Mosque?
    var monthData: MonthPrayerData?
    var ramadanData: RamadanPrayerData?
    var ukDst: [UkDstYear] = []

    var displayedPrayerTimes: DailyPrayerTimes?
    var iqamahTimes: DailyIqamahTimes?
    var nextCountdown: NextPrayerCountdownResult?

    var loadState: LoadState = .idle
    var lastError: String?

    enum LoadState: Equatable {
        case idle, loading, loaded, empty
    }

    init(
        repository: any PrayerRepository,
        settings: SettingsStore,
        notificationScheduler: any PrayerNotificationScheduling,
        widgetSnapshotWriter: (any WidgetPrayerSnapshotWriting)? = nil
    ) {
        self.repository = repository
        self.settings = settings
        self.notificationScheduler = notificationScheduler
        self.widgetSnapshotWriter = widgetSnapshotWriter
    }

    func load() async {
        loadState = .loading
        lastError = nil
        do {
            let list = try await repository.listMosques()
            mosques = MosqueDefaults.visibleMosques(list)
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
            try await refreshPrayerPayload(for: mosque)
            await refreshWidgetSnapshot(for: mosque)
            loadState = .loaded
        } catch {
            lastError = error.localizedDescription
            loadState = mosques.isEmpty ? .empty : .loaded
        }
    }

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
        monthData = try await monthly
        ramadanData = try await ramadan
        ukDst = (try await dst)?.ukDstDates ?? []

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
        let list = try? await repository.listMosques()
        let full = list ?? mosques
        if let m = MosqueDefaults.resolveSelectedMosque(
            mosques: full,
            selectedId: settings.selectedMosqueId,
            selectedSlug: settings.selectedMosqueSlug
        ) {
            selectedMosque = m
            mosques = MosqueDefaults.visibleMosques(full)
            do {
                try await refreshPrayerPayload(for: m)
                await refreshWidgetSnapshot(for: m)
            } catch {
                lastError = error.localizedDescription
            }
        }
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
        return try? await repository.getMonthlyPrayerTimes(mosqueSlug: mosqueSlug, month: monthName, year: year)
    }

    private func refreshWidgetSnapshot(for mosque: Mosque) async {
        await widgetSnapshotWriter?.refreshSnapshot(for: mosque, days: 7)
    }
}
