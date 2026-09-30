import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customizes the system shield shown over apps blocked by Prayer Focus.
final class PrayerFocusShieldConfiguration: ShieldConfigurationDataSource {
    private struct Window: Decodable {
        let start: Date
        let end: Date
        let prayer: String?
    }

    private struct Theme: Decodable {
        let backgroundHex: String
        let foregroundHex: String
    }

    private let defaults = UserDefaults(suiteName: "group.mikhailspeaks.masjidly")

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let prayer = activePrayerRawValue()
        let theme = theme(for: prayer)
        let background = UIColor(rgbHex: theme.backgroundHex) ?? UIColor(red: 0.06, green: 0.22, blue: 0.51, alpha: 1)
        let foreground = UIColor(rgbHex: theme.foregroundHex) ?? .white
        let name = displayName(for: prayer)

        // Apple applies backgroundColor as a tint on the blur; nil blur falls back to white.
        // Apple only fills one control (primary). Secondary is always text-style.
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: background,
            title: .init(text: "\(name) Prayer Focus", color: foreground),
            subtitle: .init(
                text: "Take a few minutes for \(name). Tap I've prayed when you're finished.",
                color: foreground.withAlphaComponent(0.85)
            ),
            primaryButtonLabel: .init(text: "OK", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: .init(text: "I've prayed", color: foreground)
        )
    }

    private func activePrayerRawValue() -> String {
        let now = Date()
        let windows = decode([Window].self, forKey: "prayerFocus.windows.v1") ?? []
        if let active = windows.first(where: { $0.start <= now && now < $0.end }), let prayer = active.prayer {
            return prayer
        }
        return windows.first?.prayer ?? "fajr"
    }

    private func theme(for prayer: String) -> Theme {
        let colors = decode([String: Theme].self, forKey: "prayerFocus.themeColors.v1") ?? [:]
        if let theme = colors[prayer] { return theme }
        return Self.defaultThemes[prayer] ?? Theme(backgroundHex: "103783", foregroundHex: "FFFFFF")
    }

    private func displayName(for prayer: String) -> String {
        switch prayer {
        case "fajr": "Fajr"
        case "dhuhr": "Dhuhr"
        case "asr": "Asr"
        case "maghrib": "Maghrib"
        case "isha": "Isha"
        default: "Prayer"
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Fallback set2 chromatic sky stops (not pale tops that read as white).
    private static let defaultThemes: [String: Theme] = [
        "fajr": Theme(backgroundHex: "103783", foregroundHex: "FFFFFF"),
        "dhuhr": Theme(backgroundHex: "60EFFF", foregroundHex: "111111"),
        "asr": Theme(backgroundHex: "60EFFF", foregroundHex: "111111"),
        "maghrib": Theme(backgroundHex: "E786A7", foregroundHex: "111111"),
        "isha": Theme(backgroundHex: "00458E", foregroundHex: "FFFFFF"),
    ]
}

private extension UIColor {
    convenience init?(rgbHex: String) {
        let hex = rgbHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
