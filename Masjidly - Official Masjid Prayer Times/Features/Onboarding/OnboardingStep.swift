import Foundation

enum OnboardingStep: Equatable, Sendable {
    case chooseLanguage
    case chooseMosque
    case prayerShortcut(index: Int)
    case qiblaCountdown
    case qibla
    case openTimetable
    case exploreTimetable
    case closeTimetable
    case openSettings
    case exploreSettings
    case closeSettings
    case notifications
}

struct OnboardingNotificationDraft: Equatable, Sendable {
    var adhanEnabled: Bool = true
    var iqamahEnabled: Bool = true
    var preAdhanReminderMinutes: Int? = nil
    var preIqamahReminderMinutes: Int? = nil
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

    init(
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
}
