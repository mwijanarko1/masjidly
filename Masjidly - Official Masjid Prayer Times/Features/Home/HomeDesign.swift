import SwiftUI

enum HomeDesign {
    enum TimeTheme {
        case dawn, day, dusk, night, weather
        
        var gradient: Gradient {
            switch self {
            case .dawn:
                return Gradient(colors: [Color(hex: "4A5EAD"), Color(hex: "95669F")])
            case .day:
                return Gradient(colors: [Color(hex: "2F75D6"), Color(hex: "12385A")])
            case .dusk:
                return Gradient(colors: [Color(hex: "B96B24"), Color(hex: "5B2D16")])
            case .night:
                return Gradient(colors: [Color(hex: "0A1220"), Color(hex: "050810")])
            case .weather:
                return Gradient(colors: [Color.white, Color(hex: "F8F9FB")])
            }
        }
        
        var glowColor: Color {
            switch self {
            case .dawn: return Color(hex: "95669F").opacity(0.3)
            case .day: return Color(hex: "2F75D6").opacity(0.3)
            case .dusk: return Color(hex: "F6C15A").opacity(0.3)
            case .night: return Color(hex: "4A5EAD").opacity(0.2)
            case .weather: return Color(hex: "47A6FF").opacity(0.15)
            }
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
