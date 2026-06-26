import SwiftUI

enum HomeDesign {
    /// Per-prayer sky style. User-facing labels: **Original** (`.classic`), **Modern** (`.set2`), **Custom** (`.custom`).
    enum SkyGradientSet: String, CaseIterable, Identifiable, Codable, Sendable {
        case classic
        case set2
        case custom

        var id: String { rawValue }
    }

    struct CustomSkyGradientColors: Codable, Equatable, Sendable {
        var topHex: String
        var bottomHex: String

        var topColor: Color { Color(hex: topHex) }
        var bottomColor: Color { Color(hex: bottomHex) }

        static func defaults(for theme: TimeTheme) -> CustomSkyGradientColors {
            let sky = theme.sky(set: theme.defaultGradientSet())
            let top = sky.baseColors.first ?? .white
            let bottom = sky.baseColors.last ?? .black
            return CustomSkyGradientColors(topHex: top.hexRGBString(), bottomHex: bottom.hexRGBString())
        }
    }

    struct SkyRadialOverlay: Sendable {
        let center: UnitPoint
        let color: Color
        let opacity: Double
        let endRadiusFraction: CGFloat
    }

    /// Soft color pools that overlap to form a mesh-style sky (pastel themes).
    struct SkyColorBlob: Sendable {
        let center: UnitPoint
        let color: Color
        let opacity: Double
        let radiusFraction: CGFloat
    }

    struct SkyTheme {
        let baseColors: [Color]
        let gradientStops: [Gradient.Stop]?
        let glowColor: Color?
        let glowBaseAlpha: CGFloat
        let radialOverlays: [SkyRadialOverlay]
        let meshBlobs: [SkyColorBlob]
        let meshBaseColor: Color?

        init(
            baseColors: [Color],
            glowColor: Color?,
            glowBaseAlpha: CGFloat = 1.0,
            gradientStops: [Gradient.Stop]? = nil,
            radialOverlays: [SkyRadialOverlay] = [],
            meshBlobs: [SkyColorBlob] = [],
            meshBaseColor: Color? = nil
        ) {
            self.baseColors = baseColors
            self.gradientStops = gradientStops
            self.glowColor = glowColor
            self.glowBaseAlpha = glowBaseAlpha
            self.radialOverlays = radialOverlays
            self.meshBlobs = meshBlobs
            self.meshBaseColor = meshBaseColor
        }

        var usesMeshComposition: Bool { !meshBlobs.isEmpty }

        var resolvedGradient: Gradient {
            if let gradientStops {
                return Gradient(stops: gradientStops)
            }
            return Gradient(colors: baseColors)
        }

        var resolvedMeshBaseColor: Color {
            meshBaseColor ?? gradientStops?.first?.color ?? baseColors.first ?? .white
        }
    }

    struct ResolvedTheme {
        let timeTheme: TimeTheme
        let gradientSet: SkyGradientSet
        let customTopColor: Color?
        let customBottomColor: Color?

        init(
            timeTheme: TimeTheme,
            gradientSet: SkyGradientSet,
            customTopColor: Color? = nil,
            customBottomColor: Color? = nil
        ) {
            self.timeTheme = timeTheme
            self.gradientSet = gradientSet
            self.customTopColor = customTopColor
            self.customBottomColor = customBottomColor
        }

        var sky: SkyTheme {
            if gradientSet == .custom,
               let customTopColor,
               let customBottomColor {
                return SkyTheme(baseColors: [customTopColor, customBottomColor], glowColor: nil)
            }
            return timeTheme.sky(set: gradientSet)
        }

        var textColor: Color {
            if gradientSet == .custom,
               let customTopColor,
               let customBottomColor {
                return Self.textColorForCustomGradient(top: customTopColor, bottom: customBottomColor)
            }
            return timeTheme.textColor(set: gradientSet)
        }

        var iconColor: Color { textColor }
        var usesLightForeground: Bool { textColor == .white }
        var gradient: Gradient { sky.resolvedGradient }

        static func textColorForCustomGradient(top: Color, bottom: Color) -> Color {
            let luminance = (top.relativeLuminance + bottom.relativeLuminance) / 2
            return luminance < 0.45 ? .white : Color(hex: "111111")
        }

