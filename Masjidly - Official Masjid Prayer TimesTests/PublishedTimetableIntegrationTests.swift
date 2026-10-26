import Foundation
import Testing
@testable import Masjidly

// Home date-picker navigation reaches repository, disk cache and display resolution.
// E2E cannot pin the schedulers' Date(); no production clock hook is added here.
@Suite("Published timetable consumer integration")
@MainActor
struct PublishedTimetableIntegrationTests {
    @Test func october23DisplaysEveryPublishedClockValue() async throws {
        let home = try await navigate(to: "2026-10-23")
        expectPublishedPrayers(try #require(home.displayedPrayerTimes), date: "2026-10-23")
    }

    @Test func october27UsesOctober27IqamahNotMappedDay3() async throws {
        // The repository also supplies distinct November data. Neither November
        // nor October's early-month ranges may replace the calendar day's range.
        let home = try await navigate(to: "2026-10-27")
        #expect(home.iqamahTimes == DailyIqamahTimes(
            fajr: "06:32", dhuhr: "13:32", asr: "16:32",
            maghrib: "18:32", isha: "20:32", jummah: "13:42"
        ))
    }

    @Test(arguments: ["2026-03-23", "2026-03-30"], ["test-masjid", "masjid-risalah"])
    func marchUsesPublishedAdhanAndIqamah(date: String, slug: String) async throws {
        let home = try await navigate(to: date, slug: slug)
        expectPublishedPrayers(try #require(home.displayedPrayerTimes), date: date)
        let expected = date == "2026-03-23"
            ? DailyIqamahTimes(fajr: "06:22", dhuhr: "13:22", asr: "16:22", maghrib: "18:22", isha: "20:22", jummah: "13:42")
            : DailyIqamahTimes(fajr: "06:32", dhuhr: "13:32", asr: "16:32", maghrib: "18:32", isha: "20:32", jummah: "13:42")
        #expect(home.iqamahTimes == expected)
    }

    @Test func alHudaOctober24UsesCalendarRow24NotShiftedRow22() async throws {
        let home = try await navigate(to: "2026-10-24", slug: "masjid-al-huda-sheffield")
        #expect(home.displayedPrayerTimes == DailyPrayerTimes(
            date: "2026-10-24", fajr: "06:24", sunrise: "07:24", dhuhr: "12:10",
            asr: "15:24", maghrib: "17:24", isha: "19:24"
        ))
        #expect(home.iqamahTimes?.fajr == "06:22")
    }

    @Test func ordinaryJanuaryDateIsUnchanged() async throws {
        let home = try await navigate(to: "2026-01-15")
        expectPublishedPrayers(try #require(home.displayedPrayerTimes), date: "2026-01-15")
        #expect(home.iqamahTimes?.fajr == "06:22")
        #expect(home.iqamahTimes?.isha == "20:22")
    }

    @Test func ramadanDateSelectsRamadanInsteadOfMonthlyRows() async throws {
        let home = try await navigate(to: "2026-02-20")
        #expect(home.displayedPrayerTimes == DailyPrayerTimes(
            date: "2026-02-20", fajr: "05:03", sunrise: "06:03", dhuhr: "12:03",
            asr: "15:03", maghrib: "17:03", isha: "19:03"
        ))
        #expect(home.iqamahTimes == DailyIqamahTimes(
            fajr: "05:33", dhuhr: "12:33", asr: "15:33",
            maghrib: "17:33", isha: "19:33", jummah: "12:43"
        ))
    }

    // The scheduler has no accessible pinned-date entry point. This guard uses
    // the real widget consumer's event transitions at literal UTC instants.
    // It proves London wall-clock conversion, not notification submission.
    @Test(arguments: [
        "2026-10-24|2026-10-24T05:00:00Z|2026-10-24T05:20:00Z",
        "2026-10-26|2026-10-26T06:00:00Z|2026-10-26T06:20:00Z",
        "2026-03-28|2026-03-28T06:00:00Z|2026-03-28T06:20:00Z",
        "2026-03-30|2026-03-30T05:00:00Z|2026-03-30T05:20:00Z"
    ])
    func publishedWidgetEventsKeepLondonOffsets(example: String) throws {
        let values = example.components(separatedBy: "|")
        let adhan = try #require(ISO8601DateFormatter().date(from: values[1]))
        let iqamah = try #require(ISO8601DateFormatter().date(from: values[2]))
        let snapshot = WidgetPrayerSnapshot(
            schemaVersion: 1, generatedAt: adhan.addingTimeInterval(-3600),
            mosque: WidgetMosqueSnapshot(id: "published", name: "Published", slug: "test-masjid", citySlug: nil, cityName: nil, countryCode: nil, countryName: nil, timezone: "Europe/London"),
            days: [WidgetPrayerDaySnapshot(
                date: values[0],
                prayers: DailyPrayerTimes(date: values[0], fajr: "06:00", sunrise: "07:00", dhuhr: "13:00", asr: "16:00", maghrib: "18:00", isha: "20:00"),
                iqamah: DailyIqamahTimes(fajr: "06:20", dhuhr: "13:20", asr: "16:20", maghrib: "18:20", isha: "20:20", jummah: "13:40")
            )], uses24HourTime: true, appLanguageRawValue: "english", asrIqamahPreference: .first
        )
        let decoded = try JSONDecoder().decode(WidgetPrayerSnapshot.self, from: JSONEncoder().encode(snapshot))
        let beforeAdhan = try WidgetPrayerResolver.resolve(snapshot: decoded, now: adhan.addingTimeInterval(-1))
        #expect(beforeAdhan.prayerName == "Fajr")
        #expect(beforeAdhan.adhanTime == "06:00")
        #expect(beforeAdhan.isIqamah == false)
        let afterAdhan = try WidgetPrayerResolver.resolve(snapshot: decoded, now: adhan.addingTimeInterval(1))
        #expect(afterAdhan.prayerName == "Fajr")
        #expect(afterAdhan.iqamahTime == "06:20")
        #expect(afterAdhan.isIqamah == true)
        let beforeIqamah = try WidgetPrayerResolver.resolve(snapshot: decoded, now: iqamah.addingTimeInterval(-1))
        #expect(beforeIqamah.prayerName == "Fajr")
        #expect(beforeIqamah.isIqamah == true)
        let afterIqamah = try WidgetPrayerResolver.resolve(snapshot: decoded, now: iqamah.addingTimeInterval(1))
        #expect(afterIqamah.prayerName == "Dhuhr")
        #expect(afterIqamah.isIqamah == false)
    }

    private func expectPublishedPrayers(_ actual: DailyPrayerTimes, date: String) {
        #expect(actual == DailyPrayerTimes(
            date: date, fajr: "06:01", sunrise: "07:02", dhuhr: "13:03",
            asr: "16:04", maghrib: "18:05", isha: "20:06"
        ))
    }

    private func navigate(to date: String, slug: String = "test-masjid") async throws -> HomeViewModel {
        let repository = PublishedTimetableRepository()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "PublishedTimetable.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let home = HomeViewModel(
            repository: repository, settings: SettingsStore(defaults: defaults),
            notificationScheduler: PrayerNotificationScheduler(repository: repository),
            diskCache: PrayerTimesDiskCache(fileManager: PublishedTimetableFileManager(root: root))
        )
        home.selectedMosque = Mosque(id: slug, name: "Published", address: "", lat: 0, lng: 0, slug: slug, citySlug: nil, cityName: nil, countryCode: nil, countryName: nil, timezone: "Europe/London", website: nil, isHidden: false)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let parts = date.split(separator: "-").compactMap { Int($0) }
        let pinned = try #require(calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)))
        home.goToDate(pinned)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while home.isLoadingDisplayedDate && ContinuousClock.now < deadline { await Task.yield() }
        try #require(!home.isLoadingDisplayedDate, "Pinned-date repository load timed out")
        try #require(home.displayedPrayerTimes != nil)
        return home
    }
}

