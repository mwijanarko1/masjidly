import Foundation

struct Mosque: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let slug: String
    let citySlug: String?
    let cityName: String?
    let countryCode: String?
    let countryName: String?
    let timezone: String?
    let website: String?
    let isHidden: Bool?

    var isHiddenResolved: Bool { isHidden ?? false }
    var cityDisplayName: String { cityName ?? "Sheffield" }

    /// Groups mosques for city pickers; stable for `SettingsStore.selectedCityGroupingKey`.
    var cityGroupingKey: String {
        if let s = citySlug, !s.isEmpty { return "slug:\(s)" }
        let label = cityName ?? cityDisplayName
        return "name:\(label.lowercased())"
    }
}

struct PrayerTime: Codable, Equatable, Sendable {
    let date: Int
    let fajr: String
    let shurooq: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
}

struct IqamahTimeRange: Codable, Equatable, Sendable {
    let dateRange: String
    let fajr: String
    let dhuhr: String
    let asr: String
    let maghrib: String?
    let isha: String
    let jummah: String?

    enum CodingKeys: String, CodingKey {
        case dateRange = "date_range"
        case fajr, dhuhr, asr, maghrib, isha, jummah
    }
}

struct MonthPrayerData: Codable, Equatable, Sendable {
    let month: String
    let prayerTimes: [PrayerTime]
    let iqamahTimes: [IqamahTimeRange]
    let jummahIqamah: String

    enum CodingKeys: String, CodingKey {
        case month
        case prayerTimes = "prayer_times"
        case iqamahTimes = "iqamah_times"
        case jummahIqamah = "jummah_iqamah"
    }
}

struct RamadanPrayerDay: Codable, Equatable, Sendable {
    let ramadanDay: Int
    let gregorian: String
    let fajr: String
    let shurooq: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String

    enum CodingKeys: String, CodingKey {
        case ramadanDay = "ramadan_day"
        case gregorian, fajr, shurooq, dhuhr, asr, maghrib, isha
    }
}

struct RamadanPrayerData: Codable, Equatable, Sendable {
    let month: String
    let gregorianStart: String
    let gregorianEnd: String
    let prayerTimes: [RamadanPrayerDay]
    let iqamahTimes: [IqamahTimeRange]
    let jummahIqamah: String

    enum CodingKeys: String, CodingKey {
        case month
        case gregorianStart = "gregorian_start"
        case gregorianEnd = "gregorian_end"
        case prayerTimes = "prayer_times"
        case iqamahTimes = "iqamah_times"
        case jummahIqamah = "jummah_iqamah"
    }
}

struct DailyPrayerTimes: Codable, Equatable, Sendable {
    var date: String
    var fajr: String
    var sunrise: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
}

struct DailyIqamahTimes: Codable, Equatable, Sendable {
    var fajr: String
    var dhuhr: String
    var asr: String
    var maghrib: String
    var isha: String
    var jummah: String
}

struct UkDstYear: Codable, Equatable, Sendable {
    let year: Int
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case year
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct UkDstCalendar: Codable, Equatable, Sendable {
    let ukDstDates: [UkDstYear]

    enum CodingKeys: String, CodingKey {
        case ukDstDates = "uk_dst_dates"
    }
}
