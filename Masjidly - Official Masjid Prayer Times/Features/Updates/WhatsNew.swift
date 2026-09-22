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
                    description: "تم إصلاح مشكلات لتحسين موثوقية التطبيق.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "بگز کی اصلاحات",
                    description: "ایپ کی بھروسے مندی بہتر بنانے کے لیے مسائل درست کیے گئے۔",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Perbaikan bug",
                    description: "Memperbaiki masalah untuk meningkatkan keandalan aplikasi.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Bug fixes",
                    description: "Fixed issues to improve app reliability.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        }
    }
}
