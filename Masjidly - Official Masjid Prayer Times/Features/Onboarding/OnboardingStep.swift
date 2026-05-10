import Foundation

enum OnboardingStep: Equatable, Sendable {
    case chooseMosque
    case prayerShortcut(index: Int)
    case openTimetable
    case closeTimetable
    case openSettings
    case closeSettings
    case notifications
}

struct OnboardingNotificationDraft: Equatable, Sendable {
    var adhanEnabled: Bool = true
    var iqamahEnabled: Bool = true
    var preAdhanReminderMinutes: Int? = nil
    var preIqamahReminderMinutes: Int? = nil
}
