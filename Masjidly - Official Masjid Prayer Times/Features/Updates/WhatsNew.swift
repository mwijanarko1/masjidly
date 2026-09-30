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
                    title: "التركيز للصلاة",
                    description: "أوقف التطبيقات المشتتة التي تختارها أثناء الصلاة. فعّل التركيز للصلاة من الإعدادات واختر ما تريد حظره.",
                    icon: "hourglass"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "نماز فوکس",
                    description: "نماز کے دوران منتخب کردہ توجہ ہٹانے والی ایپس روکیں۔ سیٹنگز میں نماز فوکس فعال کریں اور منتخب کریں کہ کیا روکنا ہے۔",
                    icon: "hourglass"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Fokus Salat",
                    description: "Jeda aplikasi pengganggu yang Anda pilih saat salat. Aktifkan Fokus Salat di Pengaturan dan pilih apa yang ingin diblokir.",
                    icon: "hourglass"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Prayer Focus",
                    description: "Pause selected distracting apps during prayer. Enable Prayer Focus in Settings and choose what to block.",
                    icon: "hourglass"
                ),
            ]
        }
    }
}
