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
                    title: "إصلاحات الأخطاء",
                    description: "تحسينات عامة لتجربة أكثر سلاسة.",
                    icon: "ladybug"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "بگ فکسز",
                    description: "مزید ہموار تجربے کے لیے عمومی بہتریاں۔",
                    icon: "ladybug"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Perbaikan Bug",
                    description: "Peningkatan umum untuk pengalaman yang lebih lancar.",
                    icon: "ladybug"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Bug Fixes",
                    description: "General improvements for a smoother experience.",
                    icon: "ladybug"
                ),
            ]
        }
    }
}
