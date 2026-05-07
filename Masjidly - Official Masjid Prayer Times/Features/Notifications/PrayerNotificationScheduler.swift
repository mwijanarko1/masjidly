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
        settings: NotificationSettings
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
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).fajr.adhan",
                    title: mosque.name,
                    body: "Fajr adhan \(displayed.fajr)",
                    civilDay: dayDate,
                    hhmm: displayed.fajr
                )
                let iqT = PrayerTimesEngine.getIqamahTime(prayer: "fajr", adhanTime: displayed.fajr, iqamahTimes: iq)
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).fajr.iqamah",
                    title: mosque.name,
                    body: "Fajr iqamah \(iqT)",
                    civilDay: dayDate,
                    hhmm: iqT
                )
            }

            if settings.dhuhrJummah {
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).dhuhr.adhan",
                    title: mosque.name,
                    body: isFriday ? "Jummah adhan \(displayed.dhuhr)" : "Dhuhr adhan \(displayed.dhuhr)",
                    civilDay: dayDate,
                    hhmm: displayed.dhuhr
                )
                let iqLabel = isFriday ? iq.jummah : PrayerTimesEngine.getIqamahTime(prayer: "dhuhr", adhanTime: displayed.dhuhr, iqamahTimes: iq)
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).\(isFriday ? "jummah" : "dhuhr").iqamah",
                    title: mosque.name,
                    body: isFriday ? "Jummah \(iqLabel)" : "Dhuhr iqamah \(iqLabel)",
                    civilDay: dayDate,
                    hhmm: iqLabel
                )
            }

            if settings.asr {
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).asr.adhan",
                    title: mosque.name,
                    body: "Asr adhan \(displayed.asr)",
                    civilDay: dayDate,
                    hhmm: displayed.asr
                )
                let iqT = PrayerTimesEngine.getIqamahTime(prayer: "asr", adhanTime: displayed.asr, iqamahTimes: iq)
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).asr.iqamah",
                    title: mosque.name,
                    body: "Asr iqamah \(iqT)",
                    civilDay: dayDate,
                    hhmm: iqT
                )
            }

            if settings.maghrib {
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).maghrib.adhan",
                    title: mosque.name,
                    body: "Maghrib adhan \(displayed.maghrib)",
                    civilDay: dayDate,
                    hhmm: displayed.maghrib
                )
                let iqT = PrayerTimesEngine.getIqamahTime(prayer: "maghrib", adhanTime: displayed.maghrib, iqamahTimes: iq)
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).maghrib.iqamah",
                    title: mosque.name,
                    body: "Maghrib iqamah \(iqT)",
                    civilDay: dayDate,
                    hhmm: iqT
                )
            }

            if settings.isha {
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).isha.adhan",
                    title: mosque.name,
                    body: "Isha adhan \(displayed.isha)",
                    civilDay: dayDate,
                    hhmm: displayed.isha
                )
                let iqT = PrayerTimesEngine.resolveIshaIqamahForDisplay(
                    slug: slug,
                    date: cal.startOfDay(for: dayDate),
                    ishaAdhan: displayed.isha,
                    iqamahTimes: iq,
                    maghribAdhan: displayed.maghrib
                )
                await scheduleIfNeeded(
                    id: "masjidly.prayer.\(slug).\(iso).isha.iqamah",
                    title: mosque.name,
                    body: "Isha iqamah \(iqT)",
                    civilDay: dayDate,
                    hhmm: iqT
                )
            }
        }
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