private final class PublishedTimetableFileManager: FileManager, @unchecked Sendable {
    let root: URL
    init(root: URL) { self.root = root; super.init() }
    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] { [root] }
}

private final class PublishedTimetableRepository: PrayerRepository {
    func listMosques() async throws -> [Mosque] { [] }

    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? {
        let rows = (1...31).map { day in
            if mosqueSlug == "masjid-al-huda-sheffield" && month == .october {
                return PrayerTime(date: day, fajr: String(format: "06:%02d", day), shurooq: String(format: "07:%02d", day), dhuhr: day < 23 ? "13:10" : "12:10", asr: String(format: "15:%02d", day), maghrib: String(format: "17:%02d", day), isha: String(format: "19:%02d", day))
            }
            return PrayerTime(date: day, fajr: "06:01", shurooq: "07:02", dhuhr: "13:03", asr: "16:04", maghrib: "18:05", isha: "20:06")
        }
        let ranges: [IqamahTimeRange] = month == .november
            ? [IqamahTimeRange(dateRange: "1-30", fajr: "07:44", dhuhr: "14:44", asr: "17:44", maghrib: "19:44", isha: "21:44", jummah: "14:54")]
            : [
                IqamahTimeRange(dateRange: "1-10", fajr: "06:12", dhuhr: "13:12", asr: "16:12", maghrib: "18:12", isha: "20:12", jummah: "13:42"),
                IqamahTimeRange(dateRange: "11-25", fajr: "06:22", dhuhr: "13:22", asr: "16:22", maghrib: "18:22", isha: "20:22", jummah: "13:42"),
                IqamahTimeRange(dateRange: "26-31", fajr: "06:32", dhuhr: "13:32", asr: "16:32", maghrib: "18:32", isha: "20:32", jummah: "13:42")
            ]
        return MonthPrayerData(month: month.rawValue, prayerTimes: rows, iqamahTimes: ranges, jummahIqamah: "13:42")
    }

    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData? {
        guard date == "2026-02-20" else { return nil }
        return RamadanPrayerData(
            month: "Ramadan", gregorianStart: "2026-02-18", gregorianEnd: "2026-03-19",
            prayerTimes: [RamadanPrayerDay(ramadanDay: 3, gregorian: "2026-02-20", fajr: "05:03", shurooq: "06:03", dhuhr: "12:03", asr: "15:03", maghrib: "17:03", isha: "19:03")],
            iqamahTimes: [IqamahTimeRange(dateRange: "1-30", fajr: "05:33", dhuhr: "12:33", asr: "15:33", maghrib: "17:33", isha: "19:33", jummah: "12:43")], jummahIqamah: "12:43"
        )
    }
}
