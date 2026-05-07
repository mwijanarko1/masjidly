import Foundation
import Testing
@testable import Masjidly

@Suite("Decoding")
struct DecodingTests {
    @Test func mosqueDecodes() throws {
        let json = """
        {"id":"1","name":"Test Masjid","address":"1 St","lat":53.3,"lng":-1.5,"slug":"test-masjid","website":null,"isHidden":false}
        """
        let m = try JSONDecoder().decode(Mosque.self, from: Data(json.utf8))
        #expect(m.slug == "test-masjid")
        #expect(m.isHiddenResolved == false)
    }

    @Test func monthlyDecodes() throws {
        let json = """
        {"month":"MAY","prayer_times":[{"date":1,"fajr":"03:30","shurooq":"05:10","dhuhr":"13:10","asr":"18:30","maghrib":"21:00","isha":"22:15"}],
        "iqamah_times":[{"date_range":"1-31","fajr":"04:00","dhuhr":"13:30","asr":"19:00","maghrib":"sunset","isha":"22:45"}],
        "jummah_iqamah":"13:35"}
        """
        let d = try JSONDecoder().decode(MonthPrayerData.self, from: Data(json.utf8))
        #expect(d.prayerTimes.count == 1)
        #expect(d.jummahIqamah == "13:35")
    }

    @Test func ramadanDecodes() throws {
        let json = """
        {"month":"Ramadan","gregorian_start":"2025-03-01","gregorian_end":"2025-03-29",
        "prayer_times":[{"ramadan_day":1,"gregorian":"2025-03-01","fajr":"05:00","shurooq":"06:00","dhuhr":"12:00","asr":"15:00","maghrib":"18:00","isha":"20:00"}],
        "iqamah_times":[{"date_range":"1-30","fajr":"05:15","dhuhr":"12:30","asr":"15:30","isha":"20:30"}],
        "jummah_iqamah":"12:45"}
        """
        let d = try JSONDecoder().decode(RamadanPrayerData.self, from: Data(json.utf8))
        #expect(d.prayerTimes.first?.ramadanDay == 1)
    }
}

@Suite("Prayer engine")
struct PrayerEngineTests {
    @Test func findDayDataClosestPrevious() {
        let rows = [
            PrayerTime(date: 1, fajr: "a", shurooq: "b", dhuhr: "12:00", asr: "c", maghrib: "d", isha: "e"),
            PrayerTime(date: 15, fajr: "a2", shurooq: "b2", dhuhr: "12:30", asr: "c2", maghrib: "d2", isha: "e2"),
        ]
        let hit = PrayerTimesEngine.findDayData(rows, dayOfMonth: 10)
        #expect(hit?.dhuhr == "12:00")
    }

    @Test func iqamahRange() throws {
        let ranges = [
            IqamahTimeRange(dateRange: "1-10", fajr: "x", dhuhr: "y", asr: "z", maghrib: nil, isha: "i", jummah: nil),
            IqamahTimeRange(dateRange: "11-20", fajr: "x2", dhuhr: "y2", asr: "z2", maghrib: nil, isha: "i2", jummah: nil),
        ]
        let d = try PrayerTimesEngine.getIqamahTimesForDate(dayOfMonth: 15, iqamahRanges: ranges)
        #expect(d.fajr == "x2")
    }

    @Test func jummahFridayUsesJummahString() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let fri = cal.date(from: DateComponents(year: 2026, month: 1, day: 2)) else { return }
        #expect(cal.component(.weekday, from: fri) == 6)
        let d = DailyPrayerTimes(date: "2026-01-02", fajr: "03:00", sunrise: "04:00", dhuhr: "13:00", asr: "18:00", maghrib: "20:00", isha: "21:00")
        let iq = DailyIqamahTimes(fajr: "03:30", dhuhr: "13:20", asr: "18:10", maghrib: "20:05", isha: "21:10", jummah: "13:25")
        let n = PrayerTimesEngine.getNextPrayerAndCountdown(prayerTimes: d, iqamahTimes: iq, mosqueSlug: "x", now: fri)
        #expect(["Jummah", "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(n.nextName))
    }

    @Test func risalahIshaDisplayUsesAdhanInMayJuly() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
        guard let d = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)) else { return }
        let iq = DailyIqamahTimes(fajr: "1", dhuhr: "2", asr: "3", maghrib: "4", isha: "Entry Time", jummah: "")
        let s = PrayerTimesEngine.resolveIshaIqamahForDisplay(
            slug: "masjid-risalah",
            date: d,
            ishaAdhan: "22:40",
            iqamahTimes: iq,
            maghribAdhan: "21:30"
        )
        #expect(s == "22:40")
    }

    @Test func dstEmbeddedRemap() {
        let day = PrayerTimesEngine.resolveTimetableDayForUkEmbeddedDst(calendarDay: 28, transitionDayInTable: 30, ukTransitionDay: 29, maxTableDay: 31)
        #expect(day == 29)
    }
}

@Suite("Settings")
struct SettingsStoreTests {
    @Test @MainActor func mosquePersistenceAndDefault() {
        let s = SettingsStore()
        s.selectedMosqueId = "bad-id"
        s.selectedMosqueSlug = MosqueDefaults.defaultSlug
        let mosques: [Mosque] = [
            Mosque(id: "a", name: "A", address: "", lat: 0, lng: 0, slug: "other", website: nil, isHidden: false),
            Mosque(id: "b", name: "MWH", address: "", lat: 0, lng: 0, slug: MosqueDefaults.defaultSlug, website: nil, isHidden: false),
        ]
        let m = MosqueDefaults.resolveSelectedMosque(mosques: mosques, selectedId: s.selectedMosqueId, selectedSlug: s.selectedMosqueSlug)
        #expect(m?.slug == MosqueDefaults.defaultSlug)
        s.uses24HourTime = true
        #expect(s.uses24HourTime == true)
    }
}

    var mosques: [Mosque] = []
    var monthly: MonthPrayerData?
    var ramadan: RamadanPrayerData?
    var dst: UkDstCalendar?

    func listMosques() async throws -> [Mosque] { mosques }
    func getMonthlyPrayerTimes(mosqueSlug: String, month: MonthName, year: Int) async throws -> MonthPrayerData? { monthly }
    func getRamadanTimetable(mosqueSlug: String, date: String?) async throws -> RamadanPrayerData? { ramadan }
    func getUkDstDates() async throws -> UkDstCalendar? { dst }
}
