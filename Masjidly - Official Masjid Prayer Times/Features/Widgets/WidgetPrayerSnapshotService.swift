import Foundation
import WidgetKit

@MainActor
protocol WidgetPrayerSnapshotWriting: AnyObject {
    func refreshSnapshot(for mosque: Mosque, days: Int) async
}

@MainActor
final class WidgetPrayerSnapshotService: WidgetPrayerSnapshotWriting {
    private let repository: any PrayerRepository
    private let settings: SettingsStore
    private let store: WidgetPrayerSnapshotStore

    init(
        repository: any PrayerRepository,
        settings: SettingsStore
    ) {
        self.repository = repository
        self.settings = settings
        store = WidgetPrayerSnapshotStore()
    }

    func refreshSnapshot(for mosque: Mosque, days: Int = 7) async {
        guard days > 0 else { return }
        do {
            let snapshot = try await buildSnapshot(for: mosque, days: days)
            try store.writeSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Widgets keep rendering their last valid snapshot if a refresh fails.
        }
    }

    private func buildSnapshot(for mosque: Mosque, days: Int) async throws -> WidgetPrayerSnapshot {
        let now = Date()
        let dst = (try await repository.getUkDstDates())?.ukDstDates ?? []
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
                let fetched = try await repository.getMonthlyPrayerTimes(
                    mosqueSlug: mosque.slug,
                    month: monthName,
                    year: parts.year
                )
                monthlyCache[monthCacheKey] = fetched
                monthly = fetched
            }

            let dateString = PrayerTimesEngine.isoDateString(year: parts.year, month: parts.month, day: parts.day)
            let ramadan = try await repository.getRamadanTimetable(mosqueSlug: mosque.slug, date: dateString)
            let raw = try PrayerTimesEngine.resolvePrayerTimes(
                slug: mosque.slug,
                on: date,
                monthly: monthly,
                ramadan: ramadan,
                ukDst: dst
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
            mosque: WidgetMosqueSnapshot(id: mosque.id, name: mosque.name, slug: mosque.slug),
            days: daySnapshots,
            uses24HourTime: settings.uses24HourTime,
            appLanguageRawValue: settings.appLanguage.rawValue
        )
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
