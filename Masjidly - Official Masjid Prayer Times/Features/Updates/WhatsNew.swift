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
                    title: "إصلاحات أخطاء",
                    description: "تحسينات وإصلاحات لجعل التطبيق أكثر موثوقية.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "بگ فکسز",
                    description: "ایپ کو زیادہ قابلِ اعتماد بنانے کے لیے اصلاحات اور بہتریاں۔",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Perbaikan bug",
                    description: "Peningkatan dan perbaikan agar aplikasi lebih andal.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Bug fixes",
                    description: "Improvements and fixes to make the app more reliable.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        }
    }
}
