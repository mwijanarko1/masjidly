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

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    /// Locale for SwiftUI `\.locale` and notification strings.
    var resolvedLocale: Locale {
        appLanguage.resolvedLocale()
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
        if let raw = defaults.string(forKey: Key.appLanguage.rawValue),
           let v = AppLanguage(rawValue: raw) {
            appLanguage = v
        } else {
            appLanguage = .system
        }
        if defaults.object(forKey: Key.hasCompletedOnboarding.rawValue) == nil {
            hasCompletedOnboarding = false
        } else {
            hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue)
        }
    }
}
