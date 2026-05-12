import Foundation
import UserNotifications

protocol PrayerNotificationCenter: AnyObject {
    func prayerNotificationAuthorizationStatus() async -> UNAuthorizationStatus
    func requestPrayerNotificationAuthorization() async throws -> Bool
    func pendingPrayerNotificationRequests() async -> [UNNotificationRequest]
    func removePendingPrayerNotificationRequests(withIdentifiers identifiers: [String])
    func addPrayerNotificationRequest(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: PrayerNotificationCenter {
    func prayerNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func requestPrayerNotificationAuthorization() async throws -> Bool {
        try await requestAuthorization(options: [.alert, .sound])
    }

    func pendingPrayerNotificationRequests() async -> [UNNotificationRequest] {
        await pendingNotificationRequests()
    }

    func removePendingPrayerNotificationRequests(withIdentifiers identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func addPrayerNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await add(request)
    }
}

final class PrayerNotificationScheduler: PrayerNotificationScheduling {
    private let repository: any PrayerRepository
    private let center: any PrayerNotificationCenter
    /// iOS keeps at most 64 pending local notifications; stop submitting beyond that in deterministic loop order.
    private var prayerNotificationAddBudget: Int = 0

    init(repository: any PrayerRepository, center: any PrayerNotificationCenter = UNUserNotificationCenter.current()) {
        self.repository = repository
        self.center = center
    }

    func requestAuthorizationIfNeeded() async throws -> Bool {
        let authorizationStatus = await center.prayerNotificationAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestPrayerNotificationAuthorization()
        @unknown default:
            return false
        }
    }

    func cancelAllPrayerNotifications() async {
        let pending = await center.pendingPrayerNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("masjidly.prayer.") }
        center.removePendingPrayerNotificationRequests(withIdentifiers: ids)
    }

