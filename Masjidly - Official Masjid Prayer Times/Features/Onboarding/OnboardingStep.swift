import Foundation

enum OnboardingStep: Equatable, Sendable {
    case chooseLanguage
    case requestLocation
    case chooseMosque
    case notifications
}

struct OnboardingNotificationDraft: Equatable, Sendable {
    var adhanEnabled: Bool = true
    var iqamahEnabled: Bool = true
    var preAdhanReminderMinutes: Int? = 10
    var preIqamahReminderMinutes: Int? = 10
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
        preAdhanReminderMinutes: Int? = 10,
        preIqamahReminderMinutes: Int? = 10,
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

    static func from(_ settings: NotificationSettings) -> OnboardingNotificationDraft {
        OnboardingNotificationDraft(
            adhanEnabled: settings.adhanEnabled,
            iqamahEnabled: settings.iqamahEnabled,
            preAdhanReminderMinutes: settings.preAdhanReminderMinutes,
            preIqamahReminderMinutes: settings.preIqamahReminderMinutes,
            fajr: settings.fajr,
            dhuhrJummah: settings.dhuhrJummah,
            asr: settings.asr,
            maghrib: settings.maghrib,
            isha: settings.isha,
            adhanFajr: settings.adhanFajr,
            adhanDhuhrJummah: settings.adhanDhuhrJummah,
            adhanAsr: settings.adhanAsr,
            adhanMaghrib: settings.adhanMaghrib,
            adhanIsha: settings.adhanIsha,
            iqamahFajr: settings.iqamahFajr,
            iqamahDhuhrJummah: settings.iqamahDhuhrJummah,
            iqamahAsr: settings.iqamahAsr,
            iqamahMaghrib: settings.iqamahMaghrib,
            iqamahIsha: settings.iqamahIsha
        )
    }

    /// Onboarding starts from the same defaults as a fresh install.
    static let defaultEnabled = OnboardingNotificationDraft.from(.defaultEnabled)
}
