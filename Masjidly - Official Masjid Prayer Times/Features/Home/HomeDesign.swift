import SwiftUI

enum HomeDesign {
    struct SkyTheme {
        let baseColors: [Color]
        let glowColor: Color?
    }

    enum TimeTheme: String, CaseIterable {
        case fajr, sunrise, dhuhr, asr, maghrib, isha, tahajjud
        
        var sky: SkyTheme {
            switch self {
            case .fajr: 
                return SkyTheme(baseColors: [Color(hex: "020326"), Color(hex: "06114F"), Color(hex: "0B1E6D"), Color(hex: "3B2A5A")], glowColor: Color(hex: "F08A4B"))
            case .sunrise:
                return SkyTheme(baseColors: [Color(hex: "6B7280"), Color(hex: "C084FC"), Color(hex: "FB923C"), Color(hex: "F59E0B")], glowColor: Color(hex: "FEF08A"))
            case .dhuhr:
                return SkyTheme(baseColors: [Color(hex: "E0F2FE"), Color(hex: "7DD3FC"), Color(hex: "38BDF8")], glowColor: Color(hex: "38BDF8").opacity(0.2))
            case .asr:
                return SkyTheme(baseColors: [Color(hex: "93C5FD"), Color(hex: "FDE68A"), Color(hex: "FDBA74")], glowColor: Color(hex: "D6B38A"))
            case .maghrib:
                return SkyTheme(baseColors: [Color(hex: "6D3FA9"), Color(hex: "A855F7"), Color(hex: "F472B6"), Color(hex: "FB7185")], glowColor: Color(hex: "F59E0B"))
            case .isha:
                return SkyTheme(baseColors: [Color(hex: "000000"), Color(hex: "020617"), Color(hex: "0F172A")], glowColor: Color(hex: "0F172A").opacity(0.4))
            case .tahajjud:
                return SkyTheme(baseColors: [Color(hex: "000000"), Color(hex: "01030A"), Color(hex: "020617")], glowColor: nil)
            }
        }
        
        var gradient: Gradient {
            Gradient(colors: sky.baseColors)
        }
        
        var textColor: Color {
            switch self {
            case .fajr, .isha, .tahajjud: return .white
            default: return Color(hex: "111111")
            }
        }
        
        var iconColor: Color {
            return textColor
        }

        /// Onboarding / glass surfaces: dark skies use light frost + white type; day themes use milky glass + dark type.
        var usesLightForeground: Bool {
            switch self {
            case .fajr, .isha, .tahajjud: return true
            default: return false
            }
        }
    }

    enum Typography {
        /// Masjidly’s single voice: **Comfortaa** — Matches the 3D, tubular, continuous rounded aesthetic of the logo perfectly.
        static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            // Mapping weights to Comfortaa font files. Ensure Comfortaa is added to Info.plist.
            let fontName: String
            switch weight {
            case .light, .thin, .ultraLight: fontName = "Comfortaa-Light"
            case .medium, .semibold: fontName = "Comfortaa-Medium"
            case .bold, .heavy, .black: fontName = "Comfortaa-Bold"
            default: fontName = "Comfortaa-Regular"
            }
            return Font.custom(fontName, size: size)
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