    func rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        locale: Locale
    ) async throws {
        await cancelAllPrayerNotifications()
        guard settings.masterEnabled else { return }
        let granted = try await requestAuthorizationIfNeeded()
        guard granted else { return }

        prayerNotificationAddBudget = 64

        let ukDst = (try? await repository.getUkDstDates())?.ukDstDates ?? []
        let slug = mosque.slug
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let baseDay = cal.startOfDay(for: Date())

        for offset in 0..<max(1, days) {
            guard let dayDate = cal.date(byAdding: .day, value: offset, to: baseDay) else { continue }
            let comps = PrayerTimesEngine.getDateInSheffield(dayDate)
            let iso = PrayerTimesEngine.isoDateString(year: comps.year, month: comps.month, day: comps.day)
            guard let monthName = MonthName.from(monthNumber: comps.month) else { continue }

            let monthly = try await repository.getMonthlyPrayerTimes(mosqueSlug: slug, month: monthName, year: comps.year)
            let ramadan = try await repository.getRamadanTimetable(mosqueSlug: slug, date: iso)

            let displayed: DailyPrayerTimes
            let iq: DailyIqamahTimes
            do {
                let raw = try PrayerTimesEngine.resolvePrayerTimes(slug: slug, on: dayDate, monthly: monthly, ramadan: ramadan, ukDst: ukDst)
                displayed = PrayerTimesEngine.getDisplayedPrayerTimes(raw, date: dayDate, mosqueSlug: slug)
                iq = try PrayerTimesEngine.resolveIqamahTimesWithDstMapping(slug: slug, on: dayDate, monthly: monthly, ramadan: ramadan, ukDst: ukDst)
            } catch {
                continue
            }

            let weekday = cal.component(.weekday, from: dayDate)
            let isFriday = weekday == 6

            try await scheduleAdhanIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).fajr.adhan",
                reminderId: "masjidly.prayer.\(slug).\(iso).fajr.adhan_reminder",
                prayerKey: "fajr",
                time: displayed.fajr,
                isFriday: isFriday,
                civilDay: dayDate,
            )
            let fajrIq = PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: displayed.fajr, iqamahTimes: iq)
            try await scheduleIqamahIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).fajr.iqamah",
                reminderId: "masjidly.prayer.\(slug).\(iso).fajr.iqamah_reminder",
                prayerKey: "fajr",
                time: fajrIq,
                isFriday: isFriday,
                civilDay: dayDate,
            )

            let dhuhrTime = displayed.dhuhr
            try await scheduleAdhanIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).dhuhr.adhan",
                reminderId: "masjidly.prayer.\(slug).\(iso).dhuhr.adhan_reminder",
                prayerKey: "dhuhr",
                time: dhuhrTime,
                isFriday: isFriday,
                civilDay: dayDate,
            )
            let iqLabel = isFriday ? iq.jummah : PrayerTimesEngine.getIqamahTime(prayer: "dhuhr", adhanTime: dhuhrTime, iqamahTimes: iq)
            try await scheduleIqamahIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).\(isFriday ? "jummah" : "dhuhr").iqamah",
                reminderId: "masjidly.prayer.\(slug).\(iso).\(isFriday ? "jummah" : "dhuhr").iqamah_reminder",
                prayerKey: "dhuhr",
                time: iqLabel,
                isFriday: isFriday,
                civilDay: dayDate,
            )

            try await scheduleAdhanIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).asr.adhan",
                reminderId: "masjidly.prayer.\(slug).\(iso).asr.adhan_reminder",
                prayerKey: "asr",
                time: displayed.asr,
                isFriday: isFriday,
                civilDay: dayDate,
            )
            let asrIq = PrayerTimesEngine.getIqamahTime(prayer: "asr", adhanTime: displayed.asr, iqamahTimes: iq)
            try await scheduleIqamahIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).asr.iqamah",
                reminderId: "masjidly.prayer.\(slug).\(iso).asr.iqamah_reminder",
                prayerKey: "asr",
                time: asrIq,
                isFriday: isFriday,
                civilDay: dayDate,
            )

            try await scheduleAdhanIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).maghrib.adhan",
                reminderId: "masjidly.prayer.\(slug).\(iso).maghrib.adhan_reminder",
                prayerKey: "maghrib",
                time: displayed.maghrib,
                isFriday: isFriday,
                civilDay: dayDate,
            )
            let maghribIq = PrayerTimesEngine.getIqamahTime(prayer: "maghrib", adhanTime: displayed.maghrib, iqamahTimes: iq)
            try await scheduleIqamahIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).maghrib.iqamah",
                reminderId: "masjidly.prayer.\(slug).\(iso).maghrib.iqamah_reminder",
                prayerKey: "maghrib",
                time: maghribIq,
                isFriday: isFriday,
                civilDay: dayDate,
            )

            try await scheduleAdhanIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).isha.adhan",
                reminderId: "masjidly.prayer.\(slug).\(iso).isha.adhan_reminder",
                prayerKey: "isha",
                time: displayed.isha,
                isFriday: isFriday,
                civilDay: dayDate,
            )
            let ishaIq = PrayerTimesEngine.resolveIshaIqamahForDisplay(
                slug: slug,
                date: cal.startOfDay(for: dayDate),
                ishaAdhan: displayed.isha,
                iqamahTimes: iq,
                maghribAdhan: displayed.maghrib
            )
            try await scheduleIqamahIfEnabled(
                settings: settings,
                mosqueSlug: slug,
                iso: iso,
                id: "masjidly.prayer.\(slug).\(iso).isha.iqamah",
                reminderId: "masjidly.prayer.\(slug).\(iso).isha.iqamah_reminder",
                prayerKey: "isha",
                time: ishaIq,
                isFriday: isFriday,
                civilDay: dayDate,
            )
        }
    }

    // MARK: - Scheduling helpers

    private func scheduleAdhanIfEnabled(
        settings: NotificationSettings,
        mosqueSlug: String,
        iso: String,
        id: String,
        reminderId: String,
        prayerKey: String,
        time: String,
        isFriday: Bool,
        civilDay: Date
    ) async throws {
        if settings.adhanEnabled {
            let copy = PrayerNotificationContent.adhanCopy(prayerKey: prayerKey, isFriday: isFriday)
            let info = Self.adhanUserInfo(prayerKey: prayerKey, mosqueSlug: mosqueSlug, iso: iso)
            try await scheduleIfNeeded(
                id: id,
                title: copy.title,
                body: copy.body,
                civilDay: civilDay,
                hhmm: time,
                categoryIdentifier: PrayerNotificationContent.CategoryID.adhan,
                sound: PrayerNotificationContent.sound(for: settings, channel: .adhan),
                userInfo: info
            )
        }
        guard let minutes = settings.preAdhanReminderMinutes, minutes > 0 else { return }
        try await scheduleReminderIfNeeded(
            settings: settings,
            id: reminderId,
            mosqueSlug: mosqueSlug,
            iso: iso,
            prayerKey: prayerKey,
            kind: .beforeAdhan,
            minutesBefore: minutes,
            isFriday: isFriday,
            civilDay: civilDay,
            hhmm: time
        )
    }

    private func scheduleIqamahIfEnabled(
        settings: NotificationSettings,
        mosqueSlug: String,
        iso: String,
        id: String,
        reminderId: String,
        prayerKey: String,
        time: String,
        isFriday: Bool,
        civilDay: Date
    ) async throws {
        if settings.iqamahEnabled {
            let copy = PrayerNotificationContent.iqamahCopy(prayerKey: prayerKey, isFriday: isFriday)
            let info = Self.iqamahUserInfo(prayerKey: prayerKey, mosqueSlug: mosqueSlug, iso: iso)
            try await scheduleIfNeeded(
                id: id,
                title: copy.title,
                body: copy.body,
                civilDay: civilDay,
                hhmm: time,
                categoryIdentifier: PrayerNotificationContent.CategoryID.iqamah,
                sound: PrayerNotificationContent.sound(for: settings, channel: .iqamah),
                userInfo: info
            )
        }
        guard let minutes = settings.preIqamahReminderMinutes, minutes > 0 else { return }
        try await scheduleReminderIfNeeded(
            settings: settings,
            id: reminderId,
            mosqueSlug: mosqueSlug,
            iso: iso,
            prayerKey: prayerKey,
            kind: .beforeIqamah,
            minutesBefore: minutes,
            isFriday: isFriday,
            civilDay: civilDay,
            hhmm: time
        )
    }

    private enum ReminderKind {
        case beforeAdhan
        case beforeIqamah
    }

    private func scheduleReminderIfNeeded(
        settings: NotificationSettings,
        id: String,
        mosqueSlug: String,
        iso: String,
        prayerKey: String,
        kind: ReminderKind,
        minutesBefore: Int,
        isFriday: Bool,
        civilDay: Date,
        hhmm: String
    ) async throws {
        guard let targetDate = triggerDate(civilDay: civilDay, hhmm: hhmm) else { return }
        var calMinus = Calendar(identifier: .gregorian)
        calMinus.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let fire = calMinus.date(byAdding: .minute, value: -minutesBefore, to: targetDate),
              fire > Date()
        else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)

        let title: String
        let body: String
        let payloadKind: PrayerNotificationContent.PayloadKind
        switch kind {
        case .beforeAdhan:
            let copy = PrayerNotificationContent.beforeAdhanReminderCopy(prayerKey: prayerKey, isFriday: isFriday, minutes: minutesBefore)
            title = copy.title
            body = copy.body
            payloadKind = .reminderBeforeAdhan
        case .beforeIqamah:
            let copy = PrayerNotificationContent.beforeIqamahReminderCopy(prayerKey: prayerKey, isFriday: isFriday, minutes: minutesBefore)
            title = copy.title
            body = copy.body
            payloadKind = .reminderBeforeIqamah
        }

        let notificationSound = UNNotificationSound.default

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = notificationSound
        content.categoryIdentifier = PrayerNotificationContent.CategoryID.reminder
        content.userInfo = Self.reminderUserInfo(
            kind: payloadKind,
            prayerKey: prayerKey,
            mosqueSlug: mosqueSlug,
            iso: iso,
            minutes: minutesBefore
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        guard prayerNotificationAddBudget > 0 else { return }
        prayerNotificationAddBudget -= 1
        try await center.addPrayerNotificationRequest(request)
    }

    private func scheduleIfNeeded(
        id: String,
        title: String,
        body: String,
        civilDay: Date,
        hhmm: String,
        categoryIdentifier: String,
        sound: UNNotificationSound,
        userInfo: [AnyHashable: Any]
    ) async throws {
        guard let fire = triggerDate(civilDay: civilDay, hhmm: hhmm), fire > Date() else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = userInfo
        let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        guard prayerNotificationAddBudget > 0 else { return }
        prayerNotificationAddBudget -= 1
        try await center.addPrayerNotificationRequest(request)
    }

    private static func adhanUserInfo(prayerKey: String, mosqueSlug: String, iso: String) -> [AnyHashable: Any] {
        [
            PrayerNotificationContent.UserInfoKey.kind: PrayerNotificationContent.PayloadKind.adhan.rawValue,
            PrayerNotificationContent.UserInfoKey.prayer: prayerKey,
            PrayerNotificationContent.UserInfoKey.mosqueSlug: mosqueSlug,
            PrayerNotificationContent.UserInfoKey.isoDate: iso,
        ]
    }

    private static func iqamahUserInfo(prayerKey: String, mosqueSlug: String, iso: String) -> [AnyHashable: Any] {
        [
            PrayerNotificationContent.UserInfoKey.kind: PrayerNotificationContent.PayloadKind.iqamah.rawValue,
            PrayerNotificationContent.UserInfoKey.prayer: prayerKey,
            PrayerNotificationContent.UserInfoKey.mosqueSlug: mosqueSlug,
            PrayerNotificationContent.UserInfoKey.isoDate: iso,
        ]
    }

    private static func reminderUserInfo(
        kind: PrayerNotificationContent.PayloadKind,
        prayerKey: String,
        mosqueSlug: String,
        iso: String,
        minutes: Int
    ) -> [AnyHashable: Any] {
        [
            PrayerNotificationContent.UserInfoKey.kind: kind.rawValue,
            PrayerNotificationContent.UserInfoKey.prayer: prayerKey,
            PrayerNotificationContent.UserInfoKey.mosqueSlug: mosqueSlug,
            PrayerNotificationContent.UserInfoKey.isoDate: iso,
            "masjidly.reminder_minutes": minutes,
        ]
    }

    private func triggerDate(civilDay: Date, hhmm: String) -> Date? {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, p[0] >= 0, p[0] < 24, p[1] >= 0, p[1] < 60 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let start = cal.startOfDay(for: civilDay)
        return cal.date(bySettingHour: p[0], minute: p[1], second: 0, of: start)
    }
}
