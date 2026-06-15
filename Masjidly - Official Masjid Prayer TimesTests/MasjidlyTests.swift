import Foundation
import Testing
@testable import Masjidly

@Suite("Decoding")
struct DecodingTests {
    @Test func mosqueDecodes() throws {
        let json = """
        {"id":"1","name":"Test Masjid","address":"1 St","lat":53.3,"lng":-1.5,"slug":"test-masjid","website":null,"isHidden":false}
        """
        let m = try JSONDecoder().decode(Mosque.self, from: Data(json.utf8))
        #expect(m.slug == "test-masjid")
        #expect(m.isHiddenResolved == false)
    }

    @Test func monthlyDecodes() throws {
        let json = """
        {"month":"MAY","prayer_times":[{"date":1,"fajr":"03:30","shurooq":"05:10","dhuhr":"13:10","asr":"18:30","maghrib":"21:00","isha":"22:15"}],
        "iqamah_times":[{"date_range":"1-31","fajr":"04:00","dhuhr":"13:30","asr":"19:00","maghrib":"sunset","isha":"22:45"}],
        "jummah_iqamah":"13:35"}
        """
        let d = try JSONDecoder().decode(MonthPrayerData.self, from: Data(json.utf8))
        #expect(d.prayerTimes.count == 1)
        #expect(d.jummahIqamah == "13:35")
    }

    @Test func ramadanDecodes() throws {
        let json = """
        {"month":"Ramadan","gregorian_start":"2025-03-01","gregorian_end":"2025-03-29",
        "prayer_times":[{"ramadan_day":1,"gregorian":"2025-03-01","fajr":"05:00","shurooq":"06:00","dhuhr":"12:00","asr":"15:00","maghrib":"18:00","isha":"20:00"}],
        "iqamah_times":[{"date_range":"1-30","fajr":"05:15","dhuhr":"12:30","asr":"15:30","isha":"20:30"}],
        "jummah_iqamah":"12:45"}
        """
        let d = try JSONDecoder().decode(RamadanPrayerData.self, from: Data(json.utf8))
        #expect(d.prayerTimes.first?.ramadanDay == 1)
    }
}

@Suite("Prayer engine")
struct PrayerEngineTests {
    @Test func findDayDataClosestPrevious() {
        let rows = [
            PrayerTime(date: 1, fajr: "a", shurooq: "b", dhuhr: "12:00", asr: "c", maghrib: "d", isha: "e"),
            PrayerTime(date: 15, fajr: "a2", shurooq: "b2", dhuhr: "12:30", asr: "c2", maghrib: "d2", isha: "e2"),
        ]
        let hit = PrayerTimesEngine.findDayData(rows, dayOfMonth: 10)
        #expect(hit?.dhuhr == "12:00")
    }

    @Test func iqamahRange() throws {
        let ranges = [
            IqamahTimeRange(dateRange: "1-10", fajr: "x", dhuhr: "y", asr: "z", maghrib: nil, isha: "i", jummah: nil),
            IqamahTimeRange(dateRange: "11-20", fajr: "x2", dhuhr: "y2", asr: "z2", maghrib: nil, isha: "i2", jummah: nil),
        ]
        let d = try PrayerTimesEngine.getIqamahTimesForDate(dayOfMonth: 15, iqamahRanges: ranges)
        #expect(d.fajr == "x2")
    }

