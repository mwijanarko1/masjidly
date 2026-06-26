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
                    title: "ودجات مُعاد تصميمها",
                    description: "ودجات الشاشة الرئيسية والقفل مع عدّاد مباشر وجداول الصلاة.",
                    icon: "square.grid.2x2.fill"
                ),
                WhatsNewItem(
                    title: "تدرجات صلاة جديدة",
                    description: "أصلي أو عصري أو مخصص لكل صلاة في الإعدادات ← السمة.",
                    icon: "paintpalette.fill"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "ویجٹس کا نیا ڈیزائن",
                    description: "ہوم اور لاک اسکرین ویجٹس میں لائیو کاؤنٹ ڈاؤن اور مکمل اوقات۔",
                    icon: "square.grid.2x2.fill"
                ),
                WhatsNewItem(
                    title: "نئے نماز کے گریڈینٹ",
                    description: "ہر نماز کے لیے اصل، جدید یا حسبِ مناسب۔ ترتیبات ← تھیم۔",
                    icon: "paintpalette.fill"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Widget didesain ulang",
                    description: "Widget layar utama dan kunci dengan hitung mundur langsung dan jadwal lengkap.",
                    icon: "square.grid.2x2.fill"
                ),
                WhatsNewItem(
                    title: "Gradien salat baru",
                    description: "Asli, Modern, atau Kustom per salat di Pengaturan → Tema.",
                    icon: "paintpalette.fill"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Redesigned widgets",
                    description: "Home and lock screen widgets with live countdowns and full prayer times.",
                    icon: "square.grid.2x2.fill"
                ),
                WhatsNewItem(
                    title: "New prayer gradients",
                    description: "Original, Modern, or Custom colors per prayer in Settings → Theme.",
                    icon: "paintpalette.fill"
                ),
            ]
        }
    }
}
