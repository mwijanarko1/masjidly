import SwiftUI

// MARK: - Qibla compass (matches Expo `QiblaPrayerIcon` layout)

private enum QiblaPrayerIconLayout {
    static let frameRef: CGFloat = 120
}

/// Sun-phase icon with concentric rings and optional heading-relative Qibla pointer.
struct QiblaPrayerIcon: View {
    let theme: HomeDesign.TimeTheme
    /// When non-nil, triangle rotates with device heading toward Qibla.
    var rotationDegrees: Double?
    var size: CGFloat = 120

    @Environment(\.locale) private var locale

    private var scale: CGFloat { size / QiblaPrayerIconLayout.frameRef }

    private var color: Color { theme.iconColor }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.24), lineWidth: 1)
                .frame(width: 112 * scale, height: 112 * scale)
            Circle()
                .stroke(color.opacity(0.08), lineWidth: 0.8)
                .frame(width: 106 * scale, height: 106 * scale)

            PrayerSunPhaseIcon(theme: theme)
                .scaleEffect(scale)
                .offset(sunPhaseContentOffset)
                .accessibilityHidden(true)

            if let rotationDegrees {
                pointerOverlay(rotationDegrees: rotationDegrees)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(String(localized: String.LocalizationValue(stringLiteral: "qibla.icon_a11y"), bundle: .main, locale: locale)))
    }

    /// Matches Expo `getQiblaRingContentOffset` (then multiplied by `scale`).
    private var sunPhaseContentOffset: CGSize {
        let baseY: CGFloat = -6
        let down5 = QiblaPrayerIconLayout.frameRef * 0.05
        let y: CGFloat
        switch theme {
        case .fajr, .dhuhr, .asr, .isha:
            y = (baseY + down5) * scale
        case .sunrise, .maghrib, .tahajjud:
            y = baseY * scale
        }
        return CGSize(width: 0, height: y)
    }

    private func pointerOverlay(rotationDegrees: Double) -> some View {
        ZStack(alignment: .top) {
            Color.clear
            QiblaPointerTriangle(color: color, size: 12 * scale)
                .padding(.top, -10 * scale)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotationDegrees))
        .animation(.easeOut(duration: 0.2), value: rotationDegrees)
    }
}

private struct QiblaPointerTriangle: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Path { path in
            let s = size
            // Tip at top (rim); base toward center — same bearing as `QiblaDirectionProvider`, clearer than tip-at-bottom in SwiftUI layout.
            path.move(to: CGPoint(x: s / 2, y: 0))
            path.addLine(to: CGPoint(x: s, y: s))
            path.addLine(to: CGPoint(x: 0, y: s))
            path.closeSubpath()
        }
        .fill(color)
        .frame(width: size, height: size)
    }
}
