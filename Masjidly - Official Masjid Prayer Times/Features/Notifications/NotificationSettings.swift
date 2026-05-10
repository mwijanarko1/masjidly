import Foundation

struct NotificationSettings: Codable, Equatable, Sendable {
    var masterEnabled: Bool = false
    var adhanEnabled: Bool = true
    var iqamahEnabled: Bool = true
    var preAdhanReminderMinutes: Int? = nil
    var preIqamahReminderMinutes: Int? = nil
    var fajr: Bool = true
    var dhuhrJummah: Bool = true
    var asr: Bool = true
    var maghrib: Bool = true
    var isha: Bool = true

    enum CodingKeys: String, CodingKey {
        case masterEnabled
        case adhanEnabled
        case iqamahEnabled
        case preAdhanReminderMinutes
        case preIqamahReminderMinutes
        case fajr
        case dhuhrJummah
        case asr
        case maghrib
        case isha
    }

    init(
        masterEnabled: Bool = false,
        adhanEnabled: Bool = true,
        iqamahEnabled: Bool = true,
        preAdhanReminderMinutes: Int? = nil,
        preIqamahReminderMinutes: Int? = nil,
        fajr: Bool = true,
        dhuhrJummah: Bool = true,
        asr: Bool = true,
        maghrib: Bool = true,
        isha: Bool = true
    ) {
        self.masterEnabled = masterEnabled
        self.adhanEnabled = adhanEnabled
        self.iqamahEnabled = iqamahEnabled
        self.preAdhanReminderMinutes = preAdhanReminderMinutes
        self.preIqamahReminderMinutes = preIqamahReminderMinutes
        self.fajr = fajr
        self.dhuhrJummah = dhuhrJummah
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        masterEnabled = try c.decodeIfPresent(Bool.self, forKey: .masterEnabled) ?? false
        adhanEnabled = try c.decodeIfPresent(Bool.self, forKey: .adhanEnabled) ?? true
        iqamahEnabled = try c.decodeIfPresent(Bool.self, forKey: .iqamahEnabled) ?? true
        preAdhanReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .preAdhanReminderMinutes)
        preIqamahReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .preIqamahReminderMinutes)
        fajr = try c.decodeIfPresent(Bool.self, forKey: .fajr) ?? true
        dhuhrJummah = try c.decodeIfPresent(Bool.self, forKey: .dhuhrJummah) ?? true
        asr = try c.decodeIfPresent(Bool.self, forKey: .asr) ?? true
        maghrib = try c.decodeIfPresent(Bool.self, forKey: .maghrib) ?? true
        isha = try c.decodeIfPresent(Bool.self, forKey: .isha) ?? true
    }
}
