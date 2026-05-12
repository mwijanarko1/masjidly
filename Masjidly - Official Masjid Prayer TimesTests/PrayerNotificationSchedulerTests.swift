import Foundation
import Testing
import UserNotifications
@testable import Masjidly

@Suite("Prayer notification scheduler")
@MainActor
struct PrayerNotificationSchedulerTests {
    @Test func authorizationUsesExistingGrantedNotificationStates() async throws {
        let mosque = Mosque(
            id: "mosque-a",
            name: "Mosque A",
            address: "",
            lat: 0,
            lng: 0,
            slug: "mosque-a",
            website: nil,
            isHidden: false
        )
        let repository = SchedulerPrayerRepository(mosque: mosque)
        let center = RecordingPrayerNotificationCenter()
        center.authorizationStatus = .provisional
        let scheduler = PrayerNotificationScheduler(repository: repository, center: center)

        let granted = try await scheduler.requestAuthorizationIfNeeded()

        #expect(granted == true)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test func authorizationDoesNotRePromptAfterDenial() async throws {
        let mosque = Mosque(
            id: "mosque-a",
            name: "Mosque A",
            address: "",
            lat: 0,
            lng: 0,
            slug: "mosque-a",
            website: nil,
            isHidden: false
        )
        let repository = SchedulerPrayerRepository(mosque: mosque)
        let center = RecordingPrayerNotificationCenter()
        center.authorizationStatus = .denied
        let scheduler = PrayerNotificationScheduler(repository: repository, center: center)

        let granted = try await scheduler.requestAuthorizationIfNeeded()

        #expect(granted == false)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test func schedulesAdhanIqamahAndReminderRequests() async throws {
        let mosque = Mosque(
            id: "mosque-a",
            name: "Mosque A",
            address: "",
            lat: 0,
            lng: 0,
            slug: "mosque-a",
            website: nil,
            isHidden: false
        )
        let repository = SchedulerPrayerRepository(mosque: mosque)
        let center = RecordingPrayerNotificationCenter()
        let scheduler = PrayerNotificationScheduler(repository: repository, center: center)
        let settings = NotificationSettings(
            masterEnabled: true,
            adhanEnabled: true,
            iqamahEnabled: true,
            preAdhanReminderMinutes: 5,
            preIqamahReminderMinutes: 5
        )

        try await scheduler.rescheduleUpcomingPrayerNotifications(
            mosque: mosque,
            days: 2,
            settings: settings,
            locale: Locale(identifier: "en_GB")
        )

        let identifiers = center.addedRequests.map(\.identifier)
        #expect(identifiers.contains { $0.hasSuffix(".fajr.adhan") })
        #expect(identifiers.contains { $0.hasSuffix(".fajr.iqamah") })
        #expect(identifiers.contains { $0.hasSuffix(".fajr.adhan_reminder") })
        #expect(identifiers.contains { $0.hasSuffix(".fajr.iqamah_reminder") })
        #expect(center.removedIdentifiers == ["masjidly.prayer.old.fajr.adhan"])
    }

    @Test func pendingPrayerRequestsIncludeOnlyMasjidlyPrefixSortedByFireDate() async throws {
        let mosque = Mosque(
            id: "mosque-a",
            name: "Mosque A",
            address: "",
            lat: 0,
            lng: 0,
            slug: "mosque-a",
            website: nil,
            isHidden: false
        )
        let repository = SchedulerPrayerRepository(mosque: mosque)
        let center = RecordingPrayerNotificationCenter()
        let scheduler = PrayerNotificationScheduler(repository: repository, center: center)
        let settings = NotificationSettings(
            masterEnabled: true,
            adhanEnabled: true,
            iqamahEnabled: false,
            preAdhanReminderMinutes: nil,
            preIqamahReminderMinutes: nil
        )

        try await scheduler.rescheduleUpcomingPrayerNotifications(
            mosque: mosque,
            days: 1,
            settings: settings,
            locale: Locale(identifier: "en_GB")
        )

        let pending = await center.pendingPrayerNotificationRequests()
        let prayer = pending.filter { $0.identifier.hasPrefix("masjidly.prayer.") }
        #expect(prayer.allSatisfy { $0.identifier.hasPrefix("masjidly.prayer.") })
        #expect(prayer.contains { $0.identifier.hasSuffix(".fajr.adhan") })
        let dated = prayer.compactMap { SchedulerTestTriggerDates.nextFireDate(for: $0.trigger) }
        #expect(dated == dated.sorted())
    }
}

private enum SchedulerTestTriggerDates {
    static func nextFireDate(for trigger: UNNotificationTrigger?) -> Date? {
        guard let trigger else { return nil }
        if let cal = trigger as? UNCalendarNotificationTrigger {
            return cal.nextTriggerDate()
        }
        if let interval = trigger as? UNTimeIntervalNotificationTrigger {
            return interval.nextTriggerDate()
        }
        return nil
    }
}

private final class RecordingPrayerNotificationCenter: PrayerNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var authorizationRequestCount = 0
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    /// Mirrors pending queue: pre-seeded stale prayer id + unrelated (see `schedulesAdhanIqamahAndReminderRequests`).
    private var storedPending: [UNNotificationRequest] = [
        UNNotificationRequest(
            identifier: "masjidly.prayer.old.fajr.adhan",
            content: UNMutableNotificationContent(),
            trigger: nil
        ),
        UNNotificationRequest(
            identifier: "unrelated.notification",
            content: UNMutableNotificationContent(),
            trigger: nil
        ),
    ]

    func prayerNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }

    func requestPrayerNotificationAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return true
    }

    func pendingPrayerNotificationRequests() async -> [UNNotificationRequest] {
        storedPending
    }

    func removePendingPrayerNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        let idSet = Set(identifiers)
        storedPending.removeAll { idSet.contains($0.identifier) }
    }

    func addPrayerNotificationRequest(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        storedPending.append(request)
    }
}

private final class SchedulerPrayerRepository: PrayerRepository {
    private let mosque: Mosque

    init(mosque: Mosque) {
        self.mosque = mosque
    }

    func listMosques() async throws -> [Mosque] {
        [mosque]
    }

    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? {
        MonthPrayerData(
            month: month.rawValue,
            prayerTimes: (1...31).map {
                PrayerTime(
                    date: $0,
                    fajr: "23:59",
                    shurooq: "23:59",
                    dhuhr: "23:59",
                    asr: "23:59",
                    maghrib: "23:59",
                    isha: "23:59"
                )
            },
            iqamahTimes: [
                IqamahTimeRange(
                    dateRange: "1-31",
                    fajr: "23:59",
                    dhuhr: "23:59",
                    asr: "23:59",
                    maghrib: "23:59",
                    isha: "23:59",
                    jummah: "23:59"
                )
            ],
            jummahIqamah: "23:59"
        )
    }

    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData? {
        nil
    }

    func getUkDstDates() async throws -> UkDstCalendar? {
        UkDstCalendar(ukDstDates: [])
    }
}
