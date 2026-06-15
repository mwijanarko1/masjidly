import Foundation

struct NotificationSettings: Codable, Equatable, Sendable {
    var masterEnabled: Bool = false
    var adhanEnabled: Bool = true
    var iqamahEnabled: Bool = true
    var preAdhanReminderMinutes: Int? = nil
    var preIqamahReminderMinutes: Int? = nil
    // Legacy single per-prayer flags (used for both adhan + iqamah before v1.1.2)
    var fajr: Bool = true
    var dhuhrJummah: Bool = true
    var asr: Bool = true
    var maghrib: Bool = true
    var isha: Bool = true
    // Per-type per-prayer flags (v1.1.2+)
    var adhanFajr: Bool = true
    var adhanDhuhrJummah: Bool = true
    var adhanAsr: Bool = true
    var adhanMaghrib: Bool = true
    var adhanIsha: Bool = true
    var iqamahFajr: Bool = true
    var iqamahDhuhrJummah: Bool = true
    var iqamahAsr: Bool = true
    var iqamahMaghrib: Bool = true
    var iqamahIsha: Bool = true

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
        case adhanFajr
        case adhanDhuhrJummah
        case adhanAsr
        case adhanMaghrib
        case adhanIsha
        case iqamahFajr
        case iqamahDhuhrJummah
        case iqamahAsr
        case iqamahMaghrib
        case iqamahIsha
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
        isha: Bool = true,
        adhanFajr: Bool = true,
        adhanDhuhrJummah: Bool = true,
        adhanAsr: Bool = true,
        adhanMaghrib: Bool = true,
        adhanIsha: Bool = true,
        iqamahFajr: Bool = true,
        iqamahDhuhrJummah: Bool = true,
        iqamahAsr: Bool = true,
        iqamahMaghrib: Bool = true,
        iqamahIsha: Bool = true
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
        self.adhanFajr = adhanFajr
        self.adhanDhuhrJummah = adhanDhuhrJummah
        self.adhanAsr = adhanAsr
        self.adhanMaghrib = adhanMaghrib
        self.adhanIsha = adhanIsha
        self.iqamahFajr = iqamahFajr
        self.iqamahDhuhrJummah = iqamahDhuhrJummah
        self.iqamahAsr = iqamahAsr
        self.iqamahMaghrib = iqamahMaghrib
        self.iqamahIsha = iqamahIsha
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        masterEnabled = try c.decodeIfPresent(Bool.self, forKey: .masterEnabled) ?? false
        adhanEnabled = try c.decodeIfPresent(Bool.self, forKey: .adhanEnabled) ?? true
        iqamahEnabled = try c.decodeIfPresent(Bool.self, forKey: .iqamahEnabled) ?? true
        preAdhanReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .preAdhanReminderMinutes)
        preIqamahReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .preIqamahReminderMinutes)
        // Legacy single per-prayer flags
        fajr = try c.decodeIfPresent(Bool.self, forKey: .fajr) ?? true
        dhuhrJummah = try c.decodeIfPresent(Bool.self, forKey: .dhuhrJummah) ?? true
        asr = try c.decodeIfPresent(Bool.self, forKey: .asr) ?? true
        maghrib = try c.decodeIfPresent(Bool.self, forKey: .maghrib) ?? true
        isha = try c.decodeIfPresent(Bool.self, forKey: .isha) ?? true
        // Per-type per-prayer flags: fall back to legacy flag if missing
        adhanFajr = try c.decodeIfPresent(Bool.self, forKey: .adhanFajr) ?? fajr
        adhanDhuhrJummah = try c.decodeIfPresent(Bool.self, forKey: .adhanDhuhrJummah) ?? dhuhrJummah
        adhanAsr = try c.decodeIfPresent(Bool.self, forKey: .adhanAsr) ?? asr
        adhanMaghrib = try c.decodeIfPresent(Bool.self, forKey: .adhanMaghrib) ?? maghrib
        adhanIsha = try c.decodeIfPresent(Bool.self, forKey: .adhanIsha) ?? isha
        iqamahFajr = try c.decodeIfPresent(Bool.self, forKey: .iqamahFajr) ?? fajr
        iqamahDhuhrJummah = try c.decodeIfPresent(Bool.self, forKey: .iqamahDhuhrJummah) ?? dhuhrJummah
        iqamahAsr = try c.decodeIfPresent(Bool.self, forKey: .iqamahAsr) ?? asr
        iqamahMaghrib = try c.decodeIfPresent(Bool.self, forKey: .iqamahMaghrib) ?? maghrib
        iqamahIsha = try c.decodeIfPresent(Bool.self, forKey: .iqamahIsha) ?? isha
    }
}
