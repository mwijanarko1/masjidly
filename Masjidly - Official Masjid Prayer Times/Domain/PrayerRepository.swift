import Foundation

protocol PrayerRepository: AnyObject {
    func listMosques() async throws -> [Mosque]
    func getDataRevision() async throws -> DataRevision
    func getPrayerDataVersions(mosqueSlug: String, month: MonthName, year: Int) async throws -> PrayerDataVersions
    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData?
    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData?
    func getUkDstDates() async throws -> UkDstCalendar?
}

extension PrayerRepository {
    func getDataRevision() async throws -> DataRevision {
        DataRevision(dataRevision: 0, updatedAt: 0)
    }

    func getPrayerDataVersions(mosqueSlug: String, month: MonthName, year: Int) async throws -> PrayerDataVersions {
        PrayerDataVersions(mosquesUpdatedAt: 0, monthlyUpdatedAt: 0, ramadanUpdatedAt: 0, dstUpdatedAt: 0)
    }
}

protocol SettingsPersisting: AnyObject {
    var selectedMosqueId: String? { get set }
    var selectedMosqueSlug: String? { get set }
    var uses24HourTime: Bool { get set }
    var notifications: NotificationSettings { get set }
    var appLanguage: AppLanguage { get set }
    var hasCompletedOnboarding: Bool { get set }
}

protocol PrayerNotificationScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        locale: Locale,
        asrIqamahPreference: AsrIqamahPreference
    ) async throws
    func cancelAllPrayerNotifications() async
}
