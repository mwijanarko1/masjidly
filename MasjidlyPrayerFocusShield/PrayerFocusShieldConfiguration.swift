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
        // Pick text from the tint itself (not the stored gradient-average hint) so custom skies stay readable.
        let usesLightForeground = Self.prefersLightForeground(on: background)
        let foreground: UIColor = usesLightForeground ? .white : UIColor(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255, alpha: 1)
        let name = displayName(for: prayer)

        // Apple applies backgroundColor as a tint on the blur; nil blur falls back to white.
        // Pin the material to the text's polarity: the adaptive material goes dark in system
        // dark mode and swallows dark text (and washes out white text in light mode).
        // Apple only fills one control (primary). Secondary is always text-style.
        return ShieldConfiguration(
            backgroundBlurStyle: usesLightForeground ? .systemThickMaterialDark : .systemThickMaterialLight,
            backgroundColor: background,
            // Without an explicit icon the system draws its own glyph in a fixed tint that ignores the sky.
            icon: icon(for: prayer, color: foreground),
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

    /// Same per-prayer symbols as the widgets, drawn in the shield's text color.
    private func icon(for prayer: String, color: UIColor) -> UIImage? {
        let symbolName = switch prayer {
        case "fajr": "sun.horizon.fill"
        case "dhuhr": "sun.max.fill"
        case "asr": "sun.dust.fill"
        case "maghrib": "sunset.fill"
        case "isha": "moon.stars.fill"
        default: "sun.max.fill"
        }
        let configuration = UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)
        return UIImage(systemName: symbolName, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
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

    /// Chooses white or near-black text, whichever has the higher WCAG contrast against `color`.
    private static func prefersLightForeground(on color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return true }
        func linear(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        let darkLuminance = linear(0x11 / 255)
        let contrastWithWhite = 1.05 / (luminance + 0.05)
        let contrastWithDark = (luminance + 0.05) / (darkLuminance + 0.05)
        return contrastWithWhite >= contrastWithDark
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