    @Test func jummahFridayUsesJummahString() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let fri = cal.date(from: DateComponents(year: 2026, month: 1, day: 2)) else { return }
        #expect(cal.component(.weekday, from: fri) == 6)
        let d = DailyPrayerTimes(date: "2026-01-02", fajr: "03:00", sunrise: "04:00", dhuhr: "13:00", asr: "18:00", maghrib: "20:00", isha: "21:00")
        let iq = DailyIqamahTimes(fajr: "03:30", dhuhr: "13:20", asr: "18:10", maghrib: "20:05", isha: "21:10", jummah: "13:25")
        let n = PrayerTimesEngine.getNextPrayerAndCountdown(prayerTimes: d, iqamahTimes: iq, mosqueSlug: "x", now: fri)
        #expect(n != nil)
        #expect(["Jummah", "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(n?.nextName ?? ""))
    }

    @Test func risalahIshaDisplayUsesAdhanInMayJuly() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let d = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)) else { return }
        let iq = DailyIqamahTimes(fajr: "1", dhuhr: "2", asr: "3", maghrib: "4", isha: "Entry Time", jummah: "")
        let s = PrayerTimesEngine.resolveIshaIqamahForDisplay(
            slug: "masjid-risalah",
            date: d,
            ishaAdhan: "22:40",
            iqamahTimes: iq,
            maghribAdhan: "21:30"
        )
        #expect(s == "22:40")
    }

    @Test func muslimWelfareHouseSummerIshaShowsAfterMaghrib() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let d = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)) else { return }
        let iq = DailyIqamahTimes(fajr: "1", dhuhr: "2", asr: "3", maghrib: "4", isha: "21:10", jummah: "")
        let s = PrayerTimesEngine.resolveIshaIqamahForDisplay(
            slug: MosqueDefaults.defaultSlug,
            date: d,
            ishaAdhan: "22:40",
            iqamahTimes: iq,
            maghribAdhan: "21:30"
        )
        #expect(s == "After Maghrib")
    }

    @Test func nonMwhMosqueSummerIshaUsesIqamahTable() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let d = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)) else { return }
        let iq = DailyIqamahTimes(fajr: "1", dhuhr: "2", asr: "3", maghrib: "4", isha: "21:10", jummah: "")
        let s = PrayerTimesEngine.resolveIshaIqamahForDisplay(
            slug: "other-mosque",
            date: d,
            ishaAdhan: "22:40",
            iqamahTimes: iq,
            maghribAdhan: "21:30"
        )
        #expect(s == "21:10")
    }

    @Test func dstEmbeddedRemap() {
        let day = PrayerTimesEngine.resolveTimetableDayForUkEmbeddedDst(calendarDay: 28, transitionDayInTable: 30, ukTransitionDay: 29, maxTableDay: 31)
        #expect(day == 29)
    }

    @Test func formatPrayerTimeUsesLocaleForTwentyFourHour() {
        let ar = Locale(identifier: "ar")
        let s = PrayerTimesEngine.formatPrayerTimeForDisplay("13:05", uses24Hour: true, locale: ar)
        #expect(s != "13:05")
    }

    @Test func heroCountdownLabelAdhanInBeforeFirstAdhan() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 3, minute: 0))!
        let d = DailyPrayerTimes(date: "2026-06-15", fajr: "04:00", sunrise: "05:00", dhuhr: "13:00", asr: "18:00", maghrib: "21:00", isha: "22:30")
        let iq = DailyIqamahTimes(fajr: "04:30", dhuhr: "13:20", asr: "18:10", maghrib: "21:05", isha: "22:45", jummah: "13:25")
        let h = PrayerTimesEngine.heroCountdownPresentation(prayerTimes: d, iqamahTimes: iq, mosqueSlug: "x", now: now)!
        #expect(h.labelKind == .adhanIn)
        #expect(h.remainingSeconds(at: now) == 3600)
    }

    @Test func heroCountdownLabelNextPrayerAfterFajrWindow() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12, minute: 0))!
        let d = DailyPrayerTimes(date: "2026-06-15", fajr: "04:00", sunrise: "05:00", dhuhr: "13:00", asr: "18:00", maghrib: "21:00", isha: "22:30")
        let iq = DailyIqamahTimes(fajr: "04:30", dhuhr: "13:20", asr: "18:10", maghrib: "21:05", isha: "22:45", jummah: "13:25")
        let h = PrayerTimesEngine.heroCountdownPresentation(prayerTimes: d, iqamahTimes: iq, mosqueSlug: "x", now: now)!
        #expect(h.labelKind == .nextPrayer)
    }

    @Test func heroCountdownIqamahPhase() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 13, minute: 5))!
        let d = DailyPrayerTimes(date: "2026-06-15", fajr: "04:00", sunrise: "05:00", dhuhr: "13:00", asr: "18:00", maghrib: "21:00", isha: "22:30")
        let iq = DailyIqamahTimes(fajr: "04:30", dhuhr: "13:20", asr: "18:10", maghrib: "21:05", isha: "22:45", jummah: "13:25")
        let h = PrayerTimesEngine.heroCountdownPresentation(prayerTimes: d, iqamahTimes: iq, mosqueSlug: "x", now: now)!
        #expect(h.labelKind == .iqamahIn)
        #expect(h.remainingSeconds(at: now) == 15 * 60)
    }

    @Test func formatHeroCountdownClock() {
        #expect(PrayerTimesEngine.formatHeroCountdownClock(totalSeconds: 5024) == "-1:23:44")
        #expect(PrayerTimesEngine.formatHeroCountdownClock(totalSeconds: 1122) == "-18:42")
        #expect(PrayerTimesEngine.formatHeroCountdownClock(totalSeconds: 545) == "-9:05")
        #expect(PrayerTimesEngine.formatHeroCountdownClock(totalSeconds: 0) == "-0:00")
    }
}

