import Foundation
import WidgetKit

@MainActor
protocol WidgetPrayerSnapshotWriting: AnyObject {
    func refreshSnapshot(for mosque: Mosque, days: Int) async
    func refreshSnapshots(for mosques: [Mosque], selectedMosque: Mosque?, days: Int) async
}

@MainActor
final class WidgetPrayerSnapshotService: WidgetPrayerSnapshotWriting {
    private let repository: any PrayerRepository
    private let settings: SettingsStore
    private let diskCache: PrayerTimesDiskCache
    private let store: WidgetPrayerSnapshotStore

    init(
        repository: any PrayerRepository,
        settings: SettingsStore,
        diskCache: PrayerTimesDiskCache
    ) {
        self.repository = repository
        self.settings = settings
        self.diskCache = diskCache
        store = WidgetPrayerSnapshotStore()
    }

    func refreshSnapshot(for mosque: Mosque, days: Int = 7) async {
        guard days > 0 else { return }
        do {
            let snapshot = try await buildSnapshot(for: mosque, days: days)
            try store.writeSnapshot(snapshot)
            // Sync the app's selected mosque ID to the shared App Group so the widget
            // can use it as the default mosque in its configuration intent.
            if let defaults = UserDefaults(suiteName: WidgetPrayerSharedConfig.appGroupIdentifier) {
                defaults.set(mosque.id, forKey: WidgetPrayerSharedConfig.appSelectedMosqueIdKey)
            }
            WidgetCenter.shared.reloadAllTimelines()
            WatchPrayerSnapshotTransferService.shared.sendLatestSnapshot()
        } catch {
            // Widgets keep rendering their last valid snapshot if a refresh fails.
        }
    }

    func refreshSnapshots(for mosques: [Mosque], selectedMosque: Mosque?, days: Int = 7) async {
        guard days > 0 else { return }
        let visible = MosqueDefaults.visibleMosques(mosques)
        do {
            try store.writeMosqueDirectory(visible.map { mosque in
                WidgetMosqueSnapshot(
                    id: mosque.id,
                    name: mosque.name,
                    slug: mosque.slug,
                    citySlug: mosque.citySlug,
                    cityName: mosque.cityName,
                    countryCode: mosque.countryCode,
                    countryName: mosque.countryName
                )
            })
        } catch {
            // The widget can still use previously persisted options.
        }

        if let selectedMosque {
            await refreshSnapshot(for: selectedMosque, days: days)
        }

        for mosque in visible where mosque.id != selectedMosque?.id {
            do {
                let snapshot = try await buildSnapshot(for: mosque, days: days)
                try store.writeSnapshot(snapshot, updateDefault: false)
            } catch {
                // Keep any previous snapshot for this mosque.
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func buildSnapshot(for mosque: Mosque, days: Int) async throws -> WidgetPrayerSnapshot {
        let now = Date()
        let dstCalendar = try await fetchUkDstCalendar()
        let dst = dstCalendar?.ukDstDates ?? []
        var monthlyCache: [String: MonthPrayerData?] = [:]
        var daySnapshots: [WidgetPrayerDaySnapshot] = []

        for offset in 0..<days {
            let date = try resolveDate(offsetByDays: offset, from: now)
            let parts = PrayerTimesEngine.getDateInSheffield(date)
            guard let monthName = MonthName.from(monthNumber: parts.month) else { continue }
            let monthCacheKey = "\(mosque.slug)-\(parts.year)-\(monthName.rawValue)"
            let monthly: MonthPrayerData?
            if let cached = monthlyCache[monthCacheKey] {
                monthly = cached
            } else {
                let fetched = try await fetchMonthly(mosqueSlug: mosque.slug, month: monthName, year: parts.year)
                monthlyCache[monthCacheKey] = fetched
                monthly = fetched
            }

            let dateString = PrayerTimesEngine.isoDateString(year: parts.year, month: parts.month, day: parts.day)
            let ramadan = try await fetchRamadan(mosqueSlug: mosque.slug, date: dateString)
            let raw = try PrayerTimesEngine.resolvePrayerTimes(
                slug: mosque.slug,
                on: date,
                monthly: monthly,
                ramadan: ramadan,
                ukDst: dst,
                asrTimingPreference: settings.asrIqamahPreference
            )
            let displayed = PrayerTimesEngine.getDisplayedPrayerTimes(raw, date: date, mosqueSlug: mosque.slug)
            let iqamah = try PrayerTimesEngine.resolveIqamahTimesWithDstMapping(
                slug: mosque.slug,
                on: date,
                monthly: monthly,
                ramadan: ramadan,
                ukDst: dst
            )
            daySnapshots.append(WidgetPrayerDaySnapshot(date: dateString, prayers: displayed, iqamah: iqamah))
        }

        return WidgetPrayerSnapshot(
            schemaVersion: WidgetPrayerSnapshot.currentSchemaVersion,
            generatedAt: now,
            mosque: WidgetMosqueSnapshot(
                id: mosque.id,
                name: mosque.name,
                slug: mosque.slug,
                citySlug: mosque.citySlug,
                cityName: mosque.cityName,
                countryCode: mosque.countryCode,
                countryName: mosque.countryName
            ),
            days: daySnapshots,
            uses24HourTime: settings.uses24HourTime,
            appLanguageRawValue: AppLanguage.english.rawValue,
            asrIqamahPreference: settings.asrIqamahPreference
        )
    }

    private func fetchUkDstCalendar() async throws -> UkDstCalendar? {
        do {
            let calendar = try await repository.getUkDstDates()
            if let calendar { try? diskCache.saveUkDst(calendar) }
            return calendar ?? diskCache.loadUkDst()
        } catch {
            if let cached = diskCache.loadUkDst() { return cached }
            throw error
        }
    }

    private func fetchMonthly(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? {
        do {
            let monthly = try await repository.getMonthlyPrayerTimes(mosqueSlug: mosqueSlug, month: month, year: year)
            if let monthly { try? diskCache.saveMonthly(slug: mosqueSlug, month: month.rawValue, year: year, data: monthly) }
            return monthly ?? diskCache.loadMonthly(slug: mosqueSlug, month: month.rawValue, year: year)
        } catch {
            if let cached = diskCache.loadMonthly(slug: mosqueSlug, month: month.rawValue, year: year) { return cached }
            throw error
        }
    }

    private func fetchRamadan(mosqueSlug: String, date: String) async throws -> RamadanPrayerData? {
        do {
            let ramadan = try await repository.getRamadanTimetable(mosqueSlug: mosqueSlug, date: date)
            if let ramadan { try? diskCache.saveRamadan(slug: mosqueSlug, date: date, data: ramadan) }
            return ramadan ?? diskCache.loadRamadan(slug: mosqueSlug, date: date)
        } catch {
            if let cached = diskCache.loadRamadan(slug: mosqueSlug, date: date) { return cached }
            throw error
        }
    }

    private func resolveDate(offsetByDays offset: Int, from date: Date) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let resolved = calendar.date(byAdding: .day, value: offset, to: date) else {
            throw WidgetPrayerSnapshotServiceError.invalidDateOffset
        }
        return resolved
    }
}

enum WidgetPrayerSnapshotServiceError: Error {
    case invalidDateOffset
}
