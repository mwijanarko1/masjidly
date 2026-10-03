import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case dawn
    case sky
    case afternoon
    case rose

    var id: String { rawValue }

    /// Name passed to `UIApplication.setAlternateIconName`.
    /// `nil` restores the primary icon from the asset catalog.
    var alternateIconName: String? {
        switch self {
        case .sky: return nil
        case .dawn: return "AppIcon-Dawn"
        case .afternoon: return "AppIcon-Afternoon"
        case .rose: return "AppIcon-Rose"
        }
    }

    var previewAssetName: String {
        switch self {
        case .dawn: return "AppIconOptionDawn"
        case .sky: return "AppIconOptionSky"
        case .afternoon: return "AppIconOptionAfternoon"
        case .rose: return "AppIconOptionRose"
        }
    }

    var titleKey: String {
        switch self {
        case .dawn: return "settings.app_icon.dawn"
        case .sky: return "settings.app_icon.sky"
        case .afternoon: return "settings.app_icon.afternoon"
        case .rose: return "settings.app_icon.rose"
        }
    }

    static var current: AppIconOption {
        guard UIApplication.shared.supportsAlternateIcons else { return .sky }
        switch UIApplication.shared.alternateIconName {
        case "AppIcon-Rose": return .rose
        case "AppIcon-Afternoon": return .afternoon
        case "AppIcon-Dawn": return .dawn
        default: return .sky
        }
    }

    static func apply(_ option: AppIconOption, completion: ((Error?) -> Void)? = nil) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?(nil)
            return
        }
        guard current != option else {
            completion?(nil)
            return
        }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
}
