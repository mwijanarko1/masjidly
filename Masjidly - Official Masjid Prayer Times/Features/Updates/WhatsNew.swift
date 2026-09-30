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
                    description: "أوقف التطبيقات التي تختارها حول أوقات الصلاة.",
                    icon: "hourglass"
                ),
            ]
        case "ur":
            return [
                WhatsNewItem(
                    title: "نماز فوکس",
                    description: "نماز کے اوقات کے قریب اپنی منتخب ایپس روکیں۔",
                    icon: "hourglass"
                ),
            ]
        case "id":
            return [
                WhatsNewItem(
                    title: "Fokus Salat",
                    description: "Jeda aplikasi pilihan Anda sekitar waktu salat.",
                    icon: "hourglass"
                ),
            ]
        default:
            return [
                WhatsNewItem(
                    title: "Prayer Focus",
                    description: "Pause the apps you choose around prayer times.",
                    icon: "hourglass"
                ),
            ]
        }
    }
}
