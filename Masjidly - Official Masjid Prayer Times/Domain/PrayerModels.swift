import Foundation

struct DataRevision: Codable, Equatable, Sendable {
    let dataRevision: Double
    let updatedAt: Double
}

struct PrayerDataVersions: Codable, Equatable, Sendable {
    let mosquesUpdatedAt: Double
    let monthlyUpdatedAt: Double
    let ramadanUpdatedAt: Double
    let dstUpdatedAt: Double
}

struct CachedPrayerDataVersions: Codable, Equatable, Sendable {
    let versions: PrayerDataVersions
    let checkedAt: Date
}

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
    let asrMithl2: String?
    let maghrib: String
    let isha: String

    enum CodingKeys: String, CodingKey {
        case date, fajr, shurooq, dhuhr, asr, maghrib, isha
        case asrMithl2 = "asr_mithl2"
    }

    init(date: Int, fajr: String, shurooq: String, dhuhr: String, asr: String, asrMithl2: String? = nil, maghrib: String, isha: String) {
        self.date = date
        self.fajr = fajr
        self.shurooq = shurooq
        self.dhuhr = dhuhr
        self.asr = asr
        self.asrMithl2 = asrMithl2
        self.maghrib = maghrib
        self.isha = isha
    }
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

    init(dateRange: String, fajr: String, dhuhr: String, asr: String, maghrib: String?, isha: String, jummah: String?) {
        self.dateRange = dateRange
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.jummah = jummah
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dateRange = try c.decode(String.self, forKey: .dateRange)
        fajr = try Self.decodeIqamahValue(c, forKey: .fajr)
        dhuhr = try Self.decodeIqamahValue(c, forKey: .dhuhr)
        asr = try Self.decodeIqamahValue(c, forKey: .asr)
        maghrib = try Self.decodeOptionalIqamahValue(c, forKey: .maghrib)
        isha = try Self.decodeIqamahValue(c, forKey: .isha)
        jummah = try Self.decodeOptionalIqamahValue(c, forKey: .jummah)
    }

    private static func decodeIqamahValue(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> String {
        if let value = try? c.decode(String.self, forKey: key) { return value }
        if let values = try? c.decode([String].self, forKey: key) { return values.joined(separator: ", ") }
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: c.codingPath + [key], debugDescription: "Expected string or string array"))
    }

    private static func decodeOptionalIqamahValue(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> String? {
        guard c.contains(key), !(try c.decodeNil(forKey: key)) else { return nil }
        if let value = try? c.decode(String.self, forKey: key) { return value }
        if let values = try? c.decode([String].self, forKey: key) { return values.joined(separator: ", ") }
        return nil
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
    let asrMithl2: String?
    let maghrib: String
    let isha: String

    enum CodingKeys: String, CodingKey {
        case ramadanDay = "ramadan_day"
        case gregorian, fajr, shurooq, dhuhr, asr, maghrib, isha
        case asrMithl2 = "asr_mithl2"
    }

    init(ramadanDay: Int, gregorian: String, fajr: String, shurooq: String, dhuhr: String, asr: String, asrMithl2: String? = nil, maghrib: String, isha: String) {
        self.ramadanDay = ramadanDay
        self.gregorian = gregorian
        self.fajr = fajr
        self.shurooq = shurooq
        self.dhuhr = dhuhr
        self.asr = asr
        self.asrMithl2 = asrMithl2
        self.maghrib = maghrib
        self.isha = isha
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
