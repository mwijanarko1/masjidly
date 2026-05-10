import SwiftUI
import UIKit

private func componentLS(_ key: String, locale: Locale) -> String {
    String(localized: String.LocalizationValue(stringLiteral: key), bundle: .main, locale: locale)
}

// MARK: - Components

struct StatusChip: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .foregroundColor(Color(hex: "58D66D"))
            Circle()
                .fill(Color(hex: "58D66D"))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: "58D66D").opacity(0.5), radius: 3)
        }
        .font(HomeDesign.Typography.app(size: 13, weight: .regular))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.2))
        .cornerRadius(20)
    }
}

struct HeroIllustration: View {
    /// Next salat name from `NextPrayerCountdownResult.nextName` (e.g. Fajr, Dhuhr, Jummah, Asr).
    let nextPrayerName: String
    @Environment(\.locale) private var locale

    private var assetName: String {
        switch nextPrayerName {
        case "Fajr": "FajrIllustration"
        case "Dhuhr", "Jummah": "DhuhrIllustration"
        case "Asr": "AsrIllustration"
        case "Maghrib": "MaghribIllustration"
        case "Isha": "IshaIllustration"
        default: "FajrIllustration"
        }
    }

    private var accessibilityLabelText: String {
        let key: String = switch nextPrayerName {
        case "Fajr": "illustration.fajr"
        case "Dhuhr": "illustration.dhuhr"
        case "Jummah": "illustration.jummah"
        case "Asr": "illustration.asr"
        case "Maghrib": "illustration.maghrib"
        case "Isha": "illustration.isha"
        default: "illustration.prayer_generic"
        }
        return componentLS(key, locale: locale)
    }

    /// When nil, uses design defaults for narrow phone width.
    var illustrationWidth: CGFloat?
    var illustrationHeight: CGFloat?
    var containerHeight: CGFloat?

    init(
        nextPrayerName: String,
        illustrationWidth: CGFloat? = nil,
        illustrationHeight: CGFloat? = nil,
        containerHeight: CGFloat? = nil
    ) {
        self.nextPrayerName = nextPrayerName
        self.illustrationWidth = illustrationWidth
        self.illustrationHeight = illustrationHeight
        self.containerHeight = containerHeight
    }

    private var resolvedImageWidth: CGFloat { illustrationWidth ?? 200 }
    private var resolvedImageHeight: CGFloat { illustrationHeight ?? 160 }
    private var resolvedContainerHeight: CGFloat { containerHeight ?? 200 }

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: resolvedImageWidth, height: resolvedImageHeight)
            .accessibilityLabel(accessibilityLabelText)
            .frame(height: resolvedContainerHeight)
    }
}

struct HeroContent: View {
    let prayerName: String
    let prayerTime: String
    let countdown: String
    let gregorianDate: String
    let hijriDate: String

