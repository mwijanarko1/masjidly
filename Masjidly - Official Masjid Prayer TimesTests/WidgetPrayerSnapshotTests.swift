import Foundation
import Testing
@testable import Masjidly

@Suite("Widget prayer snapshots")
struct WidgetPrayerSnapshotTests {
    @Test func snapshotRoundTripsCoreFields() throws {
        let snapshot = makeSnapshot(generatedAt: fixedDate(hour: 7, minute: 0))

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetPrayerSnapshot.self, from: data)

        #expect(decoded.schemaVersion == WidgetPrayerSnapshot.currentSchemaVersion)
        #expect(decoded.mosque.name == "Test Masjid")
        #expect(decoded.days.count == 1)
        #expect(decoded.uses24HourTime == false)
        #expect(decoded.appLanguageRawValue == AppLanguage.english.rawValue)
    }

    @Test func resolverShowsAdhanBeforePrayer() throws {
        let snapshot = makeSnapshot(generatedAt: fixedDate(hour: 4, minute: 0))

        let state = try WidgetPrayerResolver.resolve(snapshot: snapshot, now: fixedDate(hour: 4, minute: 30))

        #expect(state.kind == .content)
        #expect(state.prayerName == "Fajr")
        #expect(state.adhanTime == "5:00am")
        #expect(state.iqamahTime == "5:20am")
        #expect(state.isIqamah == false)
    }

    @Test func resolverShowsIqamahBetweenAdhanAndIqamah() throws {
        let snapshot = makeSnapshot(generatedAt: fixedDate(hour: 5, minute: 2))

        let state = try WidgetPrayerResolver.resolve(snapshot: snapshot, now: fixedDate(hour: 5, minute: 10))

        #expect(state.kind == .content)
        #expect(state.prayerName == "Fajr")
        #expect(state.adhanTime == "5:00am")
        #expect(state.iqamahTime == "5:20am")
        #expect(state.isIqamah == true)
    }

    @Test func resolverUsesJummahOnFriday() throws {
        let snapshot = makeSnapshot(generatedAt: fixedDate(hour: 11, minute: 0))

        let state = try WidgetPrayerResolver.resolve(snapshot: snapshot, now: fixedDate(hour: 12, minute: 50))

        #expect(state.kind == .content)
        #expect(state.prayerName == "Jummah")
        #expect(state.adhanTime == "1:10pm")
        #expect(state.iqamahTime == "1:35pm")
    }

    @Test func resolverShowsTomorrowFajrAfterIshaWhenTimesDiffer() throws {
        // Two-day snapshot with different Fajr times; now is after Isha on day 1
        let snapshot = makeTwoDaySnapshot(
            generatedAt: fixedDate(hour: 22, minute: 30),
            day1Date: "2026-05-08",
            day2Date: "2026-05-09"
        )

        let state = try WidgetPrayerResolver.resolve(snapshot: snapshot, now: fixedDate(hour: 23, minute: 0))

        #expect(state.kind == .content)
        #expect(state.prayerName == "Fajr")
        #expect(state.adhanTime == "5:30am")  // Tomorrow's Fajr, not today's 5:00am
        #expect(state.iqamahTime == "5:50am") // Tomorrow's iqamah, not today's 5:20am
        #expect(state.isIqamah == false)
    }

    @Test func resolverReportsStaleWhenTodayIsMissing() throws {
        let snapshot = makeSnapshot(
            generatedAt: fixedDate(hour: 8, minute: 0),
            dayDate: "2026-05-09"
        )

        let state = try WidgetPrayerResolver.resolve(snapshot: snapshot, now: fixedDate(hour: 8, minute: 0))

        #expect(state.kind == .stale)
    }

    private func makeTwoDaySnapshot(
        generatedAt: Date,
        day1Date: String,
        day2Date: String
    ) -> WidgetPrayerSnapshot {
        WidgetPrayerSnapshot(
            schemaVersion: WidgetPrayerSnapshot.currentSchemaVersion,
            generatedAt: generatedAt,
            mosque: WidgetMosqueSnapshot(id: "1", name: "Test Masjid", slug: "test-masjid"),
            days: [
                WidgetPrayerDaySnapshot(
                    date: day1Date,
                    prayers: DailyPrayerTimes(
                        date: day1Date,
                        fajr: "05:00",
                        sunrise: "06:15",
                        dhuhr: "13:10",
                        asr: "17:30",
                        maghrib: "20:45",
                        isha: "22:15"
                    ),
                    iqamah: DailyIqamahTimes(
                        fajr: "05:20",
                        dhuhr: "13:30",
                        asr: "17:45",
                        maghrib: "20:50",
                        isha: "22:30",
                        jummah: "13:35"
                    )
                ),
                WidgetPrayerDaySnapshot(
                    date: day2Date,
                    prayers: DailyPrayerTimes(
                        date: day2Date,
                        fajr: "05:30",   // Different from day 1
                        sunrise: "06:15",
                        dhuhr: "13:15",
                        asr: "17:30",
                        maghrib: "20:45",
                        isha: "22:15"
                    ),
                    iqamah: DailyIqamahTimes(
                        fajr: "05:50",   // Different from day 1
                        dhuhr: "13:35",
                        asr: "17:45",
                        maghrib: "20:50",
                        isha: "22:30",
                        jummah: "13:35"
                    )
                )
            ],
            uses24HourTime: false,
            appLanguageRawValue: AppLanguage.english.rawValue
        )
    }

    private func makeSnapshot(
        generatedAt: Date,
        dayDate: String = "2026-05-08"
    ) -> WidgetPrayerSnapshot {
        WidgetPrayerSnapshot(
            schemaVersion: WidgetPrayerSnapshot.currentSchemaVersion,
            generatedAt: generatedAt,
            mosque: WidgetMosqueSnapshot(id: "1", name: "Test Masjid", slug: "test-masjid"),
            days: [
                WidgetPrayerDaySnapshot(
                    date: dayDate,
                    prayers: DailyPrayerTimes(
                        date: dayDate,
                        fajr: "05:00",
                        sunrise: "06:15",
                        dhuhr: "13:10",
                        asr: "17:30",
                        maghrib: "20:45",
                        isha: "22:15"
                    ),
                    iqamah: DailyIqamahTimes(
                        fajr: "05:20",
                        dhuhr: "13:30",
                        asr: "17:45",
                        maghrib: "20:50",
                        isha: "22:30",
                        jummah: "13:35"
                    )
                )
            ],
            uses24HourTime: false,
            appLanguageRawValue: AppLanguage.english.rawValue
        )
    }

    private func fixedDate(hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = PrayerTimesEngine.sheffieldTimeZone
        return calendar.date(from: DateComponents(year: 2026, month: 5, day: 8, hour: hour, minute: minute)) ?? Date()
    }
}