        /// Filled settings action rows (location recovery, etc.) — readable on both classic and pastel skies.
        var settingsActionButtonForeground: Color {
            usesLightForeground ? .white : textColor
        }

        var settingsActionButtonBackground: Color {
            usesLightForeground ? Color.white.opacity(0.22) : textColor.opacity(0.12)
        }
    }

    enum ThemeMode: String, CaseIterable, Identifiable {
        case dynamic
        case fixed

        var id: String { rawValue }
    }

    enum TimeTheme: String, CaseIterable, Identifiable {
        case fajr, sunrise, dhuhr, asr, maghrib, isha, tahajjud

        var id: String { rawValue }

        var sky: SkyTheme {
            sky(set: .set2)
        }

        func sky(set: SkyGradientSet) -> SkyTheme {
            switch set {
            case .classic:
                return classicSetSky
            case .set2:
                return set2Sky
            case .custom:
                return set2Sky
            }
        }

        func defaultGradientSet() -> SkyGradientSet {
            switch self {
            case .fajr, .sunrise, .asr, .maghrib, .isha:
                return .set2
            default:
                return .classic
            }
        }

        private var set2Sky: SkyTheme {
            switch self {
            case .fajr:
                return SkyTheme(baseColors: [Color(hex: "103783"), Color(hex: "8752A3")], glowColor: nil)
            case .sunrise:
                return set2SunriseSky
            case .dhuhr:
                return SkyTheme(baseColors: [Color(hex: "EBF4F5"), Color(hex: "60EFFF")], glowColor: nil)
            case .asr:
                return set2AsrSky
            case .maghrib:
                return SkyTheme(
                    baseColors: [
                        Color(hex: "F2D7D9"),
                        Color(hex: "E786A7"),
                    ],
                    glowColor: nil
                )
            case .isha:
                return SkyTheme(baseColors: [Color(hex: "000328"), Color(hex: "00458E")], glowColor: nil)
            default:
                return classicSetSky
            }
        }

        private var set2SunriseSky: SkyTheme {
            SkyTheme(
                baseColors: [
                    Color(hex: "07C8F9"),
                    Color(hex: "B597F6"),
                ],
                glowColor: nil
            )
        }

        private var set2AsrSky: SkyTheme {
            SkyTheme(
                baseColors: [
                    Color(hex: "60EFFF"),
                    Color(hex: "F3F98A"),
                ],
                glowColor: nil
            )
        }

        private var classicSetSky: SkyTheme {
            switch self {
            case .fajr:
                return SkyTheme(
                    baseColors: [Color(hex: "020326"), Color(hex: "06114F"), Color(hex: "0B1E6D"), Color(hex: "3B2A5A")],
                    glowColor: Color(hex: "F08A4B")
                )
            case .sunrise:
                return SkyTheme(
                    baseColors: [Color(hex: "6B7280"), Color(hex: "C084FC"), Color(hex: "FB923C"), Color(hex: "F59E0B")],
                    glowColor: Color(hex: "FEF08A")
                )
            case .dhuhr:
                return SkyTheme(baseColors: [Color(hex: "E0F2FE"), Color(hex: "7DD3FC"), Color(hex: "38BDF8")], glowColor: Color(hex: "38BDF8"), glowBaseAlpha: 0.2)
            case .asr:
                return SkyTheme(baseColors: [Color(hex: "93C5FD"), Color(hex: "FDE68A"), Color(hex: "FDBA74")], glowColor: Color(hex: "D6B38A"))
            case .maghrib:
                return SkyTheme(baseColors: [Color(hex: "6D3FA9"), Color(hex: "A855F7"), Color(hex: "F472B6"), Color(hex: "FB7185")], glowColor: Color(hex: "F59E0B"))
            case .isha:
                return SkyTheme(baseColors: [Color(hex: "000000"), Color(hex: "020617"), Color(hex: "0F172A")], glowColor: Color(hex: "0F172A"), glowBaseAlpha: 0.4)
            case .tahajjud:
                return SkyTheme(baseColors: [Color(hex: "000000"), Color(hex: "01030A"), Color(hex: "020617")], glowColor: nil)
            }
        }