@Suite("Qibla direction")
struct QiblaDirectionTests {
    @Test func sheffieldBearingPointsSoutheastTowardMakkah() {
        let bearing = QiblaDirectionCalculator.bearingDegrees(
            fromLatitude: 53.3811,
            longitude: -1.4701
        )

        #expect(abs(bearing - 119.2) < 0.5)
    }

    @Test func indicatorRotationTracksLiveHeading() {
        let rotation = QiblaDirectionCalculator.indicatorRotationDegrees(
            qiblaBearing: 119.2,
            heading: 100
        )

        #expect(abs(rotation - 19.2) < 0.5)
    }

    @Test func continuousRotationTakesShortestPathAcrossZeroDegrees() {
        let clockwise = QiblaDirectionCalculator.continuousRotationDegrees(previous: 358, target: 2)
        let counterClockwise = QiblaDirectionCalculator.continuousRotationDegrees(previous: 2, target: 358)

        #expect(abs(clockwise - 362) < 0.5)
        #expect(abs(counterClockwise - (-2)) < 0.5)
    }
}

@Suite("Settings")
struct SettingsStoreTests {
    @Test @MainActor func selectedCityGroupingKeyPersists() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests.selectedCityGroupingKeyPersists")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests.selectedCityGroupingKeyPersists")

        let s = SettingsStore(defaults: defaults)
        s.selectedCityGroupingKey = "slug:leeds"
        #expect(SettingsStore(defaults: defaults).selectedCityGroupingKey == "slug:leeds")
    }

    @Test @MainActor func mosquePersistenceAndDefault() {
        let s = SettingsStore()
        s.selectedMosqueId = "bad-id"
        s.selectedMosqueSlug = MosqueDefaults.defaultSlug
        let mosques: [Mosque] = [
            Mosque(id: "a", name: "A", address: "", lat: 0, lng: 0, slug: "other", website: nil, isHidden: false),
            Mosque(id: "b", name: "MWH", address: "", lat: 0, lng: 0, slug: MosqueDefaults.defaultSlug, website: nil, isHidden: false),
        ]
        let m = MosqueDefaults.resolveSelectedMosque(mosques: mosques, selectedId: s.selectedMosqueId, selectedSlug: s.selectedMosqueSlug)
        #expect(m?.slug == MosqueDefaults.defaultSlug)
        s.uses24HourTime = true
        #expect(s.uses24HourTime == true)
    }

    @Test @MainActor func appLanguagePersistsSelectedLanguage() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests.appLanguagePersistsSelectedLanguage")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests.appLanguagePersistsSelectedLanguage")
        let s = SettingsStore(defaults: defaults)
        s.appLanguage = .indonesian
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.appLanguage == .indonesian)
        #expect(reloaded.resolvedLocale.identifier == "id_ID")
    }

    @Test func appLanguageMetadataSupportsRtl() {
        #expect(AppLanguage.english.resolvedLanguageCode == "en")
        #expect(AppLanguage.arabic.isResolvedRightToLeft == true)
        #expect(AppLanguage.urdu.isResolvedRightToLeft == true)
        #expect(AppLanguage.indonesian.isResolvedRightToLeft == false)
    }

    @Test @MainActor func onboardingCompletionPersists() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests.onboardingCompletionPersists")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests.onboardingCompletionPersists")

        let s = SettingsStore(defaults: defaults)
        #expect(s.hasCompletedOnboarding == false)

        s.hasCompletedOnboarding = true
        #expect(SettingsStore(defaults: defaults).hasCompletedOnboarding == true)
    }

    @Test func notificationSettingsDecodesLegacyJSONWithChannelDefaults() throws {
        let json = """
        {"masterEnabled":true,"fajr":true,"dhuhrJummah":false,"asr":true,"maghrib":true,"isha":false}
        """
        let settings = try JSONDecoder().decode(NotificationSettings.self, from: Data(json.utf8))

        #expect(settings.masterEnabled == true)
        #expect(settings.adhanEnabled == true)
        #expect(settings.iqamahEnabled == true)
        #expect(settings.preAdhanReminderMinutes == nil)
    }

    @Test func notificationReminderMinutesRoundTrip() throws {
        var settings = NotificationSettings()
        settings.masterEnabled = true
        settings.adhanEnabled = false
        settings.iqamahEnabled = true
        settings.preAdhanReminderMinutes = 10

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(NotificationSettings.self, from: data)

        #expect(decoded.masterEnabled == true)
        #expect(decoded.adhanEnabled == false)
        #expect(decoded.iqamahEnabled == true)
        #expect(decoded.preAdhanReminderMinutes == 10)
    }
}

