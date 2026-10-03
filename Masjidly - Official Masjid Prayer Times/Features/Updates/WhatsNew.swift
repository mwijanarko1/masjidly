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
                    title: "شعارات جديدة",
                    description: "أربع مظاهر جديدة لمسجدلي: فجر، سماء، ظهيرة، ووردي.",
                    icon: "paintpalette.fill"
                ),
                WhatsNewItem(
                    title: "اختيار أيقونة التطبيق",
                    description: "اختر شعارك المفضل في أي وقت من الإعدادات.",
                    icon: "square.grid.2x2.fill"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "نئے لوگو",
                    description: "مسجدلی کے چار نئے انداز: فجر، آسمان، سہ پہر، اور گلابی۔",
                    icon: "paintpalette.fill"
                ),
                WhatsNewItem(
                    title: "ایپ آئیکن منتخب کریں",
                    description: "سیٹنگز سے کسی بھی وقت اپنا پسندیدہ لوگو چنیں۔",
                    icon: "square.grid.2x2.fill"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Logo baru",
                    description: "Empat tampilan baru untuk Masjidly: Fajar, Langit, Sore, dan Mawar.",
                    icon: "paintpalette.fill"
                ),
                WhatsNewItem(
                    title: "Pilih ikon aplikasi",
                    description: "Pilih logo favorit Anda kapan saja dari Pengaturan.",
                    icon: "square.grid.2x2.fill"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "New logos",
                    description: "Four fresh looks for Masjidly: Dawn, Sky, Afternoon, and Rose.",
                    icon: "paintpalette.fill"
                ),
                WhatsNewItem(
                    title: "App icon picker",
                    description: "Choose your favourite logo anytime in Settings.",
                    icon: "square.grid.2x2.fill"
                ),
            ]
        }
    }
}
