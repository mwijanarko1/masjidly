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
                    title: "شرح أقصر",
                    description: "أصبح شرح البدء أقصر.",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "تبويبات المساجد",
                    description: "افتح عدة مساجد في تبويبات، وانتقل بينها أو أغلقها. يبقى المسجد المحدد في الإعدادات للإشعارات والودجت.",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "مختصر رہنمائی",
                    description: "شروع کرنے کی رہنمائی اب مختصر ہے۔",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "مسجد کے ٹیبز",
                    description: "کئی مساجد کو ٹیبز میں کھولیں، ان کے درمیان جائیں یا بند کریں۔ اطلاعات اور ویجٹ کے لیے ڈیفالٹ مسجد سیٹنگز میں ہی رہے گی۔",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Tutorial lebih singkat",
                    description: "Tutorial awal sekarang lebih singkat.",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "Tab masjid",
                    description: "Buka beberapa masjid dalam tab, beralih, atau tutup tab. Masjid untuk notifikasi dan widget tetap dipilih di Pengaturan.",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Shortened tutorial",
                    description: "The getting-started tutorial is now shorter.",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "Mosque tabs",
                    description: "Open, switch, and close mosque tabs. Your Settings mosque still controls notifications and the widget.",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        }
    }
}
