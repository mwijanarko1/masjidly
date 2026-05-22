import Foundation

enum WhatsNewAction {
    case settings
    case timetable
}

struct WhatsNewItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String // SF Symbol name
    let action: WhatsNewAction?
}

struct WhatsNew {
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    static var fullVersionString: String {
        "\(currentVersion) (\(currentBuild))"
    }

    static let latestUpdates: [WhatsNewItem] = [
        WhatsNewItem(
            title: "Multi-Language Support",
            description: "Masjidly now speaks your language. Switch between English, Arabic, Urdu, and Indonesian. Prayer names, settings, notifications, and widgets all adapt instantly.",
            icon: "globe",
            action: nil
        ),
        WhatsNewItem(
            title: "Arabic & Urdu RTL Layout",
            description: "Full right-to-left layout support for Arabic and Urdu. The entire interface mirrors gracefully, including the home screen, settings, and onboarding.",
            icon: "text.alignright",
            action: nil
        ),
        WhatsNewItem(
            title: "Localized Widgets",
            description: "Home screen widgets now display prayer times, mosque names, and dates in your selected language. No app restart needed.",
            icon: "square.grid.2x2",
            action: nil
        ),
        WhatsNewItem(
            title: "Localized Notifications",
            description: "Adhan and Iqamah notifications now show prayer names in your language, with localized alert text that respects the app language setting.",
            icon: "bell.badge",
            action: nil
        ),
        WhatsNewItem(
            title: "Seamless Runtime Switching",
            description: "Change language in Settings and the entire app updates on the spot. No app restart required. Widgets and notifications sync automatically.",
            icon: "arrow.triangle.2.circlepath",
            action: nil
        )
    ]
}
