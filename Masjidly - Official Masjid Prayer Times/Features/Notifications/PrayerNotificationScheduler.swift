import Foundation
import UserNotifications

final class PrayerNotificationScheduler: PrayerNotificationScheduling {
    private let repository: any PrayerRepository
    private let center: UNUserNotificationCenter

    init(repository: any PrayerRepository, center: UNUserNotificationCenter = .current()) {
        self.repository = repository
        self.center = center
    }

    func requestAuthorizationIfNeeded() async throws -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return try await center.requestAuthorization(options: [.alert, .sound])
    }

    func cancelAllPrayerNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("masjidly.prayer.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
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

        let ukDst = (try? await repository.getUkDstDates())?.ukDstDates ?? []
        let slug = mosque.slug
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let (y0, m0, d0) = PrayerTimesEngine.getDateInSheffield(Date())
        guard let baseDay = cal.date(from: DateComponents(year: y0, month: m0, day: d0)) else { return }

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

            if settings.fajr {
                await scheduleAdhanIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).fajr.adhan",
                    reminderId: "masjidly.prayer.\(slug).\(iso).fajr.adhan_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.fajr_adhan", locale: locale, args: [displayed.fajr]),
                    prayerLabel: "Fajr",
                    civilDay: dayDate,
                    hhmm: displayed.fajr,
                    locale: locale
                )
                let iqT = PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: displayed.fajr, iqamahTimes: iq)
                await scheduleIqamahIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).fajr.iqamah",
                    reminderId: "masjidly.prayer.\(slug).\(iso).fajr.iqamah_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.fajr_iqamah", locale: locale, args: [iqT]),
                    prayerLabel: "Fajr",
                    civilDay: dayDate,
                    hhmm: iqT,
                    locale: locale
                )
            }

            if settings.dhuhrJummah {
                let adhanKey = isFriday ? "notification.jummah_adhan" : "notification.dhuhr_adhan"
                await scheduleAdhanIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).dhuhr.adhan",
                    reminderId: "masjidly.prayer.\(slug).\(iso).dhuhr.adhan_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat(adhanKey, locale: locale, args: [displayed.dhuhr]),
                    prayerLabel: isFriday ? "Jummah" : "Dhuhr",
                    civilDay: dayDate,
                    hhmm: displayed.dhuhr,
                    locale: locale
                )
                let iqLabel = isFriday ? iq.jummah : PrayerTimesEngine.getIqamahTime(prayer: "dhuhr", adhanTime: displayed.dhuhr, iqamahTimes: iq)
                let iqBodyKey = isFriday ? "notification.jummah" : "notification.dhuhr_iqamah"
                await scheduleIqamahIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).\(isFriday ? "jummah" : "dhuhr").iqamah",
                    reminderId: "masjidly.prayer.\(slug).\(iso).\(isFriday ? "jummah" : "dhuhr").iqamah_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat(iqBodyKey, locale: locale, args: [iqLabel]),
                    prayerLabel: isFriday ? "Jummah" : "Dhuhr",
                    civilDay: dayDate,
                    hhmm: iqLabel,
                    locale: locale
                )
            }

            if settings.asr {
                await scheduleAdhanIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).asr.adhan",
                    reminderId: "masjidly.prayer.\(slug).\(iso).asr.adhan_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.asr_adhan", locale: locale, args: [displayed.asr]),
                    prayerLabel: "Asr",
                    civilDay: dayDate,
                    hhmm: displayed.asr,
                    locale: locale
                )
                let iqT = PrayerTimesEngine.getIqamahTime(prayer: "asr", adhanTime: displayed.asr, iqamahTimes: iq)
                await scheduleIqamahIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).asr.iqamah",
                    reminderId: "masjidly.prayer.\(slug).\(iso).asr.iqamah_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.asr_iqamah", locale: locale, args: [iqT]),
                    prayerLabel: "Asr",
                    civilDay: dayDate,
                    hhmm: iqT,
                    locale: locale
                )
            }

            if settings.maghrib {
                await scheduleAdhanIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).maghrib.adhan",
                    reminderId: "masjidly.prayer.\(slug).\(iso).maghrib.adhan_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.maghrib_adhan", locale: locale, args: [displayed.maghrib]),
                    prayerLabel: "Maghrib",
                    civilDay: dayDate,
                    hhmm: displayed.maghrib,
                    locale: locale
                )
                let iqT = PrayerTimesEngine.getIqamahTime(prayer: "maghrib", adhanTime: displayed.maghrib, iqamahTimes: iq)
                await scheduleIqamahIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).maghrib.iqamah",
                    reminderId: "masjidly.prayer.\(slug).\(iso).maghrib.iqamah_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.maghrib_iqamah", locale: locale, args: [iqT]),
                    prayerLabel: "Maghrib",
                    civilDay: dayDate,
                    hhmm: iqT,
                    locale: locale
                )
            }

            if settings.isha {
                await scheduleAdhanIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).isha.adhan",
                    reminderId: "masjidly.prayer.\(slug).\(iso).isha.adhan_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.isha_adhan", locale: locale, args: [displayed.isha]),
                    prayerLabel: "Isha",
                    civilDay: dayDate,
                    hhmm: displayed.isha,
                    locale: locale
                )
                let iqT = PrayerTimesEngine.resolveIshaIqamahForDisplay(
                    slug: slug,
                    date: cal.startOfDay(for: dayDate),
                    ishaAdhan: displayed.isha,
                    iqamahTimes: iq,
                    maghribAdhan: displayed.maghrib
                )
                await scheduleIqamahIfEnabled(
                    settings: settings,
                    id: "masjidly.prayer.\(slug).\(iso).isha.iqamah",
                    reminderId: "masjidly.prayer.\(slug).\(iso).isha.iqamah_reminder",
                    title: mosque.name,
                    body: Self.localizedFormat("notification.isha_iqamah", locale: locale, args: [iqT]),
                    prayerLabel: "Isha",
                    civilDay: dayDate,
                    hhmm: iqT,
                    locale: locale
                )
            }
        }
    }

    private static func localizedFormat(_ catalogKey: String, locale: Locale, args: [CVarArg]) -> String {
        let template = String(
            localized: String.LocalizationValue(stringLiteral: catalogKey),
            bundle: .main,
            locale: locale
        )
        return String(format: template, locale: locale, arguments: args)
    }

    private func scheduleAdhanIfEnabled(
        settings: NotificationSettings,
        id: String,
        reminderId: String,
        title: String,
        body: String,
        prayerLabel: String,
        civilDay: Date,
        hhmm: String,
        locale: Locale
    ) async {
        if settings.adhanEnabled {
            await scheduleIfNeeded(id: id, title: title, body: body, civilDay: civilDay, hhmm: hhmm)
        }
        guard let minutes = settings.preAdhanReminderMinutes, minutes > 0 else { return }
        await scheduleReminderIfNeeded(
            id: reminderId,
            title: title,
            prayerLabel: prayerLabel,
            eventLabel: "adhan",
            minutesBefore: minutes,
            civilDay: civilDay,
            hhmm: hhmm,
            locale: locale
        )
    }

    private func scheduleIqamahIfEnabled(
        settings: NotificationSettings,
        id: String,
        reminderId: String,
        title: String,
        body: String,
        prayerLabel: String,
        civilDay: Date,
        hhmm: String,
        locale: Locale
    ) async {
        if settings.iqamahEnabled {
            await scheduleIfNeeded(id: id, title: title, body: body, civilDay: civilDay, hhmm: hhmm)
        }
        guard let minutes = settings.preIqamahReminderMinutes, minutes > 0 else { return }
        await scheduleReminderIfNeeded(
            id: reminderId,
            title: title,
            prayerLabel: prayerLabel,
            eventLabel: "iqamah",
            minutesBefore: minutes,
            civilDay: civilDay,
            hhmm: hhmm,
            locale: locale
        )
    }

    private func scheduleReminderIfNeeded(
        id: String,
        title: String,
        prayerLabel: String,
        eventLabel: String,
        minutesBefore: Int,
        civilDay: Date,
        hhmm: String,
        locale: Locale
    ) async {
        guard let targetDate = triggerDate(civilDay: civilDay, hhmm: hhmm),
              let fire = Calendar(identifier: .gregorian).date(byAdding: .minute, value: -minutesBefore, to: targetDate),
              fire > Date()
        else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(prayerLabel) \(eventLabel) is in \(minutesBefore) minutes"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {}
    }

    private func scheduleIfNeeded(id: String, title: String, body: String, civilDay: Date, hhmm: String) async {
        guard let fire = triggerDate(civilDay: civilDay, hhmm: hhmm), fire > Date() else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {}
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
