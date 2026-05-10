import Foundation

protocol PrayerRepository: AnyObject {
    func listMosques() async throws -> [Mosque]
    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData?
    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData?
    func getUkDstDates() async throws -> UkDstCalendar?
}

protocol SettingsPersisting: AnyObject {
    var selectedMosqueId: String? { get set }
    var selectedMosqueSlug: String? { get set }
    var uses24HourTime: Bool { get set }
    var notifications: NotificationSettings { get set }
    var appLanguage: AppLanguage { get set }
}

protocol PrayerNotificationScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        locale: Locale
    ) async throws
    func cancelAllPrayerNotifications() async
}
