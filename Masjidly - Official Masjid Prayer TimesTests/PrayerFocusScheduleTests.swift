import Foundation
import Testing
@testable import Masjidly

@Suite("Prayer Focus schedule")
struct PrayerFocusScheduleTests {
    private let early = london(2026, 1, 1, 0, 0)

    @Test func iqamahBasisStartsAtIqamahForFifteenMinutes() {
        let windows = build([day("2026-05-07")], settings(start: .iqamah))

        #expect(windows.map(\.start) == [
            london(2026, 5, 7, 5, 20), london(2026, 5, 7, 13, 30), london(2026, 5, 7, 17, 0),
            london(2026, 5, 7, 21, 5), london(2026, 5, 7, 22, 45),
        ])
        #expect(windows.allSatisfy { $0.end.timeIntervalSince($0.start) == 15 * 60 })
    }

    @Test func adhanBasisStartsAtAdhan() {
        let windows = build([day("2026-05-07")], settings(start: .adhan))
        #expect(windows.first?.start == london(2026, 5, 7, 5, 0))
    }

    @Test func fridayDhuhrUsesFirstJummahIqamah() {
        let windows = build([day("2026-05-08", jummah: "13:35, 14:15")], settings(start: .iqamah, prayers: [.dhuhr]))
        #expect(windows.map(\.start) == [london(2026, 5, 8, 13, 35)])
    }

    @Test func skipsDisabledPrayers() {
        let windows = build([day("2026-05-07")], settings(start: .iqamah, prayers: [.fajr, .isha]))
        #expect(windows.map(\.start) == [london(2026, 5, 7, 5, 20), london(2026, 5, 7, 22, 45)])
    }

    @Test func mergesOverlappingWindows() {
        let windows = build([day("2026-05-07", maghribIqamah: "21:05", ishaIqamah: "21:40")], settings(start: .iqamah, duration: 60, prayers: [.maghrib, .isha]))
        #expect(windows == [PrayerFocusWindow(start: london(2026, 5, 7, 21, 5), end: london(2026, 5, 7, 22, 40), prayer: .maghrib)])
    }

    @Test func unresolvedIqamahIsSkippedNotMovedToAdhan() {
        let windows = build([day("2026-05-07", ishaIqamah: "After Isha")], settings(start: .iqamah, prayers: [.maghrib, .isha]))
        #expect(windows.map(\.start) == [london(2026, 5, 7, 21, 5)])
    }

    @Test func skipsInvalidTimesInsteadOfOpenEndedWindows() {
        let d = day("2026-05-07", fajrAdhan: "--")
        #expect(build([d], settings(start: .adhan, prayers: [.fajr])).isEmpty)
    }

    @Test func dropsPastAndSuppressedWindows() {
        let windows = PrayerFocusScheduleBuilder.windows(
            snapshot: snapshot([day("2026-05-07")]),
            settings: settings(start: .iqamah),
            now: london(2026, 5, 7, 13, 35),
            suppressedUntil: london(2026, 5, 7, 13, 45)
        )
        #expect(windows.first?.start == london(2026, 5, 7, 17, 0))
    }

    @Test func keepsCurrentWindowWhenNotSuppressed() {
        let windows = PrayerFocusScheduleBuilder.windows(snapshot: snapshot([day("2026-05-07")]), settings: settings(start: .iqamah), now: london(2026, 5, 7, 13, 35))
        #expect(windows.first?.start == london(2026, 5, 7, 13, 30))
    }

    @Test func capsAtDeviceActivityMonitorLimit() {
        let days = (1...7).map { day(String(format: "2026-05-%02d", $0)) }
        #expect(build(days, settings(start: .iqamah)).count == PrayerFocusScheduleBuilder.maxWindows)
    }

    @Test func resolvesTimesInMosqueCivilTimeAcrossDst() {
        // UK clocks go back at 02:00 on 25 Oct 2026: 05:20 BST is 04:20 UTC, 05:20 GMT is 05:20 UTC.
        let windows = build([day("2026-10-24"), day("2026-10-25")], settings(start: .iqamah, prayers: [.fajr]))
        #expect(windows.map(\.start) == [utc(2026, 10, 24, 4, 20), utc(2026, 10, 25, 5, 20)])
    }

    @Test func asrUsesSecondIqamahWhenPreferred() {
        let d = day("2026-05-07", asrIqamah: "17:00, 18:00")
        let windows = PrayerFocusScheduleBuilder.windows(snapshot: snapshot([d], asr: .second), settings: settings(start: .iqamah, prayers: [.asr]), now: early)
        #expect(windows.map(\.start) == [london(2026, 5, 7, 18, 0)])
    }

    // MARK: - Mosque time zone

    @Test func londonMosqueTimeIsSameInstantAsRiyadhLocal() {
        // 16:30 Europe/London (BST) on 30 Sep 2026 is 18:30 Asia/Riyadh and 15:30 UTC.
        let d = day("2026-09-30", asrIqamah: "16:30")
        let windows = build([d], settings(start: .iqamah, prayers: [.asr]), timezone: "Europe/London")
        #expect(windows.map(\.start) == [utc(2026, 9, 30, 15, 30)])
        #expect(windows.map(\.start) == [date(2026, 9, 30, 18, 30, riyadh)])
    }

    @Test func riyadhMosqueTimesAreReadInRiyadh() {
        let d = day("2026-09-30", asrIqamah: "16:30")
        let windows = build([d], settings(start: .iqamah, prayers: [.asr]), timezone: "Asia/Riyadh")
        #expect(windows.map(\.start) == [utc(2026, 9, 30, 13, 30)])
    }

    @Test func mosqueWithoutDstIgnoresUkClockChange() {
        // Riyadh stays UTC+3 while UK clocks go back on 25 Oct 2026.
        let windows = build([day("2026-10-24"), day("2026-10-25")], settings(start: .iqamah, prayers: [.fajr]), timezone: "Asia/Riyadh")
        #expect(windows.map(\.start) == [utc(2026, 10, 24, 2, 20), utc(2026, 10, 25, 2, 20)])
    }

    @Test func explicitLondonZoneFollowsUkDst() {
        let windows = build([day("2026-10-24"), day("2026-10-25")], settings(start: .iqamah, prayers: [.fajr]), timezone: "Europe/London")
        #expect(windows.map(\.start) == [utc(2026, 10, 24, 4, 20), utc(2026, 10, 25, 5, 20)])
    }

    @Test func switchingMosqueRebuildsWindowsInNewZone() {
        let days = [day("2026-09-30", asrIqamah: "16:30")]
        let prayers = settings(start: .iqamah, prayers: [.asr])
        let london = build(days, prayers, timezone: "Europe/London")
        let riyadh = build(days, prayers, timezone: "Asia/Riyadh")
        #expect(london != riyadh)
        #expect(zip(london, riyadh).allSatisfy { $0.start.timeIntervalSince($1.start) == 2 * 3600 })
    }

    @Test func missingZoneKeepsLegacySheffieldDefault() {
        #expect(build([day("2026-09-30")], settings(start: .iqamah)) == build([day("2026-09-30")], settings(start: .iqamah), timezone: "Europe/London"))
    }

    @Test func unknownZoneSchedulesNothing() {
        #expect(build([day("2026-09-30")], settings(start: .iqamah), timezone: "Mars/Olympus").isEmpty)
    }

    @Test func deviceZoneChangeKeepsTheSameRegisteredInstant() {
        let instant = utc(2026, 9, 30, 15, 30)
        let inLondon = PrayerFocusScheduleBuilder.deviceActivityComponents(for: instant, in: PrayerTimesEngine.sheffieldTimeZone)
        let inRiyadh = PrayerFocusScheduleBuilder.deviceActivityComponents(for: instant, in: riyadh)
        #expect(inLondon.hour == 16 && inRiyadh.hour == 18)
        #expect(inLondon.timeZone == PrayerTimesEngine.sheffieldTimeZone && inRiyadh.timeZone == riyadh)
        // Components carry calendar + zone, so they resolve to the prayer instant whatever the device zone.
        #expect(inLondon.date == instant && inRiyadh.date == instant)
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(tokyo.date(from: inRiyadh) == instant)
    }

    // MARK: - Helpers

    private func build(_ days: [WidgetPrayerDaySnapshot], _ settings: PrayerFocusSettings, timezone: String? = nil) -> [PrayerFocusWindow] {
        PrayerFocusScheduleBuilder.windows(snapshot: snapshot(days, timezone: timezone), settings: settings, now: early)
    }

    private func settings(start: PrayerFocusStart, duration: Int = 15, prayers: Set<PrayerFocusPrayer> = Set(PrayerFocusPrayer.allCases)) -> PrayerFocusSettings {
        PrayerFocusSettings(isEnabled: true, start: start, durationMinutes: duration, prayers: prayers)
    }

    private func day(
        _ date: String,
        fajrAdhan: String = "05:00",
        asrIqamah: String = "17:00",
        maghribIqamah: String = "21:05",
        ishaIqamah: String = "22:45",
        jummah: String = "13:35"
    ) -> WidgetPrayerDaySnapshot {
        WidgetPrayerDaySnapshot(
            date: date,
            prayers: DailyPrayerTimes(date: date, fajr: fajrAdhan, sunrise: "05:10", dhuhr: "13:10", asr: "16:45", maghrib: "21:00", isha: "22:30"),
            iqamah: DailyIqamahTimes(fajr: "05:20", dhuhr: "13:30", asr: asrIqamah, maghrib: maghribIqamah, isha: ishaIqamah, jummah: jummah)
        )
    }

    private func snapshot(_ days: [WidgetPrayerDaySnapshot], asr: AsrIqamahPreference = .first, timezone: String? = nil) -> WidgetPrayerSnapshot {
        WidgetPrayerSnapshot(
            schemaVersion: WidgetPrayerSnapshot.currentSchemaVersion,
            generatedAt: early,
            mosque: WidgetMosqueSnapshot(id: "1", name: "Test Masjid", slug: "test-masjid", citySlug: nil, cityName: nil, countryCode: nil, countryName: nil, timezone: timezone),
            days: days,
            uses24HourTime: true,
            appLanguageRawValue: AppLanguage.english.rawValue,
            asrIqamahPreference: asr
        )
    }
}

private let riyadh = TimeZone(identifier: "Asia/Riyadh")!

private func london(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    date(y, mo, d, h, mi, PrayerTimesEngine.sheffieldTimeZone)
}

private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    date(y, mo, d, h, mi, TimeZone(secondsFromGMT: 0)!)
}

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ tz: TimeZone) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}