        func textColor(set: SkyGradientSet) -> Color {
            switch set {
            case .classic:
                switch self {
                case .fajr, .maghrib, .isha, .tahajjud:
                    return .white
                default:
                    return Color(hex: "111111")
                }
            case .set2, .custom:
                switch self {
                case .fajr, .isha, .tahajjud:
                    return .white
                default:
                    return Color(hex: "111111")
                }
            }
        }

        func usesLightForeground(set: SkyGradientSet) -> Bool {
            textColor(set: set) == .white
        }

        var textColor: Color {
            textColor(set: .set2)
        }

        var iconColor: Color {
            textColor
        }

        var usesLightForeground: Bool {
            usesLightForeground(set: .set2)
        }

        private var pastelSky: SkyTheme {
            switch self {
            case .fajr:
                return SkyTheme(
                    baseColors: [Color(hex: "DFEFF8"), Color(hex: "A2ECF7"), Color(hex: "84B3F4"), Color(hex: "AB8DD6")],
                    glowColor: nil,
                    gradientStops: [
                        .init(color: Color(hex: "DFEFF8"), location: 0),
                        .init(color: Color(hex: "A2ECF7"), location: 0.26),
                        .init(color: Color(hex: "84B3F4"), location: 0.63),
                        .init(color: Color(hex: "AB8DD6"), location: 1),
                    ],
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.68, y: 0.08), color: Color(hex: "A2ECF7"), opacity: 0.45, endRadiusFraction: 0.38),
                    ],
                    meshBlobs: [
                        SkyColorBlob(center: UnitPoint(x: 0.10, y: 0.06), color: Color(hex: "DFEFF8"), opacity: 0.98, radiusFraction: 0.82),
                        SkyColorBlob(center: UnitPoint(x: 0.88, y: 0.10), color: Color(hex: "A2ECF7"), opacity: 0.92, radiusFraction: 0.72),
                        SkyColorBlob(center: UnitPoint(x: 0.42, y: 0.38), color: Color(hex: "84B3F4"), opacity: 0.88, radiusFraction: 0.90),
                        SkyColorBlob(center: UnitPoint(x: 0.78, y: 0.82), color: Color(hex: "AB8DD6"), opacity: 0.94, radiusFraction: 0.78),
                        SkyColorBlob(center: UnitPoint(x: 0.16, y: 0.72), color: Color(hex: "96A1EA"), opacity: 0.80, radiusFraction: 0.68),
                    ],
                    meshBaseColor: Color(hex: "DFEFF8")
                )
            case .sunrise:
                return SkyTheme(
                    baseColors: [Color(hex: "F7D7C4"), Color(hex: "F9BFA4"), Color(hex: "F6A6B8"), Color(hex: "A8D8F0")],
                    glowColor: nil,
                    gradientStops: [
                        .init(color: Color(hex: "F7D7C4"), location: 0),
                        .init(color: Color(hex: "F9BFA4"), location: 0.28),
                        .init(color: Color(hex: "F6A6B8"), location: 0.62),
                        .init(color: Color(hex: "A8D8F0"), location: 1),
                    ],
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.50, y: 0.12), color: Color(hex: "FFE6B4"), opacity: 0.50, endRadiusFraction: 0.32),
                        SkyRadialOverlay(center: UnitPoint(x: 0.22, y: 0.85), color: Color(hex: "A8D8F0"), opacity: 0.42, endRadiusFraction: 0.40),
                    ],
                    meshBlobs: [
                        SkyColorBlob(center: UnitPoint(x: 0.22, y: 0.10), color: Color(hex: "F7D7C4"), opacity: 0.96, radiusFraction: 0.76),
                        SkyColorBlob(center: UnitPoint(x: 0.62, y: 0.18), color: Color(hex: "F9BFA4"), opacity: 0.90, radiusFraction: 0.70),
                        SkyColorBlob(center: UnitPoint(x: 0.48, y: 0.52), color: Color(hex: "F6A6B8"), opacity: 0.88, radiusFraction: 0.85),
                        SkyColorBlob(center: UnitPoint(x: 0.82, y: 0.78), color: Color(hex: "A8D8F0"), opacity: 0.86, radiusFraction: 0.72),
                        SkyColorBlob(center: UnitPoint(x: 0.14, y: 0.80), color: Color(hex: "F2C4D0"), opacity: 0.78, radiusFraction: 0.62),
                    ],
                    meshBaseColor: Color(hex: "F7D7C4")
                )
            case .dhuhr:
                return SkyTheme(
                    baseColors: [Color(hex: "D6EFFA"), Color(hex: "DCEFFC"), Color(hex: "7CB5F0"), Color(hex: "62B1E0")],
                    glowColor: nil,
                    gradientStops: [
                        .init(color: Color(hex: "D6EFFA"), location: 0),
                        .init(color: Color(hex: "DCEFFC"), location: 0.22),
                        .init(color: Color(hex: "7CB5F0"), location: 0.65),
                        .init(color: Color(hex: "62B1E0"), location: 1),
                    ],
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.58, y: 0.05), color: Color(hex: "DCEFFC"), opacity: 0.45, endRadiusFraction: 0.38),
                    ],
                    meshBlobs: [
                        SkyColorBlob(center: UnitPoint(x: 0.14, y: 0.08), color: Color(hex: "D6EFFA"), opacity: 0.98, radiusFraction: 0.80),
                        SkyColorBlob(center: UnitPoint(x: 0.72, y: 0.12), color: Color(hex: "DCEFFC"), opacity: 0.94, radiusFraction: 0.74),
                        SkyColorBlob(center: UnitPoint(x: 0.50, y: 0.46), color: Color(hex: "7CB5F0"), opacity: 0.90, radiusFraction: 0.88),
                        SkyColorBlob(center: UnitPoint(x: 0.36, y: 0.84), color: Color(hex: "62B1E0"), opacity: 0.92, radiusFraction: 0.76),
                        SkyColorBlob(center: UnitPoint(x: 0.88, y: 0.70), color: Color(hex: "6AB9F8"), opacity: 0.78, radiusFraction: 0.64),
                    ],
                    meshBaseColor: Color(hex: "D6EFFA")
                )
            case .asr:
                return SkyTheme(
                    baseColors: [Color(hex: "9FF1F2"), Color(hex: "6CD4E4"), Color(hex: "73E1EA"), Color(hex: "BDE2BD")],
                    glowColor: nil,
                    gradientStops: [
                        .init(color: Color(hex: "9FF1F2"), location: 0),
                        .init(color: Color(hex: "6CD4E4"), location: 0.32),
                        .init(color: Color(hex: "73E1EA"), location: 0.62),
                        .init(color: Color(hex: "BDE2BD"), location: 1),
                    ],
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.18, y: 0.06), color: Color(hex: "9FF1F2"), opacity: 0.50, endRadiusFraction: 0.36),
                        SkyRadialOverlay(center: UnitPoint(x: 0.45, y: 0.88), color: Color(hex: "BDE2BD"), opacity: 0.45, endRadiusFraction: 0.42),
                    ],
                    meshBlobs: [
                        SkyColorBlob(center: UnitPoint(x: 0.20, y: 0.10), color: Color(hex: "9FF1F2"), opacity: 0.96, radiusFraction: 0.78),
                        SkyColorBlob(center: UnitPoint(x: 0.78, y: 0.14), color: Color(hex: "6CD4E4"), opacity: 0.92, radiusFraction: 0.72),
                        SkyColorBlob(center: UnitPoint(x: 0.52, y: 0.44), color: Color(hex: "73E1EA"), opacity: 0.90, radiusFraction: 0.86),
                        SkyColorBlob(center: UnitPoint(x: 0.30, y: 0.82), color: Color(hex: "BDE2BD"), opacity: 0.88, radiusFraction: 0.74),
                        SkyColorBlob(center: UnitPoint(x: 0.82, y: 0.76), color: Color(hex: "88E8E8"), opacity: 0.76, radiusFraction: 0.66),
                    ],
                    meshBaseColor: Color(hex: "9FF1F2")
                )
            case .maghrib:
                return SkyTheme(
                    baseColors: [Color(hex: "F2D7D9"), Color(hex: "E786A7")],
                    glowColor: nil,
                    gradientStops: [
                        .init(color: Color(hex: "F2D7D9"), location: 0),
                        .init(color: Color(hex: "E786A7"), location: 1),
                    ],
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.18, y: 0.04), color: Color(hex: "F2D7D9"), opacity: 0.48, endRadiusFraction: 0.38),
                    ],
                    meshBlobs: [
                        SkyColorBlob(center: UnitPoint(x: 0.16, y: 0.08), color: Color(hex: "F2D7D9"), opacity: 0.96, radiusFraction: 0.78),
                        SkyColorBlob(center: UnitPoint(x: 0.76, y: 0.82), color: Color(hex: "E786A7"), opacity: 0.92, radiusFraction: 0.76),
                        SkyColorBlob(center: UnitPoint(x: 0.20, y: 0.78), color: Color(hex: "F0C4D8"), opacity: 0.80, radiusFraction: 0.66),
                    ],
                    meshBaseColor: Color(hex: "F2D7D9")
                )
            case .isha:
                return SkyTheme(
                    baseColors: [Color(hex: "1D1939"), Color(hex: "1B122F"), Color(hex: "221A2E"), Color(hex: "050409")],
                    glowColor: nil,
                    gradientStops: [
                        .init(color: Color(hex: "1D1939"), location: 0),
                        .init(color: Color(hex: "1B122F"), location: 0.34),
                        .init(color: Color(hex: "221A2E"), location: 0.68),
                        .init(color: Color(hex: "050409"), location: 1),
                    ],
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.55, y: 0.35), color: Color(hex: "221A2E"), opacity: 0.55, endRadiusFraction: 0.45),
                    ],
                    meshBlobs: [
                        SkyColorBlob(center: UnitPoint(x: 0.50, y: 0.12), color: Color(hex: "1D1939"), opacity: 0.98, radiusFraction: 0.80),
                        SkyColorBlob(center: UnitPoint(x: 0.18, y: 0.38), color: Color(hex: "1B122F"), opacity: 0.94, radiusFraction: 0.72),
                        SkyColorBlob(center: UnitPoint(x: 0.72, y: 0.42), color: Color(hex: "221A2E"), opacity: 0.90, radiusFraction: 0.78),
                        SkyColorBlob(center: UnitPoint(x: 0.48, y: 0.78), color: Color(hex: "050409"), opacity: 0.96, radiusFraction: 0.84),
                        SkyColorBlob(center: UnitPoint(x: 0.82, y: 0.68), color: Color(hex: "2A2040"), opacity: 0.82, radiusFraction: 0.62),
                    ],
                    meshBaseColor: Color(hex: "1D1939")
                )
            case .tahajjud:
                return classicSetSky
            }
        }

        var gradient: Gradient {
            sky.resolvedGradient
        }
    }

    enum Typography {
        /// Masjidly’s primary voice: **Gill Sans** — A timeless, premium sans-serif that balances modern minimalism with classic elegance.
        static func app(size: CGFloat, weight: Font.Weight = .regular, name: String = "Gill Sans") -> Font {
            Font.custom(name, size: size).weight(weight)
        }

        /// Hero clock, prayer name, and other display lines.
        static func primary(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            app(size: size, weight: weight)
        }

        /// Iqamah caption under the hero adhan — light weight to match thin line icons.
        static func iqamahSubtitle(size: CGFloat = 26, weight: Font.Weight = .regular) -> Font {
            app(size: size, weight: weight)
        }
    }

    enum Colors {
        static let primary = Color(hex: "1D2433") // Navy/Black from weather app
        static let secondary = Color(hex: "9095A1") // Gray from weather app
        static let accent = Color(hex: "47A6FF") // Blue from weather app
        
        static let bgGradient = Gradient(colors: [
            Color.white,
            Color(hex: "F8F9FB")
        ])
        
        static let glassBackground = Color.white
        static let glassBorder = Color(hex: "F0F0F0")
        static let activeGradient = LinearGradient(
            gradient: Gradient(colors: [Color(hex: "47A6FF"), Color(hex: "2E8DFF")]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    enum Shadows {
        static let warmGlow = Shadow(color: Colors.accent.opacity(0.3), radius: 20, x: 0, y: 10)
        static let softCard = Shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
        static let intenseGlow = Shadow(color: Colors.accent.opacity(0.4), radius: 25, x: 0, y: 12)
    }
}

extension HomeDesign.TimeTheme {
    static let selectablePrayerThemes: [Self] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
    static let configurableGradientThemes: [Self] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

    /// Sky / glass theme for the home prayer hero (matches `HomeView` carousel selection).
    static func homeHeroTheme(displayedPrayerTimes: DailyPrayerTimes?, selectedPrayerIndex: Int) -> Self {
        guard displayedPrayerTimes != nil else { return .fajr }
        let prayers: [Self] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        guard selectedPrayerIndex >= 0, selectedPrayerIndex < prayers.count else { return .fajr }
        return prayers[selectedPrayerIndex]
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func customShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension Color {
    var relativeLuminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func channel(_ value: CGFloat) -> Double {
            let scaled = Double(value)
            return scaled <= 0.03928 ? scaled / 12.92 : pow((scaled + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    func hexRGBString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Dynamic Font Support

struct AppFontNameKey: EnvironmentKey {
    static let defaultValue: String = "Gill Sans"
}

extension EnvironmentValues {
    var appFontName: String {
        get { self[AppFontNameKey.self] }
        set { self[AppFontNameKey.self] = newValue }
    }
}

struct AppFontModifier: ViewModifier {
    @Environment(\.appFontName) var fontName
    @Environment(\.locale) var locale
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        let isArabic = locale.identifier.hasPrefix("ar")
        let isUrdu = locale.identifier.hasPrefix("ur")
        let scale: CGFloat = isUrdu ? 1.25 : (isArabic ? 1.20 : 1.00)
        content.font(HomeDesign.Typography.app(size: size * scale, weight: weight, name: fontName))
    }
}

extension View {
    func appFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(AppFontModifier(size: size, weight: weight))
    }
}

struct AtmosphericSkyBackground: View {
    let sky: HomeDesign.SkyTheme
    var height: CGFloat = 800

    var body: some View {
        GeometryReader { geo in
            let span = max(geo.size.width, geo.size.height)
            ZStack {
                if sky.usesMeshComposition {
                    meshSkyLayer(span: span)
                } else {
                    LinearGradient(
                        gradient: sky.resolvedGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                ForEach(Array(sky.radialOverlays.enumerated()), id: \.offset) { _, overlay in
                    RadialGradient(
                        colors: [overlay.color.opacity(overlay.opacity), overlay.color.opacity(overlay.opacity * 0.25), .clear],
                        center: overlay.center,
                        startRadius: 0,
                        endRadius: span * overlay.endRadiusFraction
                    )
                    .blendMode(.screen)
                }

                if let glow = sky.glowColor {
                    RadialGradient(
                        colors: [glow.opacity(0.6 * sky.glowBaseAlpha), glow.opacity(0.3 * sky.glowBaseAlpha), .clear],
                        center: UnitPoint(x: 0.5, y: 0.82),
                        startRadius: 0,
                        endRadius: max(geo.size.height, height) * 0.7
                    )
                    .blendMode(.screen)
                }

                if sky.usesMeshComposition {
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), .clear, Color.black.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.softLight)
                } else {
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.plusLighter)
                }
            }
        }
    }

    @ViewBuilder
    private func meshSkyLayer(span: CGFloat) -> some View {
        sky.resolvedMeshBaseColor

        ForEach(Array(sky.meshBlobs.enumerated()), id: \.offset) { _, blob in
            EllipticalGradient(
                stops: [
                    .init(color: blob.color.opacity(blob.opacity), location: 0),
                    .init(color: blob.color.opacity(blob.opacity * 0.55), location: 0.45),
                    .init(color: blob.color.opacity(0), location: 1),
                ],
                center: blob.center,
                startRadiusFraction: 0,
                endRadiusFraction: blob.radiusFraction * min(1.15, span / 800)
            )
        }

        LinearGradient(
            gradient: sky.resolvedGradient,
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)
        )
        .opacity(0.18)
        .blendMode(.softLight)
    }
}
