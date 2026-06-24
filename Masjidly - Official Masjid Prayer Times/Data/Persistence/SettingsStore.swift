import Foundation
import Observation
import WidgetKit

enum AsrIqamahPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case first
    case second

    var id: String { rawValue }
}

@Observable
@MainActor
final class SettingsStore: SettingsPersisting {
    private let defaults: UserDefaults

    private enum Key: String {
        case selectedMosqueId
        case selectedMosqueSlug
        case selectedCityGroupingKey
        case selectedCountryGroupingKey
        case uses24HourTime
        case notificationsJSON
        case appLanguage
        case hasCompletedOnboarding
        case appFontName
        case themeMode
        case fixedTheme
        case prayerGradientStylesJSON
        case asrIqamahPreference
        case hideQiblaCompass
        case firstAppOpenTrackedAt1970
        case hasCompletedEnjoymentReviewFlow
        case lastSeenBuildVersion
    }

    /// Stored fields so `@Observable` tracks mutations; UserDefaults syncs in `didSet`.
    var selectedMosqueId: String? {
        didSet { defaults.set(selectedMosqueId, forKey: Key.selectedMosqueId.rawValue) }
    }

    var selectedMosqueSlug: String? {
        didSet { defaults.set(selectedMosqueSlug, forKey: Key.selectedMosqueSlug.rawValue) }
    }

    /// When set, filters the mosque list in settings; when `nil`, the UI derives the city from the selected mosque.
    var selectedCityGroupingKey: String? {
        didSet { defaults.set(selectedCityGroupingKey, forKey: Key.selectedCityGroupingKey.rawValue) }
    }

    /// When set, filters the country list in settings; when `nil`, the UI derives the country from the selected mosque.
    var selectedCountryGroupingKey: String? {
        didSet { defaults.set(selectedCountryGroupingKey, forKey: Key.selectedCountryGroupingKey.rawValue) }
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

    /// Locale resolved from the persisted in-app language selection.
    var resolvedLocale: Locale { appLanguage.resolvedLocale() }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    var appFontName: String {
        didSet { defaults.set(appFontName, forKey: Key.appFontName.rawValue) }
    }

    var themeMode: HomeDesign.ThemeMode {
        didSet {
            defaults.set(themeMode.rawValue, forKey: Key.themeMode.rawValue)
            syncWidgetThemeSettings()
        }
    }

    var fixedTheme: HomeDesign.TimeTheme {
        didSet {
            defaults.set(fixedTheme.rawValue, forKey: Key.fixedTheme.rawValue)
            syncWidgetThemeSettings()
        }
    }

    private var prayerGradientStyles: [String: String] {
        didSet {
            if let data = try? JSONEncoder().encode(prayerGradientStyles) {
                defaults.set(data, forKey: Key.prayerGradientStylesJSON.rawValue)
            } else {
                defaults.removeObject(forKey: Key.prayerGradientStylesJSON.rawValue)
            }
            syncWidgetThemeSettings()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func skyGradientSet(for theme: HomeDesign.TimeTheme) -> HomeDesign.SkyGradientSet {
        guard HomeDesign.TimeTheme.configurableGradientThemes.contains(theme) else {
            return theme.defaultGradientSet()
        }
        let raw = prayerGradientStyles[theme.rawValue] ?? theme.defaultGradientSet().rawValue
        return HomeDesign.SkyGradientSet(rawValue: raw) ?? theme.defaultGradientSet()
    }

    func setSkyGradientSet(_ set: HomeDesign.SkyGradientSet, for theme: HomeDesign.TimeTheme) {
        guard HomeDesign.TimeTheme.configurableGradientThemes.contains(theme) else { return }
        var styles = prayerGradientStyles
        styles[theme.rawValue] = set.rawValue
        prayerGradientStyles = styles
    }

    func resolvedAppearance(for theme: HomeDesign.TimeTheme) -> HomeDesign.ResolvedTheme {
        HomeDesign.ResolvedTheme(
            timeTheme: theme,
            gradientSet: skyGradientSet(for: theme)
        )
    }

    var asrIqamahPreference: AsrIqamahPreference {
        didSet { defaults.set(asrIqamahPreference.rawValue, forKey: Key.asrIqamahPreference.rawValue) }
    }

    func resolvedTheme(dynamicTheme: HomeDesign.TimeTheme) -> HomeDesign.TimeTheme {
        themeMode == .dynamic ? dynamicTheme : fixedTheme
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

    /// The last build version string the user has seen in the What's New modal.
    /// When a new build is installed, this won't match, triggering the update pop-up.
    var lastSeenBuildVersion: String? {
        didSet { defaults.set(lastSeenBuildVersion, forKey: Key.lastSeenBuildVersion.rawValue) }
    }


    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedMosqueId = defaults.string(forKey: Key.selectedMosqueId.rawValue)
        selectedMosqueSlug = defaults.string(forKey: Key.selectedMosqueSlug.rawValue)
        selectedCityGroupingKey = defaults.string(forKey: Key.selectedCityGroupingKey.rawValue)
        selectedCountryGroupingKey = defaults.string(forKey: Key.selectedCountryGroupingKey.rawValue)
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
        appLanguage = AppLanguage(persistedRawValue: defaults.string(forKey: Key.appLanguage.rawValue))
        if defaults.object(forKey: Key.hasCompletedOnboarding.rawValue) == nil {
            hasCompletedOnboarding = false
        } else {
            hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue)
        }
        appFontName = defaults.string(forKey: Key.appFontName.rawValue) ?? "Gill Sans"
        themeMode = HomeDesign.ThemeMode(rawValue: defaults.string(forKey: Key.themeMode.rawValue) ?? "") ?? .dynamic
        fixedTheme = HomeDesign.TimeTheme(rawValue: defaults.string(forKey: Key.fixedTheme.rawValue) ?? "") ?? .fajr
        if let data = defaults.data(forKey: Key.prayerGradientStylesJSON.rawValue),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            prayerGradientStyles = decoded
        } else {
            prayerGradientStyles = [:]
        }
        asrIqamahPreference = AsrIqamahPreference(rawValue: defaults.string(forKey: Key.asrIqamahPreference.rawValue) ?? "") ?? .first
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
        lastSeenBuildVersion = defaults.string(forKey: Key.lastSeenBuildVersion.rawValue)
        syncWidgetThemeSettings()
    }

    private func syncWidgetThemeSettings() {
        guard let appGroupDefaults = UserDefaults(suiteName: WidgetPrayerSharedConfig.appGroupIdentifier) else { return }
        appGroupDefaults.set(themeMode.rawValue, forKey: WidgetPrayerSharedConfig.themeModeKey)
        appGroupDefaults.set(fixedTheme.rawValue, forKey: WidgetPrayerSharedConfig.fixedThemeKey)
        if let data = try? JSONEncoder().encode(prayerGradientStyles) {
            appGroupDefaults.set(data, forKey: WidgetPrayerSharedConfig.prayerGradientStylesKey)
        } else {
            appGroupDefaults.removeObject(forKey: WidgetPrayerSharedConfig.prayerGradientStylesKey)
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
