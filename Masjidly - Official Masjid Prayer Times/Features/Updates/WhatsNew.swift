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
                    title: "تنبيه المسجد الأقرب",
                    description: "سيخبرك مسجدلي عندما يكون مسجد آخر أقرب إليك، ويمكنك التبديل إليه بنقرة واحدة.",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "إصلاحات الأخطاء",
                    description: "تم إصلاح مشكلات لتحسين موثوقية التطبيق.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "قریب ترین مسجد کی اطلاع",
                    description: "جب کوئی دوسرا مسجد آپ کے زیادہ قریب ہو تو مسجدلی آپ کو بتائے گا، اور آپ ایک ٹیپ سے اسے منتخب کر سکتے ہیں۔",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "بگز کی اصلاحات",
                    description: "ایپ کی بھروسے مندی بہتر بنانے کے لیے مسائل درست کیے گئے۔",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Pemberitahuan masjid terdekat",
                    description: "Masjidly memberi tahu saat masjid lain lebih dekat dan memungkinkan Anda beralih dengan satu ketukan.",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "Perbaikan bug",
                    description: "Memperbaiki masalah untuk meningkatkan keandalan aplikasi.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Nearest mosque prompt",
                    description: "Masjidly now lets you know when another mosque is closer and switch with one tap.",
                    icon: "location.fill"
                ),
                WhatsNewItem(
                    title: "Bug fixes",
                    description: "Fixed issues to improve app reliability.",
                    icon: "wrench.and.screwdriver.fill"
                ),
            ]
        }
    }
}