    var timeFontSize: CGFloat = 96
    var nameFontSize: CGFloat = 28
    var stackSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: stackSpacing) {
            // Main Time
            Text(prayerTime)
                .font(HomeDesign.Typography.app(size: timeFontSize, weight: .light))
                .foregroundColor(HomeDesign.Colors.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(prayerName)
                .font(HomeDesign.Typography.app(size: nameFontSize, weight: .regular))
                .foregroundColor(HomeDesign.Colors.secondary)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

struct QuickInfoItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(HomeDesign.Typography.app(size: 24, weight: .light))
                .foregroundColor(HomeDesign.Colors.primary)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(HomeDesign.Typography.app(size: 16, weight: .medium))
                    .foregroundColor(HomeDesign.Colors.primary)
                Text(label)
                    .font(HomeDesign.Typography.app(size: 12, weight: .regular))
                    .foregroundColor(HomeDesign.Colors.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(24)
        .customShadow(HomeDesign.Shadows.softCard)
    }
}

struct PrayerCarouselItem: View {
    let name: String
    let time: String
    let icon: String
    let isSelected: Bool

    var cardWidth: CGFloat = 80
    var cardHeight: CGFloat = 110
    var timeFontSize: CGFloat = 14
    var iconFontSize: CGFloat = 34
    var nameFontSize: CGFloat = 12

    var body: some View {
        VStack(spacing: 8) {
            Text(time)
                .font(HomeDesign.Typography.app(size: timeFontSize, weight: .medium))
                .foregroundColor(isSelected ? .white : HomeDesign.Colors.primary)

            Image(systemName: icon)
                .font(HomeDesign.Typography.app(size: iconFontSize, weight: .light))
                .foregroundColor(isSelected ? .white : HomeDesign.Colors.accent)
                .symbolVariant(.fill)

            Text(name)
                .font(HomeDesign.Typography.app(size: nameFontSize, weight: .regular))
                .foregroundColor(isSelected ? .white : HomeDesign.Colors.secondary)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            ZStack {
                if isSelected {
                    HomeDesign.Colors.activeGradient
                        .customShadow(HomeDesign.Shadows.intenseGlow)
                } else {
                    Color.white
                }
            }
        )
        .cornerRadius(24)
        .customShadow(isSelected ? Shadow(color: .clear, radius: 0, x: 0, y: 0) : HomeDesign.Shadows.softCard)
    }
}

/// Refined line-art sun/moon icons per prayer time — each icon uses filled shapes with subtle opacity,
/// graduated ray patterns, and balanced proportions for a premium, elegant feel.
struct PrayerSunPhaseIcon: View {
    let theme: HomeDesign.TimeTheme
    @Environment(\.locale) private var locale

    private static let canvas = CGSize(width: 100, height: 88)

    var body: some View {
        Canvas { context, size in
            let color = theme.iconColor
            let thin = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            let medium = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            let cx = size.width * 0.5

            switch theme {
            case .fajr:
                Self.drawFajr(context: context, cx: cx, size: size, color: color, thin: thin, medium: medium)
            case .sunrise:
                Self.drawSunrise(context: context, cx: cx, size: size, color: color, thin: thin, medium: medium)
            case .dhuhr:
                Self.drawDhuhr(context: context, cx: cx, size: size, color: color, thin: thin, medium: medium)
            case .asr:
                Self.drawAsr(context: context, cx: cx, size: size, color: color, thin: thin, medium: medium)
            case .maghrib:
                Self.drawMaghrib(context: context, cx: cx, size: size, color: color, thin: thin, medium: medium)
            case .isha, .tahajjud:
                Self.drawIsha(context: context, cx: cx, size: size, color: color, thin: thin, medium: medium)
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        let key: String = switch theme {
        case .fajr: "sun_phase.dawn"
        case .sunrise: "sun_phase.sunrise"
        case .dhuhr: "sun_phase.midday"
        case .asr: "sun_phase.afternoon"
        case .maghrib: "sun_phase.sunset"
        case .isha, .tahajjud: "sun_phase.crescent"
        }
        return componentLS(key, locale: locale)
    }

    // MARK: - Helpers

    /// Draws a 4-point star/sparkle path.
    private static func fourPointStarPath(cx: CGFloat, cy: CGFloat, size: CGFloat) -> Path {
        var p = Path()
        let c = size * 0.25 // control point offset
        p.move(to: CGPoint(x: cx, y: cy - size))
        p.addQuadCurve(to: CGPoint(x: cx + size, y: cy), control: CGPoint(x: cx + c, y: cy - c))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy + size), control: CGPoint(x: cx + c, y: cy + c))
        p.addQuadCurve(to: CGPoint(x: cx - size, y: cy), control: CGPoint(x: cx - c, y: cy + c))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy - size), control: CGPoint(x: cx - c, y: cy - c))
        return p
    }

    // MARK: - Drawing

    /// Fajr — Night's end: A single small star with a very thin horizontal line underneath it.
    private static func drawFajr(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let baseY = size.height * 0.62
        let lineHalf: CGFloat = 16

        // Very thin horizontal line
        var horizon = Path()
        horizon.move(to: CGPoint(x: cx - lineHalf, y: baseY))
        horizon.addLine(to: CGPoint(x: cx + lineHalf, y: baseY))
        context.stroke(horizon, with: .color(color), style: thin)

        // Single small star above it
        let star = fourPointStarPath(cx: cx, cy: baseY - 14, size: 6)
        context.stroke(star, with: .color(color), style: thin)
    }

    /// Sunrise — Rising sun: A semicircle emerging above a horizontal line, with three short upward rays above it.
    private static func drawSunrise(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let baseY = size.height * 0.62
        let r: CGFloat = 14
        let lineHalf: CGFloat = 32

        // Horizon line
        var horizon = Path()
        horizon.move(to: CGPoint(x: cx - lineHalf, y: baseY))
        horizon.addLine(to: CGPoint(x: cx + lineHalf, y: baseY))
        context.stroke(horizon, with: .color(color), style: medium)

        // Semicircle stroke
        var sunStroke = Path()
        sunStroke.addArc(center: CGPoint(x: cx, y: baseY), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        context.stroke(sunStroke, with: .color(color), style: medium)

        // Three rays above the sun (-135, -90, -45)
        let gap: CGFloat = 6
        let rayLen: CGFloat = 8
        let angles: [Double] = [-135, -90, -45]
        for deg in angles {
            let rad = deg * .pi / 180
            let startR = r + gap
            let endR = r + gap + rayLen
            var ray = Path()
            ray.move(to: CGPoint(x: cx + cos(rad) * startR, y: baseY + sin(rad) * startR))
            ray.addLine(to: CGPoint(x: cx + cos(rad) * endR, y: baseY + sin(rad) * endR))
            context.stroke(ray, with: .color(color), style: medium)
        }
    }

    /// Dhuhr — Sunburst: A circle with short straight rays around it.
    private static func drawDhuhr(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let cy = size.height * 0.48
        let r: CGFloat = 12

        // Circle stroke
        var circle = Path()
        circle.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        context.stroke(circle, with: .color(color), style: medium)

        // 8 straight rays around
        let gap: CGFloat = 6
        let len: CGFloat = 8
        for i in 0..<8 {
            let angle = Double(i) * 45.0 * .pi / 180.0
            let startR = r + gap
            let endR = r + gap + len
            var ray = Path()
            ray.move(to: CGPoint(x: cx + cos(angle) * startR, y: cy + sin(angle) * startR))
            ray.addLine(to: CGPoint(x: cx + cos(angle) * endR, y: cy + sin(angle) * endR))
            context.stroke(ray, with: .color(color), style: medium)
        }
    }

    /// Asr — Shadow marker: A short vertical line with a long diagonal shadow extending from its base.
    private static func drawAsr(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let cy = size.height * 0.48
        let bodyH: CGFloat = 14
        let top = cy - bodyH * 0.5
        let bottom = cy + bodyH * 0.5
        let startX = cx - 10

        // Short vertical line (the body)
        var post = Path()
        post.move(to: CGPoint(x: startX, y: top))
        post.addLine(to: CGPoint(x: startX, y: bottom))
        context.stroke(post, with: .color(color), style: medium)

        // Long diagonal shadow line (length > body height)
        var shadow = Path()
        shadow.move(to: CGPoint(x: startX, y: bottom))
        shadow.addLine(to: CGPoint(x: startX + 28, y: bottom + 8))
        context.stroke(shadow, with: .color(color), style: thin)
    }

    /// Maghrib — Sunset arrow: A semicircle touching a horizontal line, with a small downward arrow above it pointing toward the horizon.
    private static func drawMaghrib(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let baseY = size.height * 0.52
        let r: CGFloat = 14
        let lineHalf: CGFloat = 32

        // Horizon line
        var horizon = Path()
        horizon.move(to: CGPoint(x: cx - lineHalf, y: baseY))
        horizon.addLine(to: CGPoint(x: cx + lineHalf, y: baseY))
        context.stroke(horizon, with: .color(color), style: medium)

        // Semicircle sitting on the horizon
        var sunStroke = Path()
        sunStroke.addArc(center: CGPoint(x: cx, y: baseY), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        context.stroke(sunStroke, with: .color(color), style: medium)

        // Downward arrow above the sun
        let arrowY = baseY - r - 4
        var arrow = Path()
        // Vertical line
        arrow.move(to: CGPoint(x: cx, y: arrowY - 8))
        arrow.addLine(to: CGPoint(x: cx, y: arrowY))
        // Arrow head
        arrow.move(to: CGPoint(x: cx - 3, y: arrowY - 3))
        arrow.addLine(to: CGPoint(x: cx, y: arrowY))
        arrow.addLine(to: CGPoint(x: cx + 3, y: arrowY - 3))
        
        // Arrow stroke
        context.stroke(arrow, with: .color(color), style: thin)
    }

    /// Isha — Night star: Three small outlined stars: one larger four-point star with two smaller dots or tiny stars beside it.
    private static func drawIsha(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let cy = size.height * 0.48

        // One larger four-point star
        let mainStar = fourPointStarPath(cx: cx - 4, cy: cy, size: 8)
        context.stroke(mainStar, with: .color(color), style: medium)

        // Two smaller dots or tiny stars beside it
        let star2 = fourPointStarPath(cx: cx + 12, cy: cy - 6, size: 4)
        context.stroke(star2, with: .color(color), style: thin)

        let star3 = fourPointStarPath(cx: cx + 10, cy: cy + 8, size: 3)
        context.stroke(star3, with: .color(color), style: thin)
    }
}

struct MinimalistPrayerPage: View {
    let prayerName: String
    let prayerTime: String
    /// Iqamah line below adhan (e.g. `Iqamah: 9:00pm`; repeats adhan time when iqamah is at adhan).
    let iqamahTime: String?
    let theme: HomeDesign.TimeTheme
    /// Full prayer names (same order as shortcuts); used for accessibility.
    let prayerLabels: [String]
    let selectedIndex: Int
    let totalCount: Int
    let onSelectPrayer: (Int) -> Void
    var highlightedShortcutIndex: Int? = nil
    var onShortcutTapped: ((Int) -> Void)? = nil

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 140)

            PrayerSunPhaseIcon(theme: theme)
                .padding(.bottom, 60)

            VStack(spacing: 6) {
                Text(prayerTime)
                    .font(HomeDesign.Typography.primary(size: 88, weight: .light))
                    .kerning(-1.76) // -0.02em * 88
                    .foregroundColor(theme.textColor)
                    .shadow(color: theme.textColor.opacity(0.1), radius: 10, x: 0, y: 5)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if let iq = iqamahTime, !iq.isEmpty {
                    Text(iq)
                        .font(HomeDesign.Typography.iqamahSubtitle(size: 26, weight: .regular))
                        .tracking(0.6)
                        .foregroundColor(theme.textColor.opacity(0.78))
                        .minimumScaleFactor(0.65)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(spacing: 24) {
                Text(prayerName)
                    .font(HomeDesign.Typography.primary(size: 36, weight: .regular))
                    .kerning(-0.36) // -0.01em * 36
                    .foregroundColor(theme.textColor)

                prayerLetterPicker
            }
            .padding(.bottom, 160)
        }
    }

    private func carouselA11yLabel(nameLabel: String, letter: String, index: Int) -> String {
        let template = componentLS("carousel.a11y", locale: locale)
        return String(format: template, locale: locale, arguments: [nameLabel, letter, index + 1, totalCount])
    }

    /// Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha — matches `HomeView` prayer order.
    private static let prayerShortcutLetters = ["F", "S", "D", "A", "M", "I"]
    private static let prayerShortcutIdentifiers = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]

    private func shortcutLetter(for index: Int) -> String {
        if index >= 0, index < Self.prayerShortcutLetters.count {
            return Self.prayerShortcutLetters[index]
        }
        if index < prayerLabels.count {
            return String(prayerLabels[index].prefix(1)).uppercased()
        }
        return "?"
    }

    private func shortcutAccessibilityIdentifier(for index: Int) -> String {
        guard index >= 0, index < Self.prayerShortcutIdentifiers.count else {
            return "PrayerShortcut.\(index)"
        }
        return "PrayerShortcut.\(Self.prayerShortcutIdentifiers[index])"
    }

    private var prayerLetterPicker: some View {
        ScrollViewReader { proxy in
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 14) {
                            ForEach(0..<totalCount, id: \.self) { index in
                                let fallbackTemplate = componentLS("carousel.prayer_fallback", locale: locale)
                                let nameLabel = index < prayerLabels.count
                                    ? prayerLabels[index]
                                    : String(format: fallbackTemplate, locale: locale, arguments: [index + 1])
                                let letter = shortcutLetter(for: index)
                                let isSelected = index == selectedIndex
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.prepare()
                                    generator.impactOccurred()
                                    onShortcutTapped?(index)
                                    onSelectPrayer(index)
                                } label: {
                                    Text(letter)
                                        .font(HomeDesign.Typography.app(size: 20, weight: isSelected ? .semibold : .regular))
                                        .foregroundColor(theme.textColor.opacity(isSelected ? 1.0 : 0.38))
                                        .frame(minWidth: 28, minHeight: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onboardingHighlight(highlightedShortcutIndex == index)
                                .id(index)
                                .accessibilityIdentifier(shortcutAccessibilityIdentifier(for: index))
                                .accessibilityLabel(carouselA11yLabel(nameLabel: nameLabel, letter: letter, index: index))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .frame(minWidth: geo.size.width)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedIndex, anchor: .center)
                }
            }
            .frame(height: 48)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Utilities

enum DateUtils {
    static func hijriDateString(for date: Date) -> String {
        let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.calendar = islamicCalendar
        formatter.dateFormat = "d MMMM yyyy 'AH'"
        return formatter.string(from: date)
    }
    
    static func currentLocalTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
