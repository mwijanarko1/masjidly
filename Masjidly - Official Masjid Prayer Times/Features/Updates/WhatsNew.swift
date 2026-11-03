import Foundation

struct WhatsNewItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String // SF Symbol name
}

struct WhatsNew {
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    static var fullVersionString: String {
        "\(currentVersion) (\(currentBuild))"
    }

    static var latestUpdates: [WhatsNewItem] { localizedUpdates(locale: Locale(identifier: "en")) }

    static func localizedUpdates(locale: Locale) -> [WhatsNewItem] {
        let code = locale.language.languageCode?.identifier ?? String(locale.identifier.prefix(2))
        switch code {
        case "ar":
            return [
                WhatsNewItem(
                    title: "إصلاح الأخطاء",
                    description: "إصلاحات وتحسينات طفيفة.",
                    icon: "ladybug"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "بگ فکسز",
                    description: "معمولی بگ فکسز اور بہتری۔",
                    icon: "ladybug"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Perbaikan bug",
                    description: "Perbaikan bug dan peningkatan kecil.",
                    icon: "ladybug"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Bug Fixes",
                    description: "Minor bug fixes and improvements.",
                    icon: "ladybug"
                ),
            ]
        }
    }
}
