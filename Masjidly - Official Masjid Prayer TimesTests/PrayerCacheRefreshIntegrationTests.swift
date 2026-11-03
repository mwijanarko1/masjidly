import Foundation
import Testing
@testable import Masjidly

// Real home model, settings and disk cache. Only the remote repository boundary
// is controlled: a UI test cannot safely publish revisions to production Convex.
@Suite("Prayer cache refresh integration", .serialized)
@MainActor
struct PrayerCacheRefreshIntegrationTests {
    @Test func cachedTabRevalidatesAfterAnotherMosqueConsumedGlobalRevision() async throws {
        let fixture = try RefreshFixture(selected: "masjid-risalah")
        defer { fixture.cleanUp() }
        fixture.backend.publishMWHS()
        try fixture.seedGlobalRevision()
        let home = fixture.makeHome()
        await home.load()

        fixture.settings.activeMosqueTabId = "muslim-welfare-house"
        await home.applySelectionFromSettings(tabSwitch: true)

        #expect(home.selectedMosque?.slug == "muslim-welfare-house")
        #expect(home.iqamahTimes?.isha == "19:30")
        #expect(fixture.cachedMWHS()?.iqamahTimes.first?.isha == "19:30")
    }

    @Test func foregroundInsideFiveMinutesFetchesChangedTimetable() async throws {
        let fixture = try RefreshFixture()
        defer { fixture.cleanUp() }
        let home = fixture.makeHome()
        await home.load()
        #expect(home.iqamahTimes?.isha == "20:15")
        fixture.backend.publishMWHS()

        await home.refreshFromNetworkIfStale()

        #expect(home.iqamahTimes?.isha == "19:30")
        #expect(fixture.cachedMWHS()?.iqamahTimes.first?.isha == "19:30")
    }

    @Test func relaunchRevalidatesMosqueEvenWhenGlobalRevisionMatches() async throws {
        let fixture = try RefreshFixture()
        defer { fixture.cleanUp() }
        fixture.backend.publishMWHS()
        try fixture.seedGlobalRevision()

        let home = fixture.makeHome()
        await home.load()

        #expect(home.iqamahTimes?.isha == "19:30")
    }

    @Test func unchangedMosqueVersionAvoidsFullMonthlyDownload() async throws {
        let fixture = try RefreshFixture()
        defer { fixture.cleanUp() }
        let home = fixture.makeHome()
        await home.load()
        await home.refreshFromNetworkIfStale()
        await home.applySelectionFromSettings(tabSwitch: true)

        #expect(home.iqamahTimes?.isha == "20:15")
        #expect(fixture.backend.monthlyRequests == 0)
    }

    @Test func offlineTabAndForegroundKeepCachedTimetableVisible() async throws {
        let fixture = try RefreshFixture(selected: "masjid-risalah")
        defer { fixture.cleanUp() }
        let home = fixture.makeHome()
        await home.load()
        fixture.backend.offline = true
        fixture.settings.activeMosqueTabId = "muslim-welfare-house"

        await home.applySelectionFromSettings(tabSwitch: true)
        await home.refreshFromNetworkIfStale()

        #expect(home.selectedMosque?.slug == "muslim-welfare-house")
        #expect(home.iqamahTimes?.isha == "20:15")
        #expect(home.displayedPrayerTimes != nil)
        #expect(home.loadState == .loaded)
    }

