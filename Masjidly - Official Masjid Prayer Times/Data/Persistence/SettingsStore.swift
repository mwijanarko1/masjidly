import Foundation
import Observation

@Observable
@MainActor
final class SettingsStore: SettingsPersisting {
    private let defaults = UserDefaults.standard

    private enum Key: String {
        case selectedMosqueId
        case selectedMosqueSlug
        case uses24HourTime
        case notificationsJSON
    }

    var selectedMosqueId: String? {
        get { defaults.string(forKey: Key.selectedMosqueId.rawValue) }
        set { defaults.set(newValue, forKey: Key.selectedMosqueId.rawValue) }
    }

    var selectedMosqueSlug: String? {
        get { defaults.string(forKey: Key.selectedMosqueSlug.rawValue) }
        set { defaults.set(newValue, forKey: Key.selectedMosqueSlug.rawValue) }
    }

    var uses24HourTime: Bool {
        get {
            if defaults.object(forKey: Key.uses24HourTime.rawValue) == nil { return false }
            return defaults.bool(forKey: Key.uses24HourTime.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.uses24HourTime.rawValue) }
    }

    var notifications: NotificationSettings {
        get {
            guard let data = defaults.data(forKey: Key.notificationsJSON.rawValue),
                  let v = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
                return NotificationSettings()
            }
            return v
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.notificationsJSON.rawValue)
            }
        }
    }
}