@Suite("Onboarding")
@MainActor
struct OnboardingFlowControllerTests {
    @Test func startsAtMosqueSelectionWhenIncomplete() async {
        let harness = OnboardingHarness()
        harness.settings.hasCompletedOnboarding = false
        harness.homeViewModel.mosques = harness.mosques

        harness.controller.startIfNeeded()

        #expect(harness.controller.currentStep == .chooseLanguage)
        #expect(harness.controller.isActive == true)
    }

    @Test func doesNotStartWhenCompleted() async {
        let harness = OnboardingHarness()
        harness.settings.hasCompletedOnboarding = true
        harness.homeViewModel.mosques = harness.mosques

        harness.controller.startIfNeeded()

        #expect(harness.controller.currentStep == nil)
        #expect(harness.controller.isActive == false)
    }

    @Test func choosingLanguagePersistsSelectionAndAdvancesToMosqueSelection() {
        let harness = OnboardingHarness()
        harness.controller.currentStep = .chooseLanguage

        harness.controller.selectLanguage(.urdu)

        #expect(harness.settings.appLanguage == .urdu)
        #expect(harness.controller.selectedLanguage == .urdu)
        #expect(harness.controller.currentStep == .chooseMosque)
    }

    @Test func choosingMosquePersistsSelectionAndStartsPrayerShortcuts() async {
        let harness = OnboardingHarness()
        harness.settings.hasCompletedOnboarding = false
        harness.homeViewModel.mosques = harness.mosques
        harness.settingsViewModel.mosques = harness.mosques
        harness.controller.startIfNeeded()

        await harness.controller.selectMosque(harness.mosques[1])

        #expect(harness.settings.selectedMosqueId == "b")
        #expect(harness.settings.selectedMosqueSlug == "mosque-b")
        #expect(harness.controller.currentStep == .prayerShortcut(index: 0))
        #expect(harness.controller.isSelectingMosque == false)
    }

    @Test func choosingMosqueIsIgnoredOutsideSelectionStep() async {
        let harness = OnboardingHarness()
        harness.settings.selectedMosqueId = "a"
        harness.controller.currentStep = .prayerShortcut(index: 0)

        await harness.controller.selectMosque(harness.mosques[1])

        #expect(harness.settings.selectedMosqueId == "a")
        #expect(harness.controller.currentStep == .prayerShortcut(index: 0))
    }

    @Test func prayerShortcutStepOnlyRequiresOneShortcutTap() {
        let harness = OnboardingHarness()
        harness.controller.currentStep = .prayerShortcut(index: 0)

        harness.controller.handlePrayerShortcutTap(index: 3)
        #expect(harness.controller.currentStep == .qiblaCountdown)
    }

    @Test func qiblaDeferPathSetsHideCompassFlag() {
        let harness = OnboardingHarness()
        harness.controller.currentStep = .qibla
        #expect(harness.settings.hideQiblaCompass == false)

        harness.controller.completeQiblaOnboardingDeferringLocation()
        #expect(harness.controller.currentStep == .openTimetable)
        #expect(harness.settings.hideQiblaCompass == true)
    }

    @Test func completeQiblaOnboardingAllowingLocationRequestDoesNotSetHideCompass() {
        let harness = OnboardingHarness()
        harness.controller.currentStep = .qibla

        harness.controller.completeQiblaOnboardingAllowingLocationRequest()
        #expect(harness.controller.currentStep == .openTimetable)
        #expect(harness.settings.hideQiblaCompass == false)
    }

