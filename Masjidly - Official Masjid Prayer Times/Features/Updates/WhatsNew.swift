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
                    description: "تم إصلاح أخطاء متعلقة بالتوقيت الصيفي.",
                    icon: "ladybug"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "بگ فکسز",
                    description: "ڈے لائٹ سیونگ ٹائم سے متعلق خرابیاں ٹھیک کر دی گئیں۔",
                    icon: "ladybug"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Perbaikan bug",
                    description: "Memperbaiki bug terkait Daylight Saving Time.",
                    icon: "ladybug"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Bug Fixes",
                    description: "Fixed bugs relating to Daylight Saving Time.",
                    icon: "ladybug"
                ),
            ]
        }
    }
}