    @Test func cachedTabKeepsTheNavigatedMonthVisible() async throws {
        let fixture = try RefreshFixture(selected: "masjid-risalah")
        defer { fixture.cleanUp() }
        let home = fixture.makeHome()
        await home.load()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let future = try #require(calendar.date(byAdding: .month, value: 1, to: Date()))
        try fixture.seedMonth(for: future, isha: "21:00")
        home.goToDate(future)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while home.isLoadingDisplayedDate && ContinuousClock.now < deadline { await Task.yield() }
        try #require(!home.isLoadingDisplayedDate)
        try #require(home.iqamahTimes?.isha == "21:00")

        fixture.settings.activeMosqueTabId = "muslim-welfare-house"
        await home.applySelectionFromSettings(tabSwitch: true)

        #expect(home.iqamahTimes?.isha == "21:00")
        #expect(home.displayedPrayerTimes?.date == PrayerTimesEngine.isoDateString(
            year: calendar.component(.year, from: future),
            month: calendar.component(.month, from: future),
            day: calendar.component(.day, from: future)))
    }

    @Test func olderResponseCannotOverwriteANewerSelectionOfTheSameMosque() async throws {
        let fixture = try RefreshFixture(selected: "masjid-risalah")
        defer { fixture.backend.releaseHeldRequest(); fixture.cleanUp() }
        let home = fixture.makeHome()
        await home.load()
        fixture.backend.publishMWHS()
        fixture.backend.holdNextMWHSRequest = true
        fixture.settings.activeMosqueTabId = "muslim-welfare-house"
        let olderSelection = Task { await home.applySelectionFromSettings(tabSwitch: true) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while fixture.backend.heldRequest == nil && ContinuousClock.now < deadline { await Task.yield() }
        try #require(fixture.backend.heldRequest != nil)

        fixture.settings.activeMosqueTabId = "masjid-risalah"
        await home.applySelectionFromSettings(tabSwitch: true)
        fixture.backend.publishMWHS(isha: "19:00")
        fixture.settings.activeMosqueTabId = "muslim-welfare-house"
        await home.applySelectionFromSettings(tabSwitch: true)
        try #require(home.iqamahTimes?.isha == "19:00")

        fixture.backend.releaseHeldRequest()
        await olderSelection.value

        #expect(home.iqamahTimes?.isha == "19:00")
        #expect(fixture.cachedMWHS()?.iqamahTimes.first?.isha == "19:00")
        #expect(home.lastError == nil)
    }
}

@MainActor
private final class RefreshFixture {
    let backend = RefreshBackend()
    let settings: SettingsStore
    let cache: PrayerTimesDiskCache
    let root: URL
    let defaults: UserDefaults
    let suite: String
    let month: MonthName
    let year: Int

    init(selected: String = "muslim-welfare-house") throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        suite = "PrayerCacheRefresh.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
        settings = SettingsStore(defaults: defaults)
        settings.selectedMosqueId = selected
        settings.selectedMosqueSlug = selected
        settings.activeMosqueTabId = selected
        settings.openMosqueTabIds = backend.mosques.map(\.id)
        settings.hasCompletedOnboarding = true
        settings.notifications.masterEnabled = false
        let parts = PrayerTimesEngine.getDateInSheffield(Date())
        year = parts.year
        month = try #require(MonthName.from(monthNumber: parts.month))
        cache = PrayerTimesDiskCache(fileManager: RefreshFileManager(root: root))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("PrayerTimesCache"), withIntermediateDirectories: true)
        try seed("mosques.json", backend.mosques)
        try seedGlobalRevision()
        for mosque in backend.mosques {
            try seed("monthly_\(mosque.slug)_\(month.rawValue)_\(year).json", RefreshBackend.monthly(month, isha: "20:15"))
            try seed("versions_\(mosque.slug)_\(month.rawValue)_\(year).json", CachedPrayerDataVersions(versions: backend.versions(for: mosque.slug), checkedAt: Date()))
        }
    }

    func seedGlobalRevision() throws {
        try seed("data_revision.json", DataRevision(dataRevision: backend.revision, updatedAt: backend.revision))
    }

    func makeHome() -> HomeViewModel {
        HomeViewModel(repository: backend, settings: settings,
                      notificationScheduler: PrayerNotificationScheduler(repository: backend), diskCache: cache)
    }

    func cachedMWHS() -> MonthPrayerData? {
        cache.loadMonthly(slug: "muslim-welfare-house", month: month.rawValue, year: year)
    }

    func seedMonth(for date: Date, isha: String) throws {
        let parts = PrayerTimesEngine.getDateInSheffield(date)
        let targetMonth = try #require(MonthName.from(monthNumber: parts.month))
        backend.ishaByMonth[targetMonth.rawValue] = isha
        for mosque in backend.mosques {
            try seed("monthly_\(mosque.slug)_\(targetMonth.rawValue)_\(parts.year).json", RefreshBackend.monthly(targetMonth, isha: isha))
            try seed("versions_\(mosque.slug)_\(targetMonth.rawValue)_\(parts.year).json", CachedPrayerDataVersions(versions: backend.versions(for: mosque.slug), checkedAt: Date()))
        }
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    private func seed<T: Encodable>(_ filename: String, _ value: T) throws {
        let destination = root.appendingPathComponent("PrayerTimesCache").appendingPathComponent(filename)
        try JSONEncoder().encode(value).write(to: destination, options: .atomic)
    }
}