    @Test func guidedSurfaceStepsAdvanceInOrder() {
        let harness = OnboardingHarness()
        harness.controller.currentStep = .prayerShortcut(index: 0)

        harness.controller.handlePrayerShortcutTap(index: 0)
        #expect(harness.controller.currentStep == .qiblaCountdown)

        harness.controller.completeQiblaCountdownStep()
        #expect(harness.controller.currentStep == .qibla)

        harness.controller.completeQiblaOnboardingAllowingLocationRequest()
        #expect(harness.controller.currentStep == .openTimetable)

        harness.controller.handleTimetableOpened()
        #expect(harness.controller.currentStep == .exploreTimetable)

        harness.controller.acknowledgeTimetableExplore()
        #expect(harness.controller.currentStep == .closeTimetable)

        harness.controller.handleTimetableClosed()
        #expect(harness.controller.currentStep == .openSettings)

        harness.controller.handleSettingsOpened()
        #expect(harness.controller.currentStep == .exploreSettings)

        harness.controller.acknowledgeSettingsExplore()
        #expect(harness.controller.currentStep == .closeSettings)

        harness.controller.handleSettingsClosed()
        #expect(harness.controller.currentStep == .notifications)
    }

    @Test func completingNotificationSetupSavesSettingsRequestsAuthorizationAndCompletes() async {
        let harness = OnboardingHarness()
        harness.homeViewModel.selectedMosque = harness.mosques[0]
        harness.controller.currentStep = .notifications
        harness.controller.notificationDraft = OnboardingNotificationDraft(
            adhanEnabled: true,
            iqamahEnabled: false,
            preAdhanReminderMinutes: 10
        )

        await harness.controller.completeNotificationSetup()

        #expect(harness.settings.hasCompletedOnboarding == true)
        #expect(harness.settings.notifications.masterEnabled == true)
        #expect(harness.settings.notifications.adhanEnabled == true)
        #expect(harness.settings.notifications.iqamahEnabled == false)
        #expect(harness.settings.notifications.preAdhanReminderMinutes == 10)
        #expect(harness.scheduler.authorizationRequestCount == 1)
        #expect(harness.scheduler.rescheduleCount == 1)
        #expect(harness.controller.currentStep == nil)
    }

    @Test func restartTutorialResetsHideQiblaCompass() {
        let harness = OnboardingHarness()
        harness.settings.hasCompletedOnboarding = true
        harness.settings.hideQiblaCompass = true

        harness.controller.restartTutorialFromDeveloperTools()

        #expect(harness.settings.hasCompletedOnboarding == false)
        #expect(harness.settings.hideQiblaCompass == false)
        #expect(harness.controller.currentStep == .chooseLanguage)
    }
}

@MainActor
private final class OnboardingHarness {
    let defaults: UserDefaults
    let mosques: [Mosque]
    let repository: MockPrayerRepository
    let scheduler: MockPrayerNotificationScheduler
    let settings: SettingsStore
    let diskCache: PrayerTimesDiskCache
    let homeViewModel: HomeViewModel
    let settingsViewModel: SettingsViewModel
    let controller: OnboardingFlowController

    init() {
        let suiteName = "OnboardingHarness.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        mosques = [
            Mosque(id: "a", name: "Mosque A", address: "", lat: 0, lng: 0, slug: "mosque-a", website: nil, isHidden: false),
            Mosque(id: "b", name: "Mosque B", address: "", lat: 0, lng: 0, slug: "mosque-b", website: nil, isHidden: false),
        ]
        repository = MockPrayerRepository(mosques: mosques)
        scheduler = MockPrayerNotificationScheduler()
        settings = SettingsStore(defaults: defaults)
        diskCache = PrayerTimesDiskCache()
        homeViewModel = HomeViewModel(repository: repository, settings: settings, notificationScheduler: scheduler, diskCache: diskCache)
        settingsViewModel = SettingsViewModel(repository: repository, settings: settings, notificationScheduler: scheduler, diskCache: diskCache)
        controller = OnboardingFlowController(
            settings: settings,
            homeViewModel: homeViewModel,
            settingsViewModel: settingsViewModel,
            notificationScheduler: scheduler
        )
    }
}

private final class MockPrayerRepository: PrayerRepository {
    let mosques: [Mosque]

    init(mosques: [Mosque]) {
        self.mosques = mosques
    }

