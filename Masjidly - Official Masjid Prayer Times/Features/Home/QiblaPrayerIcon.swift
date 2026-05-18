import SwiftUI

// MARK: - Qibla compass (matches Expo `QiblaPrayerIcon` layout)

private enum QiblaPrayerIconLayout {
    static let frameRef: CGFloat = 120
}

/// Sun-phase icon with concentric rings and optional heading-relative Qibla pointer.
/// When `showCountdown` is true, the center crossfades to countdown text and the ring shows `countdownProgress`; the Qibla pointer still follows `rotationDegrees`.
struct QiblaPrayerIcon: View {
    let theme: HomeDesign.TimeTheme
    /// When non-nil, triangle rotates with device heading toward Qibla (symbolic mode only).
    var rotationDegrees: Double?
    var size: CGFloat = 120

    var showCountdown: Bool = false
    var countdownLabel: String = ""
    var countdownTime: String = ""
    /// Elapsed fraction 0...1 for the countdown progress ring trim only.
    var countdownProgress: Double = 0

    @Environment(\.locale) private var locale

    private var scale: CGFloat { size / QiblaPrayerIconLayout.frameRef }

    private var color: Color { theme.iconColor }

    private var outerRingOpacity: Double { showCountdown ? 0.42 : 0.24 }

    private var pointerRotation: Double {
        rotationDegrees ?? 0
    }

    private var showPointer: Bool {
        rotationDegrees != nil
    }

    var body: some View {
        ZStack {
            if showCountdown {
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, max(0, countdownProgress))))
                    .stroke(color.opacity(0.38), style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
                    .frame(width: 112 * scale, height: 112 * scale)
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .stroke(color.opacity(outerRingOpacity), lineWidth: showCountdown ? 1.15 : 1)
                .frame(width: 112 * scale, height: 112 * scale)
            Circle()
                .stroke(color.opacity(0.08), lineWidth: 0.8)
                .frame(width: 106 * scale, height: 106 * scale)

            ZStack {
                PrayerSunPhaseIcon(theme: theme)
                    .scaleEffect(scale)
                    .offset(sunPhaseContentOffset)
                    .accessibilityHidden(true)
                    .opacity(showCountdown ? 0 : 1)

                VStack(spacing: 2 * scale) {
                    Text(countdownLabel)
                        .font(.system(size: 9 * scale, weight: .semibold, design: .default))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(color.opacity(0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(countdownTime)
                        .font(.system(size: 20 * scale, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(color.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 78 * scale)
                .offset(y: showCountdown ? 0 : 3 * scale)
                .opacity(showCountdown ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.22), value: showCountdown)

            if showPointer {
                pointerOverlay(rotationDegrees: pointerRotation)
                    .animation(.easeOut(duration: 0.2), value: pointerRotation)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabelResolved))
    }

    private var accessibilityLabelResolved: String {
        if showCountdown {
            let fmt = LocaleBundle.string(forKey: "home.countdown.a11y.active", locale: locale)
            return String(format: fmt, locale: locale, arguments: [countdownLabel, countdownTime])
        }
        return LocaleBundle.string(forKey: "qibla.icon_a11y", locale: locale)
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
            QiblaPointerTriangle(color: color.opacity(showCountdown ? 0.92 : 1), size: 12 * scale)
                .padding(.top, -10 * scale)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotationDegrees))
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
