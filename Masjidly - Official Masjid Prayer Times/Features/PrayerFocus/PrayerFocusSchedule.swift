import Foundation

enum PrayerFocusStart: String, Codable, CaseIterable, Sendable {
    case adhan
    case iqamah
}

enum PrayerFocusPrayer: String, Codable, CaseIterable, Sendable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    var labelKey: String {
        switch self {
        case .fajr: "settings.notification.fajr"
        case .dhuhr: "settings.notification.dhuhr_jummah"
        case .asr: "settings.notification.asr"
        case .maghrib: "settings.notification.maghrib"
        case .isha: "settings.notification.isha"
        }
    }
}

struct PrayerFocusSettings: Codable, Equatable, Sendable {
    static let durationOptions = [15, 20, 30, 45, 60]

    var isEnabled = false
    var start: PrayerFocusStart = .adhan
    var durationMinutes = 15
    var prayers = Set(PrayerFocusPrayer.allCases)
}

struct PrayerFocusWindow: Codable, Equatable, Sendable {
    let start: Date
    let end: Date
    let prayer: PrayerFocusPrayer

    func contains(_ date: Date) -> Bool { start <= date && date < end }
}

/// Colors for the ManagedSettings shield UI, keyed by `PrayerFocusPrayer.rawValue` in the App Group.
struct PrayerFocusShieldTheme: Codable, Equatable, Sendable {
    let backgroundHex: String
    let foregroundHex: String
}

enum PrayerFocusScheduleBuilder {
    /// `DeviceActivityCenter` monitors at most 20 activities per app.
    static let maxWindows = 20
    /// `DeviceActivityCenter` rejects intervals shorter than 15 minutes.
    static let minimumDurationMinutes = 15

    /// Builds bounded, non-overlapping windows from the active mosque's resolved widget snapshot.
    /// Timetable clock times are read in the mosque's time zone, so each window is an absolute instant
    /// independent of the device's zone. Overlapping windows are merged so one window ending can never clear another.
    static func windows(
        snapshot: WidgetPrayerSnapshot,
        settings: PrayerFocusSettings,
        now: Date,
        suppressedUntil: Date? = nil
    ) -> [PrayerFocusWindow] {
        guard let mosqueTimeZone = snapshot.mosque.prayerTimeZone else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = mosqueTimeZone
        let duration = TimeInterval(max(settings.durationMinutes, minimumDurationMinutes) * 60)
        let preference = snapshot.asrIqamahPreference ?? .first

        var starts: [(date: Date, prayer: PrayerFocusPrayer)] = []
        for day in snapshot.days {
            guard let civilDay = civilDay(day.date, calendar: cal) else { continue }
            let isFriday = cal.component(.weekday, from: civilDay) == 6
            for prayer in PrayerFocusPrayer.allCases where settings.prayers.contains(prayer) {
                let adhan = adhanTime(prayer, day.prayers)
                let time = switch settings.start {
                case .adhan: adhan
                // Non-clock iqamah values ("After Maghrib") are skipped, never replaced with adhan.
                case .iqamah: iqamahTime(prayer, day: day, adhan: adhan, isFriday: isFriday, slug: snapshot.mosque.slug, civilDay: civilDay, preference: preference)
                }
                if let start = date(time, on: civilDay, calendar: cal) {
                    starts.append((start, prayer))
                }
            }
        }

        var merged: [PrayerFocusWindow] = []
        for item in starts.sorted(by: { $0.date < $1.date }) {
            let end = item.date.addingTimeInterval(duration)
            guard end > now, end > (suppressedUntil ?? .distantPast) else { continue }
            if let last = merged.last, item.date <= last.end {
                // Keep the earlier prayer's identity for the shield while the merged window is active.
                merged[merged.count - 1] = PrayerFocusWindow(start: last.start, end: max(last.end, end), prayer: last.prayer)
            } else {
                merged.append(PrayerFocusWindow(start: item.date, end: end, prayer: item.prayer))
            }
        }
        return Array(merged.prefix(maxWindows))
    }

    /// DeviceActivity components for an absolute instant. Carrying the calendar and zone pins the
    /// components to that instant; bare wall-clock components would float with the device's zone.
    static func deviceActivityComponents(for date: Date, in timeZone: TimeZone) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: date)
    }

    private static func adhanTime(_ prayer: PrayerFocusPrayer, _ times: DailyPrayerTimes) -> String {
        switch prayer {
        case .fajr: times.fajr
        case .dhuhr: times.dhuhr
        case .asr: times.asr
        case .maghrib: times.maghrib
        case .isha: times.isha
        }
    }

    private static func iqamahTime(
        _ prayer: PrayerFocusPrayer,
        day: WidgetPrayerDaySnapshot,
        adhan: String,
        isFriday: Bool,
        slug: String,
        civilDay: Date,
        preference: AsrIqamahPreference
    ) -> String {
        if prayer == .asr {
            return PrayerTimesEngine.selectAsrIqamahTime(day.iqamah.asr, adhanTime: adhan, preference: preference)
        }
        if prayer == .dhuhr, isFriday, let jummah = PrayerTimesEngine.splitJummahIqamahTimes(day.iqamah.jummah).first {
            return jummah
        }
        return PrayerTimesEngine.getDisplayIqamah(
            prayer: prayer.rawValue,
            adhanTime: adhan,
            iqamahTimes: day.iqamah,
            mosqueSlug: slug,
            date: civilDay,
            maghribAdhan: day.prayers.maghrib
        )
    }

    private static func civilDay(_ iso: String, calendar: Calendar) -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    private static func date(_ hhmm: String, on civilDay: Date, calendar: Calendar) -> Date? {
        let p = hhmm.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return calendar.date(bySettingHour: h, minute: m, second: 0, of: civilDay)
    }
}
