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
                    description: "إصلاحات وتحسينات عامة لتجربة أكثر سلاسة.",
                    icon: "ladybug"
                ),
                WhatsNewItem(
                    title: "أوقات منتصف الليل والثلث الأخير",
                    description: "تمت إضافة أوقات منتصف الليل والثلث الأخير من الليل لكل جدول صلاة.",
                    icon: "moon.stars"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "بگ فکسز",
                    description: "مختلف بگ فکسز اور بہتریوں کے ساتھ ہموار تجربہ۔",
                    icon: "ladybug"
                ),
                WhatsNewItem(
                    title: "آدھی رات اور آخری تہائی رات کے اوقات",
                    description: "ہر نماز کے شیڈول کے لیے آدھی رات اور آخری تہائی رات کے اوقات شامل کیے گئے ہیں۔",
                    icon: "moon.stars"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Perbaikan Bug",
                    description: "Berbagai perbaikan bug dan peningkatan untuk pengalaman yang lebih lancar.",
                    icon: "ladybug"
                ),
                WhatsNewItem(
                    title: "Waktu Tengah Malam & Sepertiga Malam",
                    description: "Waktu tengah malam dan sepertiga malam terakhir telah ditambahkan untuk setiap jadwal sholat.",
                    icon: "moon.stars"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Bug Fixes",
                    description: "Various bug fixes and improvements for a smoother experience.",
                    icon: "ladybug"
                ),
                WhatsNewItem(
                    title: "Midnight & Last Third Times",
                    description: "Midnight and last third of the night times have been added for each prayer schedule.",
                    icon: "moon.stars"
                ),
            ]
        }
    }
}