private final class RefreshFileManager: FileManager, @unchecked Sendable {
    let root: URL
    init(root: URL) { self.root = root; super.init() }
    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] { [root] }
}

@MainActor
private final class RefreshBackend: PrayerRepository {
    var revision: Double = 1
    var offline = false
    var monthlyRequests = 0
    var ishaByMonth: [String: String] = [:]
    var holdNextMWHSRequest = false
    var heldRequest: CheckedContinuation<Void, Never>?
    private var mwhsIsha = "20:15"
    let mosques = ["masjid-risalah", "muslim-welfare-house"].map {
        Mosque(id: $0, name: $0, address: "", lat: 53.38, lng: -1.47, slug: $0,
               citySlug: "sheffield", cityName: "Sheffield", countryCode: "gb", countryName: "United Kingdom",
               timezone: "Europe/London", website: nil, isHidden: false)
    }

    func publishMWHS(isha: String = "19:30") { revision += 1; mwhsIsha = isha }

    func releaseHeldRequest() {
        heldRequest?.resume()
        heldRequest = nil
    }

    func versions(for slug: String) -> PrayerDataVersions {
        PrayerDataVersions(mosquesUpdatedAt: 1, monthlyUpdatedAt: slug == "muslim-welfare-house" ? revision : 1,
                           ramadanUpdatedAt: 1, dstUpdatedAt: 1)
    }

    func listMosques() async throws -> [Mosque] {
        try requireOnline()
        return mosques
    }

    func getDataRevision() async throws -> DataRevision {
        try requireOnline()
        return DataRevision(dataRevision: revision, updatedAt: revision)
    }

    func getPrayerDataVersions(mosqueSlug: String, month: MonthName, year: Int) async throws -> PrayerDataVersions {
        try requireOnline()
        return versions(for: mosqueSlug)
    }

    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? {
        try requireOnline()
        monthlyRequests += 1
        let result = Self.monthly(month, isha: ishaByMonth[month.rawValue] ?? (mosqueSlug == "muslim-welfare-house" ? mwhsIsha : "20:15"))
        if mosqueSlug == "muslim-welfare-house" && holdNextMWHSRequest {
            holdNextMWHSRequest = false
            await withCheckedContinuation { heldRequest = $0 }
        }
        return result
    }

    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData? {
        try requireOnline()
        return nil
    }

    static func monthly(_ month: MonthName, isha: String) -> MonthPrayerData {
        MonthPrayerData(month: month.rawValue,
                        prayerTimes: (1...31).map { PrayerTime(date: $0, fajr: "05:04", shurooq: "06:50", dhuhr: "11:50", asr: "14:15", maghrib: "16:49", isha: "18:36") },
                        iqamahTimes: [IqamahTimeRange(dateRange: "1-31", fajr: "05:45", dhuhr: "13:10", asr: "14:30", maghrib: "16:49", isha: isha, jummah: "12:45")],
                        jummahIqamah: "12:45")
    }

    private func requireOnline() throws {
        if offline { throw URLError(.notConnectedToInternet) }
    }
}
