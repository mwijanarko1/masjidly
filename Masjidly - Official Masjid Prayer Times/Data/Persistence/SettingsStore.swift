import Foundation
import Observation

@Observable
@MainActor
final class SettingsStore: SettingsPersisting {
    private let defaults: UserDefaults

    private enum Key: String {
        case selectedMosqueId
        case selectedMosqueSlug
        case uses24HourTime
        case notificationsJSON
        case appLanguage
        case hasCompletedOnboarding
        case appFontName
        case hideQiblaCompass
        case firstAppOpenTrackedAt1970
        case hasCompletedEnjoymentReviewFlow
    }

    /// Stored fields so `@Observable` tracks mutations; UserDefaults syncs in `didSet`.
    var selectedMosqueId: String? {
        didSet { defaults.set(selectedMosqueId, forKey: Key.selectedMosqueId.rawValue) }
    }

    var selectedMosqueSlug: String? {
        didSet { defaults.set(selectedMosqueSlug, forKey: Key.selectedMosqueSlug.rawValue) }
    }

    var uses24HourTime: Bool {
        didSet { defaults.set(uses24HourTime, forKey: Key.uses24HourTime.rawValue) }
    }

    var notifications: NotificationSettings {
        didSet {
            if let data = try? JSONEncoder().encode(notifications) {
                defaults.set(data, forKey: Key.notificationsJSON.rawValue)
            }
        }
    }

    var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Key.appLanguage.rawValue) }
    }

    /// Convenience: always English locale.
    var resolvedLocale: Locale { Locale(identifier: "en") }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    var appFontName: String {
        didSet { defaults.set(appFontName, forKey: Key.appFontName.rawValue) }
    }

    /// When true, the Qibla compass rings and pointer are hidden (user deferred location).
    var hideQiblaCompass: Bool {
        didSet { defaults.set(hideQiblaCompass, forKey: Key.hideQiblaCompass.rawValue) }
    }

    /// First launch time used for the “enjoying the app?” review prompt eligibility (`nil` until recorded).
    var firstAppOpenTrackedAt: Date? {
        didSet {
            if let firstAppOpenTrackedAt {
                defaults.set(firstAppOpenTrackedAt.timeIntervalSince1970, forKey: Key.firstAppOpenTrackedAt1970.rawValue)
            } else {
                defaults.removeObject(forKey: Key.firstAppOpenTrackedAt1970.rawValue)
            }
        }
    }

    /// After the user responds to the soft review prompt (either option), we do not show it again.
    var hasCompletedEnjoymentReviewFlow: Bool {
        didSet { defaults.set(hasCompletedEnjoymentReviewFlow, forKey: Key.hasCompletedEnjoymentReviewFlow.rawValue) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedMosqueId = defaults.string(forKey: Key.selectedMosqueId.rawValue)
        selectedMosqueSlug = defaults.string(forKey: Key.selectedMosqueSlug.rawValue)
        if defaults.object(forKey: Key.uses24HourTime.rawValue) == nil {
            uses24HourTime = false
        } else {
            uses24HourTime = defaults.bool(forKey: Key.uses24HourTime.rawValue)
        }
        if let data = defaults.data(forKey: Key.notificationsJSON.rawValue),
           let v = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            notifications = v
        } else {
            notifications = NotificationSettings()
        }
        // Migrate legacy arabic/urdu/system → english and write back to clean the key.
        if let raw = defaults.string(forKey: Key.appLanguage.rawValue), raw != AppLanguage.english.rawValue {
            defaults.set(AppLanguage.english.rawValue, forKey: Key.appLanguage.rawValue)
        }
        appLanguage = .english
        if defaults.object(forKey: Key.hasCompletedOnboarding.rawValue) == nil {
            hasCompletedOnboarding = false
        } else {
            hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue)
        }
        appFontName = defaults.string(forKey: Key.appFontName.rawValue) ?? "Gill Sans"
        if defaults.object(forKey: Key.hideQiblaCompass.rawValue) == nil {
            hideQiblaCompass = false
        } else {
            hideQiblaCompass = defaults.bool(forKey: Key.hideQiblaCompass.rawValue)
        }
        if defaults.object(forKey: Key.firstAppOpenTrackedAt1970.rawValue) != nil {
            firstAppOpenTrackedAt = Date(timeIntervalSince1970: defaults.double(forKey: Key.firstAppOpenTrackedAt1970.rawValue))
        } else {
            firstAppOpenTrackedAt = nil
        }
        if defaults.object(forKey: Key.hasCompletedEnjoymentReviewFlow.rawValue) == nil {
            hasCompletedEnjoymentReviewFlow = false
        } else {
            hasCompletedEnjoymentReviewFlow = defaults.bool(forKey: Key.hasCompletedEnjoymentReviewFlow.rawValue)
        }
    }

    func ensureFirstAppOpenTrackedAtRecordedIfNeeded() {
        if firstAppOpenTrackedAt == nil {
            firstAppOpenTrackedAt = Date()
        }
    }

    #if DEBUG
    func resetEnjoymentReviewPromptForTesting() {
        hasCompletedEnjoymentReviewFlow = false
        firstAppOpenTrackedAt = Date().addingTimeInterval(-86400 * 2)
    }
    #endif
}
