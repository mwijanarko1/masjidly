import Foundation

struct NotificationSettings: Codable, Equatable, Sendable {
    var masterEnabled: Bool = false
    var adhanEnabled: Bool = true
    var iqamahEnabled: Bool = true
    var preAdhanReminderMinutes: Int? = nil
    var preIqamahReminderMinutes: Int? = nil

    enum CodingKeys: String, CodingKey {
        case masterEnabled
        case adhanEnabled
        case iqamahEnabled
        case preAdhanReminderMinutes
        case preIqamahReminderMinutes
    }

    init(
        masterEnabled: Bool = false,
        adhanEnabled: Bool = true,
        iqamahEnabled: Bool = true,
        preAdhanReminderMinutes: Int? = nil,
        preIqamahReminderMinutes: Int? = nil
    ) {
        self.masterEnabled = masterEnabled
        self.adhanEnabled = adhanEnabled
        self.iqamahEnabled = iqamahEnabled
        self.preAdhanReminderMinutes = preAdhanReminderMinutes
        self.preIqamahReminderMinutes = preIqamahReminderMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        masterEnabled = try c.decodeIfPresent(Bool.self, forKey: .masterEnabled) ?? false
        adhanEnabled = try c.decodeIfPresent(Bool.self, forKey: .adhanEnabled) ?? true
        iqamahEnabled = try c.decodeIfPresent(Bool.self, forKey: .iqamahEnabled) ?? true
        preAdhanReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .preAdhanReminderMinutes)
        preIqamahReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .preIqamahReminderMinutes)
    }
}