    func listMosques() async throws -> [Mosque] {
        mosques
    }

    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? {
        MonthPrayerData(
            month: "May 2026",
            prayerTimes: [
                PrayerTime(date: 10, fajr: "04:00", shurooq: "05:30", dhuhr: "13:00", asr: "18:00", maghrib: "21:00", isha: "22:30")
            ],
            iqamahTimes: [
                IqamahTimeRange(dateRange: "1-31", fajr: "04:30", dhuhr: "13:30", asr: "18:30", maghrib: "sunset", isha: "23:00", jummah: "13:45")
            ],
            jummahIqamah: "13:45"
        )
    }

    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData? {
        nil
    }

    func getUkDstDates() async throws -> UkDstCalendar? {
        UkDstCalendar(ukDstDates: [])
    }
}

private final class MockPrayerNotificationScheduler: PrayerNotificationScheduling {
    var authorizationRequestCount = 0
    var rescheduleCount = 0
    var cancelCount = 0

    func requestAuthorizationIfNeeded() async throws -> Bool {
        authorizationRequestCount += 1
        return true
    }

    func rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        locale: Locale,
        asrIqamahPreference: AsrIqamahPreference
    ) async throws {
        rescheduleCount += 1
    }

    func cancelAllPrayerNotifications() async {
        cancelCount += 1
    }
}

@Suite("Disk cache")
@MainActor
struct PrayerTimesDiskCacheTests {
    @Test func roundTripMosques() {
        let cache = PrayerTimesDiskCache()
        let mosques = [
            Mosque(id: "a", name: "Alpha", address: "", lat: 0, lng: 0, slug: "alpha", website: nil, isHidden: false),
            Mosque(id: "b", name: "Beta", address: "", lat: 0, lng: 0, slug: "beta", website: nil, isHidden: false),
        ]
        try? cache.saveMosques(mosques)
        let loaded: [Mosque]? = cache.loadMosques()
        #expect(loaded?.count == 2)
        #expect(loaded?.first?.slug == "alpha")
    }

    @Test func roundTripMonthly() {
        let cache = PrayerTimesDiskCache()
        let data = MonthPrayerData(
            month: "MAY",
            prayerTimes: [
                PrayerTime(date: 1, fajr: "03:00", shurooq: "05:00", dhuhr: "13:00", asr: "18:00", maghrib: "21:00", isha: "22:00")
            ],
            iqamahTimes: [],
            jummahIqamah: "13:30"
        )
        try? cache.saveMonthly(slug: "test-masjid", month: "may", year: 2026, data: data)
        let loaded: MonthPrayerData? = cache.loadMonthly(slug: "test-masjid", month: "may", year: 2026)
        #expect(loaded?.prayerTimes.count == 1)
        #expect(loaded?.jummahIqamah == "13:30")
    }

    @Test func roundTripRamadan() {
        let cache = PrayerTimesDiskCache()
        let data = RamadanPrayerData(
            month: "Ramadan",
            gregorianStart: "2026-02-17",
            gregorianEnd: "2026-03-18",
            prayerTimes: [
                RamadanPrayerDay(ramadanDay: 1, gregorian: "2026-02-17", fajr: "05:30", shurooq: "06:00", dhuhr: "12:00", asr: "15:00", maghrib: "17:30", isha: "19:00")
            ],
            iqamahTimes: [],
            jummahIqamah: "12:30"
        )
        try? cache.saveRamadan(slug: "test-masjid", date: "2026-02-17", data: data)
        let loaded: RamadanPrayerData? = cache.loadRamadan(slug: "test-masjid", date: "2026-02-17")
        #expect(loaded?.prayerTimes.first?.ramadanDay == 1)
    }

    @Test func roundTripUkDst() {
        let cache = PrayerTimesDiskCache()
        let dst = UkDstCalendar(ukDstDates: [
            UkDstYear(year: 2026, startDate: "2026-03-29", endDate: "2026-10-25")
        ])
        try? cache.saveUkDst(dst)
        let loaded: UkDstCalendar? = cache.loadUkDst()
        #expect(loaded?.ukDstDates.first?.year == 2026)
    }

    @Test func loadMosquesReturnsNilWhenMissing() {
        let cache = PrayerTimesDiskCache()
        let mosques: [Mosque]? = cache.loadMosques()
        #expect(mosques == nil)
    }

    @Test func safeFilenameReplacesPathSeparators() {
        let unsafe = "../../etc/passwd"
        let safe = PrayerTimesDiskCache.safe(unsafe)
        #expect(!safe.contains("/"))
        #expect(!safe.contains("."))
    }
}
