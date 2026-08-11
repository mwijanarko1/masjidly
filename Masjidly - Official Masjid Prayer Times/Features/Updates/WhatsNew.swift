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
                    title: "اتجاهات إلى أقرب مسجد",
                    description: "افتح إرشادات خطوة بخطوة إلى أقرب مسجد في تطبيق الخرائط المفضل لديك.",
                    icon: "map.fill"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "قریب ترین مسجد کا راستہ",
                    description: "اپنی پسندیدہ نقشہ ایپ میں قریب ترین مسجد تک مرحلہ وار راستہ کھولیں۔",
                    icon: "map.fill"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Petunjuk ke masjid terdekat",
                    description: "Buka petunjuk arah langkah demi langkah ke masjid terdekat di aplikasi peta pilihan Anda.",
                    icon: "map.fill"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Directions to your nearest mosque",
                    description: "Open turn-by-turn directions to the closest mosque in your preferred maps app.",
                    icon: "map.fill"
                ),
            ]
        }
    }
}
