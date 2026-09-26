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
                    title: "تبويبات المساجد",
                    description: "اعرض أوقات أكثر من مسجد عبر التبويبات. افتحها، انتقل بينها، أو أغلقها. يبقى المسجد المحدد في الإعدادات للإشعارات والودجت.",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "مسجد کے ٹیبز",
                    description: "ٹیبز سے ایک سے زیادہ مساجد کے اوقات دیکھیں۔ کھولیں، سوئچ کریں، یا بند کریں۔ اطلاعات اور ویجٹ کے لیے ڈیفالٹ مسجد سیٹنگز میں ہی رہے گی۔",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Tab masjid",
                    description: "Lihat jadwal lebih dari satu masjid lewat tab. Buka, beralih, atau tutup tab. Masjid untuk notifikasi dan widget tetap dipilih di Pengaturan.",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Mosque tabs",
                    description: "Mosque tabs let you see times for more than one mosque. Open, switch, or close them anytime. The active mosque controls notifications and the widget.",
                    icon: "rectangle.on.rectangle"
                ),
            ]
        }
    }
}
