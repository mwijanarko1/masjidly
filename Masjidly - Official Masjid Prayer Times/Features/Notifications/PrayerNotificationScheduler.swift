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

private actor PrayerNotificationRunLock {
    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run<T>(_ operation: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            locked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

private actor PrayerNotificationRunGate {
    private var generation = 0

    func next() -> Int {
        generation += 1
        return generation
    }

    func invalidate() {
        generation += 1
    }

    func isCurrent(_ value: Int) -> Bool {
        generation == value
    }
}

final class PrayerNotificationScheduler: PrayerNotificationScheduling {
    private let repository: any PrayerRepository
    private let center: any PrayerNotificationCenter
    private let runLock = PrayerNotificationRunLock()
    private let runGate = PrayerNotificationRunGate()
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
        await runLock.run {
            await runGate.invalidate()
            await cancelAllPrayerNotificationsForCurrentRun()
        }
    }

    private func cancelAllPrayerNotificationsForCurrentRun() async {
        let pending = await center.pendingPrayerNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("masjidly.prayer.") }
        center.removePendingPrayerNotificationRequests(withIdentifiers: ids)
    }

    func rescheduleUpcomingPrayerNotifications(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        locale: Locale,
        asrIqamahPreference: AsrIqamahPreference
    ) async throws {
        try await runLock.run {
            try await rescheduleUpcomingPrayerNotificationsForCurrentRun(
                mosque: mosque,
                days: days,
                settings: settings,
                locale: locale,
                asrIqamahPreference: asrIqamahPreference
            )
        }
    }

    private func rescheduleUpcomingPrayerNotificationsForCurrentRun(
        mosque: Mosque,
        days: Int,
        settings: NotificationSettings,
        locale: Locale,
        asrIqamahPreference: AsrIqamahPreference
    ) async throws {
        let generation = await runGate.next()
        await cancelAllPrayerNotificationsForCurrentRun()
        guard settings.masterEnabled else { return }
        let granted = try await requestAuthorizationIfNeeded()
        guard granted, await runGate.isCurrent(generation) else { return }

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
                let raw = try PrayerTimesEngine.resolvePrayerTimes(slug: slug, on: dayDate, monthly: monthly, ramadan: ramadan, ukDst: ukDst, asrTimingPreference: asrIqamahPreference)
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
            )
            let asrIq = PrayerTimesEngine.selectAsrIqamahTime(iq.asr, adhanTime: displayed.asr, preference: asrIqamahPreference)
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
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
                locale: locale,
                generation: generation
            )
        }
    }

    /// Returns `true` if the given prayerKey's adhan flag is enabled in settings.
    private func isAdhanForPrayerEnabled(prayerKey: String, settings: NotificationSettings) -> Bool {
        switch prayerKey {
        case "fajr":    return settings.adhanFajr
        case "dhuhr":   return settings.adhanDhuhrJummah
        case "asr":     return settings.adhanAsr
        case "maghrib": return settings.adhanMaghrib
        case "isha":    return settings.adhanIsha
        default:         return true
        }
    }

    /// Returns `true` if the given prayerKey's iqamah flag is enabled in settings.
    private func isIqamahForPrayerEnabled(prayerKey: String, settings: NotificationSettings) -> Bool {
        switch prayerKey {
        case "fajr":    return settings.iqamahFajr
        case "dhuhr":   return settings.iqamahDhuhrJummah
        case "asr":     return settings.iqamahAsr
        case "maghrib": return settings.iqamahMaghrib
        case "isha":    return settings.iqamahIsha
        default:         return true
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
        civilDay: Date,
        locale: Locale,
        generation: Int
    ) async throws {
        guard isAdhanForPrayerEnabled(prayerKey: prayerKey, settings: settings) else { return }
        if settings.adhanEnabled {
            let copy = PrayerNotificationContent.adhanCopy(prayerKey: prayerKey, isFriday: isFriday, locale: locale)
            let info = Self.adhanUserInfo(prayerKey: prayerKey, mosqueSlug: mosqueSlug, iso: iso)
            try await scheduleIfNeeded(
                id: id,
                title: copy.title,
                body: copy.body,
                civilDay: civilDay,
                hhmm: time,
                categoryIdentifier: PrayerNotificationContent.CategoryID.adhan,
                sound: PrayerNotificationContent.sound(for: settings, channel: .adhan),
                userInfo: info,
                generation: generation
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
            hhmm: time,
            locale: locale,
            generation: generation
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
        civilDay: Date,
        locale: Locale,
        generation: Int
    ) async throws {
        guard isIqamahForPrayerEnabled(prayerKey: prayerKey, settings: settings) else { return }
        if settings.iqamahEnabled {
            let copy = PrayerNotificationContent.iqamahCopy(prayerKey: prayerKey, isFriday: isFriday, locale: locale)
            let info = Self.iqamahUserInfo(prayerKey: prayerKey, mosqueSlug: mosqueSlug, iso: iso)
            try await scheduleIfNeeded(
                id: id,
                title: copy.title,
                body: copy.body,
                civilDay: civilDay,
                hhmm: time,
                categoryIdentifier: PrayerNotificationContent.CategoryID.iqamah,
                sound: PrayerNotificationContent.sound(for: settings, channel: .iqamah),
                userInfo: info,
                generation: generation
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
            hhmm: time,
            locale: locale,
            generation: generation
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
        hhmm: String,
        locale: Locale,
        generation: Int
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
            let copy = PrayerNotificationContent.beforeAdhanReminderCopy(prayerKey: prayerKey, isFriday: isFriday, minutes: minutesBefore, locale: locale)
            title = copy.title
            body = copy.body
            payloadKind = .reminderBeforeAdhan
        case .beforeIqamah:
            let copy = PrayerNotificationContent.beforeIqamahReminderCopy(prayerKey: prayerKey, isFriday: isFriday, minutes: minutesBefore, locale: locale)
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
        guard prayerNotificationAddBudget > 0, await runGate.isCurrent(generation) else { return }
        prayerNotificationAddBudget -= 1
        try await center.addPrayerNotificationRequest(request)
        if !(await runGate.isCurrent(generation)) {
            center.removePendingPrayerNotificationRequests(withIdentifiers: [id])
        }
    }

    private func scheduleIfNeeded(
        id: String,
        title: String,
        body: String,
        civilDay: Date,
        hhmm: String,
        categoryIdentifier: String,
        sound: UNNotificationSound,
        userInfo: [AnyHashable: Any],
        generation: Int
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
        guard prayerNotificationAddBudget > 0, await runGate.isCurrent(generation) else { return }
        prayerNotificationAddBudget -= 1
        try await center.addPrayerNotificationRequest(request)
        if !(await runGate.isCurrent(generation)) {
            center.removePendingPrayerNotificationRequests(withIdentifiers: [id])
        }
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
