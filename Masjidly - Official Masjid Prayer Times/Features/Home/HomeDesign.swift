import SwiftUI

enum HomeDesign {
    enum TimeTheme: String, CaseIterable {
        case fajr, sunrise, dhuhr, asr, maghrib, isha, tahajjud
        
        var gradient: Gradient {
            switch self {
            case .fajr: return Gradient(colors: [Color(hex: "DDF7FF"), Color(hex: "A9D8FF"), Color(hex: "B8A5F2"), Color(hex: "F5B9C8")])
            case .sunrise: return Gradient(colors: [Color(hex: "DFFBFF"), Color(hex: "FFE8A3"), Color(hex: "FFB16D"), Color(hex: "F87878")])
            case .dhuhr: return Gradient(colors: [Color(hex: "E8FAFF"), Color(hex: "8EDBFF"), Color(hex: "38BDF8")])
            case .asr: return Gradient(colors: [Color(hex: "22D3EE"), Color(hex: "4ADEDE"), Color(hex: "B8EFAE"), Color(hex: "F6D98B")])
            case .maghrib: return Gradient(colors: [Color(hex: "E9B7FF"), Color(hex: "F7A1D5"), Color(hex: "FF7C93"), Color(hex: "FFB066")])
            case .isha: return Gradient(colors: [Color(hex: "111827"), Color(hex: "1E1B4B"), Color(hex: "060712")])
            case .tahajjud: return Gradient(colors: [Color(hex: "0B1026"), Color(hex: "11143A"), Color(hex: "030712")])
            }
        }
        
        var textColor: Color {
            switch self {
            case .isha, .tahajjud: return .white
            default: return Color(hex: "111111")
            }
        }
        
        var iconColor: Color {
            return textColor
        }
    }

    enum Typography {
        /// Masjidly’s single voice: **SF Pro Rounded** — default to lighter weights so type matches thin line-art icons.
        static func app(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.system(size: size, weight: weight, design: .rounded)
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
