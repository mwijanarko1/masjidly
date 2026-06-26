import SwiftUI
import UIKit
import WidgetKit

@main
struct MasjidlyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MasjidlyPrayerWidget()
    }
}

struct MasjidlyPrayerWidget: Widget {
    let kind = "MasjidlyPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MasjidlyPrayerTimelineProvider()) { entry in
            MasjidlyPrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Masjidly")
        .description("Shows the next prayer and adhan time for your selected masjid.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct MasjidlyPrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MasjidlyPrayerEntry {
        MasjidlyPrayerEntry(date: Date(), state: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MasjidlyPrayerEntry) -> Void) {
        completion(entry(for: Date(), includeTomorrowFajr: shouldIncludeTomorrowFajr(for: context.family)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MasjidlyPrayerEntry>) -> Void) {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        guard let snapshot = MasjidlyWidgetSnapshotStore().readSnapshot() else {
            completion(Timeline(entries: [entry(for: now)], policy: .after(now.addingTimeInterval(1_800))))
            return
        }

        let includeTomorrowFajr = shouldIncludeTomorrowFajr(for: context.family)
        let state = MasjidlyWidgetResolver.resolve(snapshot: snapshot, now: now, includeTomorrowFajr: includeTomorrowFajr)
        let locale = AppLanguage(persistedRawValue: snapshot.appLanguageRawValue).resolvedLocale()

        guard state.kind == .content, let target = state.targetDate else {
            completion(Timeline(entries: [MasjidlyPrayerEntry(date: now, state: state, locale: locale)], policy: .after(now.addingTimeInterval(1_800))))
            return
        }

        let untilAdhan = target.timeIntervalSince(now)

        if untilAdhan > 0, untilAdhan < 2 * 3_600 {
            let startOfMinute = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)) ?? now
            let minuteCount = min(max(Int(ceil(untilAdhan / 60)) + 20, 8), 90)
            var entries: [MasjidlyPrayerEntry] = (0..<minuteCount).compactMap { offset in
                guard let d = calendar.date(byAdding: .minute, value: offset, to: startOfMinute) else { return nil }
                return MasjidlyPrayerEntry(date: d, state: MasjidlyWidgetResolver.resolve(snapshot: snapshot, now: d, includeTomorrowFajr: includeTomorrowFajr), locale: locale)
            }
            if entries.isEmpty {
                entries = [MasjidlyPrayerEntry(date: now, state: state, locale: locale)]
            }
            let reload = entries.last?.date ?? now
            completion(Timeline(entries: entries, policy: .after(reload)))
            return
        }

        let entry = MasjidlyPrayerEntry(date: now, state: state, locale: locale)
        let refresh = min(max(now.addingTimeInterval(1_800), target.addingTimeInterval(30)), now.addingTimeInterval(3_600))
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func shouldIncludeTomorrowFajr(for family: WidgetFamily) -> Bool {
        switch family {
        case .systemMedium, .systemLarge:
            return false
        default:
            return true
        }
    }

    private func entry(for date: Date, includeTomorrowFajr: Bool = true) -> MasjidlyPrayerEntry {
        guard let snapshot = MasjidlyWidgetSnapshotStore().readSnapshot() else {
            return MasjidlyPrayerEntry(date: date, state: .missing)
        }
        let locale = AppLanguage(persistedRawValue: snapshot.appLanguageRawValue).resolvedLocale()
        return MasjidlyPrayerEntry(date: date, state: MasjidlyWidgetResolver.resolve(snapshot: snapshot, now: date, includeTomorrowFajr: includeTomorrowFajr), locale: locale)
    }
}

struct MasjidlyPrayerEntry: TimelineEntry {
    let date: Date
    let state: MasjidlyWidgetState
    let locale: Locale

    init(date: Date, state: MasjidlyWidgetState, locale: Locale = Locale(identifier: "en")) {
        self.date = date
        self.state = state
        self.locale = locale
    }
}

extension MasjidlyWidgetState {
    var iconName: String {
        switch prayerId.lowercased() {
        case "fajr": return "sun.horizon"
        case "sunrise": return "sunrise"
        case "dhuhr", "jummah": return "sun.max"
        case "asr": return "sun.dust"
        case "maghrib": return "sunset"
        case "isha": return "moon.stars"
        default: return "sun.max"
        }
    }
}

struct MasjidlyPrayerWidgetView: View {
    let entry: MasjidlyPrayerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let theme = MasjidlyWidgetTheme.resolvedTheme(for: entry.state.prayerId)
        let gradientSet = MasjidlyWidgetTheme.resolvedGradientSet(for: entry.state.prayerId)
        let customColors = MasjidlyWidgetTheme.resolvedCustomGradientColors(for: entry.state.prayerId)
        
        Group {
            if entry.state.kind != .content {
                unavailableView
            } else {
                switch family {
                case .systemSmall:
                    smallView(theme: theme, gradientSet: gradientSet, customColors: customColors)
                case .systemMedium:
                    mediumView(theme: theme, gradientSet: gradientSet, customColors: customColors)
                case .systemLarge:
                    largeView(theme: theme, gradientSet: gradientSet, customColors: customColors)
                case .accessoryInline:
                    Text(accessoryInlineText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .truncationMode(.tail)
                case .accessoryCircular:
                    accessoryCircularView
                case .accessoryRectangular:
                    accessoryRectangularView
                default:
                    smallView(theme: theme, gradientSet: gradientSet, customColors: customColors)
                }
            }
        }
        .environment(\.layoutDirection, widgetLayoutDirection)
        .containerBackground(for: .widget) {
            if isLockScreenAccessoryFamily {
                Color.clear
            } else if entry.state.kind != .content {
                Color(hex: "111111")
            } else {
                backgroundView(for: theme, gradientSet: gradientSet, customColors: customColors)
            }
        }
    }

    private var widgetLayoutDirection: LayoutDirection {
        let languageCode = String(entry.locale.identifier.prefix(2))
        return ["ar", "ur"].contains(languageCode) ? .rightToLeft : .leftToRight
    }

    private var isLockScreenAccessoryFamily: Bool {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular: true
        default: false
        }
    }

    @ViewBuilder
    private var unavailableView: some View {
        switch family {
        case .accessoryInline:
            Text(widgetLS("widget.open_masjidly_update", locale: entry.locale))
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "exclamationmark")
                    .widgetFont(.headline, locale: entry.locale)
                    .fontWeight(.semibold)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Masjidly")
                    .widgetFont(.headline, locale: entry.locale)
                    .lineLimit(1)
                Text(widgetLS("widget.open_app", locale: entry.locale))
                    .widgetFont(.caption, locale: entry.locale)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        default:
            errorView
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .widgetFont(.title3, locale: entry.locale)
                .foregroundStyle(.white)
            Text(widgetLS("widget.unavailable", locale: entry.locale))
                .widgetFont(size: 14, weight: .medium, locale: entry.locale)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(widgetLS("widget.open_app", locale: entry.locale))
                .widgetFont(.caption2, locale: entry.locale)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
    }

    @ViewBuilder
    private func backgroundView(
        for theme: MasjidlyWidgetTheme.TimeTheme,
        gradientSet: MasjidlyWidgetTheme.SkyGradientSet,
        customColors: MasjidlyWidgetTheme.CustomSkyGradientColors?
    ) -> some View {
        let sky: MasjidlyWidgetTheme.SkyTheme = {
            if gradientSet == .custom,
               let customColors {
                return MasjidlyWidgetTheme.SkyTheme(
                    baseColors: [customColors.topColor, customColors.bottomColor],
                    gradientStops: nil,
                    glowColor: nil,
                    radialOverlays: []
                )
            }
            return theme.sky(set: gradientSet)
        }()
        GeometryReader { geo in
            let span = max(geo.size.width, geo.size.height)
            ZStack {
                if sky.usesMeshComposition {
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
                            endRadiusFraction: blob.radiusFraction
                        )
                    }
                    LinearGradient(gradient: sky.resolvedGradient, startPoint: .top, endPoint: .bottom)
                        .opacity(0.18)
                        .blendMode(.softLight)
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

                if theme.showsStars(set: gradientSet) {
                    starField(in: geo.size, intensity: theme == .tahajjud ? 0.08 : 0.04)
                }

                if let glow = sky.glowColor {
                    RadialGradient(
                        colors: [glow.opacity(0.4), glow.opacity(0.15), .clear],
                        center: UnitPoint(x: 0.5, y: 0.85),
                        startRadius: 0,
                        endRadius: geo.size.height * 1.2
                    )
                    .blendMode(.screen)
                }

                LinearGradient(
                    colors: sky.usesMeshComposition
                        ? [Color.white.opacity(0.08), .clear, Color.black.opacity(0.04)]
                        : [Color.black.opacity(0.1), .clear, Color.black.opacity(0.05)],
                    startPoint: sky.usesMeshComposition ? .topLeading : .top,
                    endPoint: sky.usesMeshComposition ? .bottomTrailing : .bottom
                )
            }
        }
    }

    private func starField(in size: CGSize, intensity: Double) -> some View {
        Canvas { context, size in
            let count = 12
            for i in 0..<count {
                let x = CGFloat((sin(Double(i) * 123.45) + 1) / 2) * size.width
                let y = CGFloat((cos(Double(i) * 543.21) + 1) / 2) * size.height * 0.7
                let opacity = CGFloat((sin(Double(i) * 99.9) + 1) / 2) * intensity
                context.opacity = opacity
                let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
    }

    private func smallView(
        theme: MasjidlyWidgetTheme.TimeTheme,
        gradientSet: MasjidlyWidgetTheme.SkyGradientSet,
        customColors: MasjidlyWidgetTheme.CustomSkyGradientColors?
    ) -> some View {
        let textColor = MasjidlyWidgetTheme.resolvedWidgetTextColor(
            theme: theme,
            gradientSet: gradientSet,
            customColors: customColors
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.state.iconName)
                    .widgetFont(size: 16, weight: .medium, locale: entry.locale)
                    .foregroundStyle(textColor.opacity(0.8))
                Text(entry.state.prayerName)
                    .widgetFont(size: 15, weight: .medium, locale: entry.locale)
                    .foregroundStyle(textColor.opacity(0.75))
                    .lineLimit(1)
            }

            Text(entry.state.adhanTime)
                .widgetFont(size: 36, weight: .light, locale: entry.locale)
                .foregroundStyle(textColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.bottom, 2)

            if !entry.state.iqamahTime.isEmpty {
                Text(String(format: widgetLS("widget.iqamah_format", locale: entry.locale), entry.state.iqamahTime))
                    .widgetFont(size: 14, weight: .regular, locale: entry.locale)
                    .foregroundStyle(textColor.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private var currentDateMediumString: String {
        let formatter = DateFormatter()
        formatter.locale = entry.locale
        formatter.dateFormat = "EEEE · d MMM"
        return formatter.string(from: entry.state.displayDate)
    }

    private func mediumView(
        theme: MasjidlyWidgetTheme.TimeTheme,
        gradientSet: MasjidlyWidgetTheme.SkyGradientSet,
        customColors: MasjidlyWidgetTheme.CustomSkyGradientColors?
    ) -> some View {
        let textColor = MasjidlyWidgetTheme.resolvedWidgetTextColor(
            theme: theme,
            gradientSet: gradientSet,
            customColors: customColors
        )
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(entry.state.mosqueDisplayName)
                    .widgetFont(size: 13, weight: .semibold, locale: entry.locale)
                    .foregroundStyle(textColor.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 4)
                Text(currentDateMediumString.uppercased())
                    .widgetFont(size: 12, weight: .semibold, locale: entry.locale)
                    .kerning(0.8)
                    .foregroundStyle(textColor.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            HStack {
                Text(widgetLS("widget.prayer", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .leading)
                Text(widgetLS("widget.adhan", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .center)
                Text(widgetLS("widget.iqamah", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .widgetFont(size: 11, weight: .bold, locale: entry.locale)
            .foregroundStyle(textColor.opacity(0.35))
            .textCase(.uppercase)
            
            VStack(spacing: 6) {
                ForEach(entry.state.rows.prefix(6)) { row in
                    HStack {
                        Text(row.name)
                            .widgetFont(size: 20, weight: row.isNext ? .bold : .regular, locale: entry.locale)
                            .foregroundStyle(row.isPassed ? textColor.opacity(0.35) : textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        
                        Text(row.adhan)
                            .widgetFont(size: 20, weight: row.isNext ? .bold : .semibold, locale: entry.locale)
                            .monospacedDigit()
                            .foregroundStyle(row.isPassed ? textColor.opacity(0.35) : textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        HStack {
                            Spacer()
                            Text(row.iqamahs.joined(separator: ", "))
                                .widgetFont(size: 20, weight: .regular, locale: entry.locale)
                                .monospacedDigit()
                                .foregroundStyle(row.isPassed ? textColor.opacity(0.2) : textColor.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private var fullDateString: String {
        let formatter = DateFormatter()
        formatter.locale = entry.locale
        formatter.dateFormat = "MMMM, EEEE d"
        return formatter.string(from: entry.state.displayDate)
    }

    private func largeView(
        theme: MasjidlyWidgetTheme.TimeTheme,
        gradientSet: MasjidlyWidgetTheme.SkyGradientSet,
        customColors: MasjidlyWidgetTheme.CustomSkyGradientColors?
    ) -> some View {
        let textColor = MasjidlyWidgetTheme.resolvedWidgetTextColor(
            theme: theme,
            gradientSet: gradientSet,
            customColors: customColors
        )
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(entry.state.mosqueDisplayName)
                    .widgetFont(size: 16, weight: .semibold, locale: entry.locale)
                    .foregroundStyle(textColor.opacity(0.7))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 6)
                Text(fullDateString.uppercased())
                    .widgetFont(size: 13, weight: .semibold, locale: entry.locale)
                    .kerning(0.8)
                    .foregroundStyle(textColor.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            largeHeroCountdownView(textColor: textColor)
                .frame(maxWidth: .infinity)

            HStack {
                Text(widgetLS("widget.prayer", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .leading)
                Text(widgetLS("widget.adhan", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .center)
                Text(widgetLS("widget.iqamah", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .widgetFont(size: 12, weight: .bold, locale: entry.locale)
            .foregroundStyle(textColor.opacity(0.35))
            .textCase(.uppercase)

            VStack(spacing: 14) {
                ForEach(entry.state.rows) { row in
                    HStack {
                        Text(row.name)
                            .widgetFont(size: 24, weight: row.isNext ? .bold : .regular, locale: entry.locale)
                            .foregroundStyle(row.isPassed ? textColor.opacity(0.35) : textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Text(row.adhan)
                            .widgetFont(size: 24, weight: row.isNext ? .bold : .semibold, locale: entry.locale)
                            .monospacedDigit()
                            .foregroundStyle(row.isPassed ? textColor.opacity(0.35) : textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack {
                            Spacer()
                            Text(row.iqamahs.joined(separator: ", "))
                                .widgetFont(size: 24, weight: .regular, locale: entry.locale)
                                .monospacedDigit()
                                .foregroundStyle(row.isPassed ? textColor.opacity(0.2) : textColor.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private var accessoryCircularView: some View {
        let s = entry.state
        let target = s.targetDate
        let showLiveCountdown = target.map { $0 > entry.date } ?? false
        let isIqamah = s.iqamahDate != nil && s.targetDate == s.iqamahDate

        return ZStack {
            AccessoryWidgetBackground()
            accessoryCircularContent(
                state: s,
                target: target,
                showLiveCountdown: showLiveCountdown,
                isIqamah: isIqamah
            )
            .widgetAccessoryScaleToFit(designSize: CGSize(width: 54, height: 54))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .widgetAccentable()
    }

    @ViewBuilder
    private func accessoryCircularContent(
        state s: MasjidlyWidgetState,
        target: Date?,
        showLiveCountdown: Bool,
        isIqamah: Bool
    ) -> some View {
        VStack(spacing: 0) {
            if showLiveCountdown, let target {
                Text(accessoryCountdownCaption(prayerName: s.prayerName, isIqamah: isIqamah))
                    .widgetFont(size: 7, weight: .bold, locale: entry.locale)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .widgetFittingLine()
                    .frame(maxWidth: .infinity)
                accessoryCircularCountdownClock(target: target)
                    .padding(.top, 2)
            } else {
                Text(s.iqamahDate != nil && s.targetDate == s.iqamahDate ? s.iqamahTime : s.adhanTime)
                    .widgetFont(size: 15, weight: .semibold, locale: entry.locale)
                    .monospacedDigit()
                    .widgetFittingLine()
                Text(s.prayerName)
                    .widgetFont(size: 10, weight: .medium, locale: entry.locale)
                    .widgetFittingLine()
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 2)
    }

    private func accessoryCircularCountdownClock(target: Date) -> some View {
        let remaining = max(0, target.timeIntervalSince(entry.date))
        let underOneHour = remaining < 3_600
        let font = widgetUIFont(size: 14, weight: .bold)
        let timerLocale = Locale(identifier: "en_GB")
        let timerWidth = min(
            underOneHour ? widgetCountdownMMSSWidth(font: font) : widgetCountdownHMSWidth(font: font),
            48
        )

        return Group {
            if underOneHour {
                Text(timerInterval: entry.date...target, countsDown: true, showsHours: false)
            } else {
                Text(timerInterval: entry.date...target, countsDown: true, showsHours: true)
            }
        }
        .font(Font(font))
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .frame(width: timerWidth)
        .environment(\.locale, timerLocale)
        .widgetFittingLine()
    }

    private func accessoryCountdownCaption(prayerName: String, isIqamah: Bool, compact: Bool = false) -> String {
        let kind = widgetLS(
            isIqamah ? "widget.countdown.iqamah_in" : "widget.countdown.adhan_in",
            locale: entry.locale
        )
        if compact {
            return kind
        }
        return "\(prayerName) · \(kind)"
    }

    private var accessoryRectangularView: some View {
        accessoryRectangularContent
            .widgetAccessoryScaleToFit(designSize: CGSize(width: 168, height: 62))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .widgetAccentable()
    }

    private var accessoryRectangularContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.state.mosqueDisplayName)
                .widgetFont(size: 9, weight: .semibold, locale: entry.locale)
                .foregroundStyle(.secondary)
                .widgetFittingLine()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 1)

            ForEach(entry.state.rows.prefix(5)) { row in
                accessoryRectangularPrayerRow(row: row)
            }
        }
        .padding(.horizontal, 1)
    }

    private func accessoryRectangularPrayerRow(row: MasjidlyWidgetPrayerRow) -> some View {
        let isNext = row.isNext
        let isPassed = row.isPassed
        let timeWeight: Font.Weight = isNext ? .bold : .semibold
        let iqamahText = row.iqamahs.joined(separator: ", ")

        return HStack(spacing: 3) {
            Text(row.name)
                .widgetFont(size: 10, weight: isNext ? .bold : .medium, locale: entry.locale)
                .foregroundStyle(isNext ? .primary : (isPassed ? .tertiary : .secondary))
                .widgetFittingLine()
                .layoutPriority(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(row.adhan)
                .widgetFont(size: 10, weight: timeWeight, locale: entry.locale)
                .monospacedDigit()
                .foregroundStyle(isNext ? .primary : (isPassed ? .tertiary : .secondary))
                .widgetFittingLine()
                .layoutPriority(0)
                .frame(width: 44, alignment: .trailing)

            Text(iqamahText)
                .widgetFont(size: 10, weight: .regular, locale: entry.locale)
                .monospacedDigit()
                .foregroundStyle(isPassed ? .tertiary : .secondary)
                .widgetFittingLine()
                .layoutPriority(0)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var accessoryInlineText: String {
        let s = entry.state
        let now = entry.date
        if let t = s.targetDate {
            let until = t.timeIntervalSince(now)
            if until > 0, until <= 45 * 60 {
                return "\(s.mosqueDisplayName) · \(s.prayerName) \(countdownAbbrev(until: until))"
            }
        }
        return "\(s.mosqueDisplayName) · \(s.prayerName) \(s.adhanTime)"
    }

    private func largeHeroCountdownView(textColor: Color) -> some View {
        let state = entry.state
        let isIqamah = state.iqamahDate != nil && state.targetDate == state.iqamahDate
        let headline = widgetCountdownHeadline(
            prayerName: state.prayerName,
            isIqamah: isIqamah,
            locale: entry.locale
        )
        let showLiveCountdown = state.targetDate.map { $0 > entry.date } ?? false

        return VStack(alignment: .center, spacing: 4) {
            Text(headline)
                .widgetFont(size: 14, weight: .medium, locale: entry.locale)
                .foregroundStyle(textColor.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)

            if showLiveCountdown, let target = state.targetDate {
                largeHeroCountdownClock(target: target, textColor: textColor)
            } else {
                Text(state.adhanTime)
                    .widgetFont(size: 32, weight: .regular, locale: entry.locale)
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    /// Native WidgetKit countdown — `Text(timerInterval:)` ticks every second without per-second timeline entries.
    private func largeHeroCountdownClock(target: Date, textColor: Color) -> some View {
        let remaining = max(0, target.timeIntervalSince(entry.date))
        let underOneHour = remaining < 3_600
        let fontSize: CGFloat = 36
        let font = widgetUIFont(size: fontSize, weight: .medium)
        let timerLocale = Locale(identifier: "en_GB")

        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                if underOneHour {
                    Text("-00:")
                        .font(Font(font))
                        .foregroundStyle(textColor)
                    Text(timerInterval: entry.date...target, countsDown: true, showsHours: false)
                        .font(Font(font))
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                        .multilineTextAlignment(.leading)
                        .frame(width: widgetCountdownMMSSWidth(font: font), alignment: .leading)
                        .environment(\.locale, timerLocale)
                } else {
                    Text("-")
                        .font(Font(font))
                        .foregroundStyle(textColor)
                    Text(timerInterval: entry.date...target, countsDown: true, showsHours: true)
                        .font(Font(font))
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                        .multilineTextAlignment(.leading)
                        .frame(width: widgetCountdownHMSWidth(font: font), alignment: .leading)
                        .environment(\.locale, timerLocale)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity)
    }

    private func widgetCountdownMMSSWidth(font: UIFont) -> CGFloat {
        let sample = "59:59" as NSString
        return ceil(sample.size(withAttributes: [.font: font]).width) + 2
    }

    private func widgetCountdownHMSWidth(font: UIFont) -> CGFloat {
        let sample = "9:59:59" as NSString
        return ceil(sample.size(withAttributes: [.font: font]).width) + 2
    }

    private func countdownAbbrev(until seconds: TimeInterval) -> String {
        let s = max(0, seconds)
        let mins = Int(s / 60)
        let units = countdownUnits
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m == 0 ? "\(h)\(units.hour)" : "\(h)\(units.hour) \(m)\(units.minute)"
        }
        if mins > 0 { return "\(mins)\(units.minute)" }
        return "<1\(units.minute)"
    }

    private var countdownUnits: (hour: String, minute: String) {
        let languageCode = String(entry.locale.identifier.prefix(2))
        switch languageCode {
        case "ar": return ("س", "د")
        case "ur": return ("گ", "م")
        case "id": return ("j", "m")
        default: return ("h", "m")
        }
    }
}



enum MasjidlyWidgetTheme {
    /// User-facing labels: **Original** (`classic`), **Modern** (`set2`), **Custom** (`custom`).
    enum SkyGradientSet: String {
        case classic
        case set2
        case custom
    }

    struct CustomSkyGradientColors: Codable, Equatable, Sendable {
        var topHex: String
        var bottomHex: String

        var topColor: Color { Color(hex: topHex) }
        var bottomColor: Color { Color(hex: bottomHex) }
    }

    struct SkyRadialOverlay {
        let center: UnitPoint
        let color: Color
        let opacity: Double
        let endRadiusFraction: CGFloat
    }

    struct SkyColorBlob {
        let center: UnitPoint
        let color: Color
        let opacity: Double
        let radiusFraction: CGFloat
    }

    struct SkyTheme {
        let baseColors: [Color]
        let gradientStops: [Gradient.Stop]?
        let glowColor: Color?
        let radialOverlays: [SkyRadialOverlay]
        let meshBlobs: [SkyColorBlob]
        let meshBaseColor: Color?

        init(
            baseColors: [Color],
            gradientStops: [Gradient.Stop]?,
            glowColor: Color?,
            radialOverlays: [SkyRadialOverlay],
            meshBlobs: [SkyColorBlob] = [],
            meshBaseColor: Color? = nil
        ) {
            self.baseColors = baseColors
            self.gradientStops = gradientStops
            self.glowColor = glowColor
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

    static func pastelMesh(for theme: TimeTheme) -> (blobs: [SkyColorBlob], base: Color) {
        switch theme {
        case .fajr:
            return ([
                SkyColorBlob(center: UnitPoint(x: 0.10, y: 0.06), color: Color(hex: "DFEFF8"), opacity: 0.98, radiusFraction: 0.82),
                SkyColorBlob(center: UnitPoint(x: 0.88, y: 0.10), color: Color(hex: "A2ECF7"), opacity: 0.92, radiusFraction: 0.72),
                SkyColorBlob(center: UnitPoint(x: 0.42, y: 0.38), color: Color(hex: "84B3F4"), opacity: 0.88, radiusFraction: 0.90),
                SkyColorBlob(center: UnitPoint(x: 0.78, y: 0.82), color: Color(hex: "AB8DD6"), opacity: 0.94, radiusFraction: 0.78),
                SkyColorBlob(center: UnitPoint(x: 0.16, y: 0.72), color: Color(hex: "96A1EA"), opacity: 0.80, radiusFraction: 0.68),
            ], Color(hex: "DFEFF8"))
        case .sunrise:
            return ([
                SkyColorBlob(center: UnitPoint(x: 0.22, y: 0.10), color: Color(hex: "F7D7C4"), opacity: 0.96, radiusFraction: 0.76),
                SkyColorBlob(center: UnitPoint(x: 0.62, y: 0.18), color: Color(hex: "F9BFA4"), opacity: 0.90, radiusFraction: 0.70),
                SkyColorBlob(center: UnitPoint(x: 0.48, y: 0.52), color: Color(hex: "F6A6B8"), opacity: 0.88, radiusFraction: 0.85),
                SkyColorBlob(center: UnitPoint(x: 0.82, y: 0.78), color: Color(hex: "A8D8F0"), opacity: 0.86, radiusFraction: 0.72),
                SkyColorBlob(center: UnitPoint(x: 0.14, y: 0.80), color: Color(hex: "F2C4D0"), opacity: 0.78, radiusFraction: 0.62),
            ], Color(hex: "F7D7C4"))
        case .dhuhr:
            return ([
                SkyColorBlob(center: UnitPoint(x: 0.14, y: 0.08), color: Color(hex: "D6EFFA"), opacity: 0.98, radiusFraction: 0.80),
                SkyColorBlob(center: UnitPoint(x: 0.72, y: 0.12), color: Color(hex: "DCEFFC"), opacity: 0.94, radiusFraction: 0.74),
                SkyColorBlob(center: UnitPoint(x: 0.50, y: 0.46), color: Color(hex: "7CB5F0"), opacity: 0.90, radiusFraction: 0.88),
                SkyColorBlob(center: UnitPoint(x: 0.36, y: 0.84), color: Color(hex: "62B1E0"), opacity: 0.92, radiusFraction: 0.76),
                SkyColorBlob(center: UnitPoint(x: 0.88, y: 0.70), color: Color(hex: "6AB9F8"), opacity: 0.78, radiusFraction: 0.64),
            ], Color(hex: "D6EFFA"))
        case .asr:
            return ([
                SkyColorBlob(center: UnitPoint(x: 0.20, y: 0.10), color: Color(hex: "9FF1F2"), opacity: 0.96, radiusFraction: 0.78),
                SkyColorBlob(center: UnitPoint(x: 0.78, y: 0.14), color: Color(hex: "6CD4E4"), opacity: 0.92, radiusFraction: 0.72),
                SkyColorBlob(center: UnitPoint(x: 0.52, y: 0.44), color: Color(hex: "73E1EA"), opacity: 0.90, radiusFraction: 0.86),
                SkyColorBlob(center: UnitPoint(x: 0.30, y: 0.82), color: Color(hex: "BDE2BD"), opacity: 0.88, radiusFraction: 0.74),
                SkyColorBlob(center: UnitPoint(x: 0.82, y: 0.76), color: Color(hex: "88E8E8"), opacity: 0.76, radiusFraction: 0.66),
            ], Color(hex: "9FF1F2"))
        case .maghrib:
            return ([
                SkyColorBlob(center: UnitPoint(x: 0.16, y: 0.08), color: Color(hex: "F2D7D9"), opacity: 0.96, radiusFraction: 0.78),
                SkyColorBlob(center: UnitPoint(x: 0.76, y: 0.82), color: Color(hex: "E786A7"), opacity: 0.92, radiusFraction: 0.76),
                SkyColorBlob(center: UnitPoint(x: 0.20, y: 0.78), color: Color(hex: "F0C4D8"), opacity: 0.80, radiusFraction: 0.66),
            ], Color(hex: "F2D7D9"))
        case .isha:
            return ([
                SkyColorBlob(center: UnitPoint(x: 0.50, y: 0.12), color: Color(hex: "1D1939"), opacity: 0.98, radiusFraction: 0.80),
                SkyColorBlob(center: UnitPoint(x: 0.18, y: 0.38), color: Color(hex: "1B122F"), opacity: 0.94, radiusFraction: 0.72),
                SkyColorBlob(center: UnitPoint(x: 0.72, y: 0.42), color: Color(hex: "221A2E"), opacity: 0.90, radiusFraction: 0.78),
                SkyColorBlob(center: UnitPoint(x: 0.48, y: 0.78), color: Color(hex: "050409"), opacity: 0.96, radiusFraction: 0.84),
                SkyColorBlob(center: UnitPoint(x: 0.82, y: 0.68), color: Color(hex: "2A2040"), opacity: 0.82, radiusFraction: 0.62),
            ], Color(hex: "1D1939"))
        default:
            return ([], .white)
        }
    }

    enum TimeTheme: String {
        case fajr, sunrise, dhuhr, asr, maghrib, isha, tahajjud

        func defaultGradientSet() -> SkyGradientSet {
            switch self {
            case .fajr, .sunrise, .asr, .maghrib, .isha:
                return .set2
            default:
                return .classic
            }
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

        func showsStars(set: SkyGradientSet) -> Bool {
            switch set {
            case .classic, .set2, .custom:
                return self == .fajr || self == .isha || self == .tahajjud
            }
        }

        private var set2Sky: SkyTheme {
            switch self {
            case .fajr:
                return SkyTheme(
                    baseColors: [Color(hex: "103783"), Color(hex: "8752A3")],
                    gradientStops: nil,
                    glowColor: nil,
                    radialOverlays: []
                )
            case .sunrise:
                return SkyTheme(
                    baseColors: [
                        Color(hex: "07C8F9"),
                        Color(hex: "B597F6"),
                    ],
                    gradientStops: nil,
                    glowColor: nil,
                    radialOverlays: []
                )
            case .dhuhr:
                return SkyTheme(
                    baseColors: [Color(hex: "EBF4F5"), Color(hex: "60EFFF")],
                    gradientStops: nil,
                    glowColor: nil,
                    radialOverlays: []
                )
            case .asr:
                return SkyTheme(
                    baseColors: [
                        Color(hex: "60EFFF"),
                        Color(hex: "F3F98A"),
                    ],
                    gradientStops: nil,
                    glowColor: nil,
                    radialOverlays: []
                )
            case .maghrib:
                return SkyTheme(
                    baseColors: [
                        Color(hex: "F2D7D9"),
                        Color(hex: "E786A7"),
                    ],
                    gradientStops: nil,
                    glowColor: nil,
                    radialOverlays: []
                )
            case .isha:
                return SkyTheme(
                    baseColors: [Color(hex: "000328"), Color(hex: "00458E")],
                    gradientStops: nil,
                    glowColor: nil,
                    radialOverlays: []
                )
            default:
                return classicSetSky
            }
        }

        private var classicSetSky: SkyTheme {
            SkyTheme(
                baseColors: classicSkyColors,
                gradientStops: nil,
                glowColor: classicGlowColor,
                radialOverlays: []
            )
        }

        private var classicSkyColors: [Color] {
            switch self {
            case .fajr:
                return [Color(hex: "020326"), Color(hex: "06114F"), Color(hex: "0B1E6D"), Color(hex: "3B2A5A")]
            case .sunrise:
                return [Color(hex: "6B7280"), Color(hex: "C084FC"), Color(hex: "FB923C"), Color(hex: "F59E0B")]
            case .dhuhr:
                return [Color(hex: "E0F2FE"), Color(hex: "7DD3FC"), Color(hex: "38BDF8")]
            case .asr:
                return [Color(hex: "93C5FD"), Color(hex: "FDE68A"), Color(hex: "FDBA74")]
            case .maghrib:
                return [Color(hex: "6D3FA9"), Color(hex: "A855F7"), Color(hex: "F472B6"), Color(hex: "FB7185")]
            case .isha:
                return [Color(hex: "000000"), Color(hex: "020617"), Color(hex: "0F172A")]
            case .tahajjud:
                return [Color(hex: "000000"), Color(hex: "01030A"), Color(hex: "020617")]
            }
        }

        private var classicGlowColor: Color? {
            switch self {
            case .fajr: return Color(hex: "F08A4B")
            case .sunrise: return Color(hex: "FEF08A")
            case .dhuhr: return Color(hex: "38BDF8").opacity(0.2)
            case .asr: return Color(hex: "D6B38A")
            case .maghrib: return Color(hex: "F59E0B")
            case .isha: return Color(hex: "0F172A").opacity(0.4)
            case .tahajjud: return nil
            }
        }

        private var classicSky: SkyTheme {
            classicSetSky
        }

        private var pastelSky: SkyTheme {
            let mesh = MasjidlyWidgetTheme.pastelMesh(for: self)
            switch self {
            case .fajr:
                return SkyTheme(
                    baseColors: [Color(hex: "DFEFF8"), Color(hex: "A2ECF7"), Color(hex: "84B3F4"), Color(hex: "AB8DD6")],
                    gradientStops: [
                        .init(color: Color(hex: "DFEFF8"), location: 0),
                        .init(color: Color(hex: "A2ECF7"), location: 0.26),
                        .init(color: Color(hex: "84B3F4"), location: 0.63),
                        .init(color: Color(hex: "AB8DD6"), location: 1),
                    ],
                    glowColor: nil,
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.68, y: 0.08), color: Color(hex: "A2ECF7"), opacity: 0.45, endRadiusFraction: 0.38),
                    ],
                    meshBlobs: mesh.blobs,
                    meshBaseColor: mesh.base
                )
            case .sunrise:
                return SkyTheme(
                    baseColors: [Color(hex: "F7D7C4"), Color(hex: "F9BFA4"), Color(hex: "F6A6B8"), Color(hex: "A8D8F0")],
                    gradientStops: [
                        .init(color: Color(hex: "F7D7C4"), location: 0),
                        .init(color: Color(hex: "F9BFA4"), location: 0.28),
                        .init(color: Color(hex: "F6A6B8"), location: 0.62),
                        .init(color: Color(hex: "A8D8F0"), location: 1),
                    ],
                    glowColor: nil,
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.50, y: 0.12), color: Color(hex: "FFE6B4"), opacity: 0.50, endRadiusFraction: 0.32),
                        SkyRadialOverlay(center: UnitPoint(x: 0.22, y: 0.85), color: Color(hex: "A8D8F0"), opacity: 0.42, endRadiusFraction: 0.40),
                    ],
                    meshBlobs: mesh.blobs,
                    meshBaseColor: mesh.base
                )
            case .dhuhr:
                return SkyTheme(
                    baseColors: [Color(hex: "D6EFFA"), Color(hex: "DCEFFC"), Color(hex: "7CB5F0"), Color(hex: "62B1E0")],
                    gradientStops: [
                        .init(color: Color(hex: "D6EFFA"), location: 0),
                        .init(color: Color(hex: "DCEFFC"), location: 0.22),
                        .init(color: Color(hex: "7CB5F0"), location: 0.65),
                        .init(color: Color(hex: "62B1E0"), location: 1),
                    ],
                    glowColor: nil,
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.58, y: 0.05), color: Color(hex: "DCEFFC"), opacity: 0.45, endRadiusFraction: 0.38),
                    ],
                    meshBlobs: mesh.blobs,
                    meshBaseColor: mesh.base
                )
            case .asr:
                return SkyTheme(
                    baseColors: [Color(hex: "9FF1F2"), Color(hex: "6CD4E4"), Color(hex: "73E1EA"), Color(hex: "BDE2BD")],
                    gradientStops: [
                        .init(color: Color(hex: "9FF1F2"), location: 0),
                        .init(color: Color(hex: "6CD4E4"), location: 0.32),
                        .init(color: Color(hex: "73E1EA"), location: 0.62),
                        .init(color: Color(hex: "BDE2BD"), location: 1),
                    ],
                    glowColor: nil,
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.18, y: 0.06), color: Color(hex: "9FF1F2"), opacity: 0.50, endRadiusFraction: 0.36),
                        SkyRadialOverlay(center: UnitPoint(x: 0.45, y: 0.88), color: Color(hex: "BDE2BD"), opacity: 0.45, endRadiusFraction: 0.42),
                    ],
                    meshBlobs: mesh.blobs,
                    meshBaseColor: mesh.base
                )
            case .maghrib:
                return SkyTheme(
                    baseColors: [Color(hex: "F2D7D9"), Color(hex: "E786A7")],
                    gradientStops: [
                        .init(color: Color(hex: "F2D7D9"), location: 0),
                        .init(color: Color(hex: "E786A7"), location: 1),
                    ],
                    glowColor: nil,
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.18, y: 0.04), color: Color(hex: "F2D7D9"), opacity: 0.48, endRadiusFraction: 0.38),
                    ],
                    meshBlobs: mesh.blobs,
                    meshBaseColor: mesh.base
                )
            case .isha:
                return SkyTheme(
                    baseColors: [Color(hex: "1D1939"), Color(hex: "1B122F"), Color(hex: "221A2E"), Color(hex: "050409")],
                    gradientStops: [
                        .init(color: Color(hex: "1D1939"), location: 0),
                        .init(color: Color(hex: "1B122F"), location: 0.34),
                        .init(color: Color(hex: "221A2E"), location: 0.68),
                        .init(color: Color(hex: "050409"), location: 1),
                    ],
                    glowColor: nil,
                    radialOverlays: [
                        SkyRadialOverlay(center: UnitPoint(x: 0.55, y: 0.35), color: Color(hex: "221A2E"), opacity: 0.55, endRadiusFraction: 0.45),
                    ],
                    meshBlobs: mesh.blobs,
                    meshBaseColor: mesh.base
                )
            case .tahajjud:
                return classicSetSky
            }
        }
    }

    static func resolvedGradientSet(for prayerId: String) -> SkyGradientSet {
        let resolvedTheme = resolvedTheme(for: prayerId)
        guard let defaults = UserDefaults(suiteName: MasjidlyWidgetSharedConfig.appGroupIdentifier),
              let data = defaults.data(forKey: MasjidlyWidgetSharedConfig.prayerGradientStylesKey),
              let styles = try? JSONDecoder().decode([String: String].self, from: data),
              let raw = styles[resolvedTheme.rawValue],
              let set = SkyGradientSet(rawValue: raw) else {
            return resolvedTheme.defaultGradientSet()
        }
        return set
    }

    static func resolvedCustomGradientColors(for prayerId: String) -> CustomSkyGradientColors? {
        let resolvedTheme = resolvedTheme(for: prayerId)
        guard resolvedGradientSet(for: prayerId) == .custom,
              let defaults = UserDefaults(suiteName: MasjidlyWidgetSharedConfig.appGroupIdentifier),
              let data = defaults.data(forKey: MasjidlyWidgetSharedConfig.prayerCustomGradientColorsKey),
              let colorsByPrayer = try? JSONDecoder().decode([String: CustomSkyGradientColors].self, from: data) else {
            return nil
        }
        return colorsByPrayer[resolvedTheme.rawValue]
    }

    static func resolvedWidgetTextColor(
        theme: TimeTheme,
        gradientSet: SkyGradientSet,
        customColors: CustomSkyGradientColors?
    ) -> Color {
        if gradientSet == .custom, let customColors {
            return textColorForCustomGradient(top: customColors.topColor, bottom: customColors.bottomColor)
        }
        return theme.textColor(set: gradientSet)
    }

    static func textColorForCustomGradient(top: Color, bottom: Color) -> Color {
        let luminance = (top.widgetRelativeLuminance + bottom.widgetRelativeLuminance) / 2
        return luminance < 0.45 ? .white : Color(hex: "111111")
    }

    static func resolvedTheme(for prayerId: String) -> TimeTheme {
        guard let defaults = UserDefaults(suiteName: MasjidlyWidgetSharedConfig.appGroupIdentifier) else {
            return theme(for: prayerId)
        }
        let mode = defaults.string(forKey: MasjidlyWidgetSharedConfig.themeModeKey) ?? "dynamic"
        if mode == "fixed",
           let rawFixedTheme = defaults.string(forKey: MasjidlyWidgetSharedConfig.fixedThemeKey),
           let fixedTheme = TimeTheme(rawValue: rawFixedTheme) {
            return fixedTheme
        }
        return theme(for: prayerId)
    }

    static func theme(for prayerId: String) -> TimeTheme {
        switch prayerId.lowercased() {
        case "fajr": return .fajr
        case "sunrise": return .sunrise
        case "dhuhr", "jummah": return .dhuhr
        case "asr": return .asr
        case "maghrib": return .maghrib
        case "isha": return .isha
        case "tahajjud": return .tahajjud
        default: return .dhuhr
        }
    }
}

// MARK: - Widget Localization Local Helper

private func widgetLS(_ key: String, locale: Locale) -> String {
    let lang = String(locale.identifier.prefix(2))
    switch key {
    case "widget.prayer":
        if lang == "ar" { return "الصلاة" }
        if lang == "ur" { return "نماز" }
        if lang == "id" { return "Salat" }
        return "Prayer"
    case "widget.adhan":
        if lang == "ar" { return "الأذان" }
        if lang == "ur" { return "اذان" }
        if lang == "id" { return "Azan" }
        return "Adhan"
    case "widget.iqamah":
        if lang == "ar" { return "الإقامة" }
        if lang == "ur" { return "اقامت" }
        if lang == "id" { return "Iqamah" }
        return "Iqamah"
    case "widget.iqamah_format":
        if lang == "ar" { return "الإقامة %@" }
        if lang == "ur" { return "اقامت %@" }
        if lang == "id" { return "Iqamah %@" }
        return "Iqamah %@"
    case "widget.countdown.adhan_in":
        if lang == "ar" { return "الأذان بعد" }
        if lang == "ur" { return "اذان میں" }
        if lang == "id" { return "AZAN DALAM" }
        return "ADHAN IN"
    case "widget.countdown.iqamah_in":
        if lang == "ar" { return "الإقامة بعد" }
        if lang == "ur" { return "اقامت میں" }
        if lang == "id" { return "IQAMAH DALAM" }
        return "IQAMAH IN"
    case "widget.unavailable":
        if lang == "ar" { return "أوقات الصلاة غير متوفرة" }
        if lang == "ur" { return "نماز کے اوقات دستیاب نہیں ہیں" }
        if lang == "id" { return "Jadwal sholat tidak tersedia" }
        return "Prayer times unavailable"
    case "widget.open_app":
        if lang == "ar" { return "افتح التطبيق للتحديث" }
        if lang == "ur" { return "اپ ڈیٹ کرنے کے لیے ایپ کھولیں" }
        if lang == "id" { return "Buka aplikasi untuk memperbarui" }
        return "Open app to update"
    case "widget.open_masjidly_update":
        if lang == "ar" { return "افتح مسجدلي للتحديث" }
        if lang == "ur" { return "اپ ڈیٹ کرنے کے لیے مسجدلی کھولیں" }
        if lang == "id" { return "Buka Masjidly untuk memperbarui" }
        return "Open Masjidly to update"
    default:
        return key
    }
}

private func widgetCountdownHeadline(prayerName: String, isIqamah: Bool, locale: Locale) -> String {
    let lang = String(locale.identifier.prefix(2))
    switch lang {
    case "ar":
        return isIqamah ? "الإقامة ل\(prayerName) بعد" : "الأذان ل\(prayerName) بعد"
    case "ur":
        return isIqamah ? "\(prayerName) کی اقامت میں" : "\(prayerName) کا اذان میں"
    case "id":
        return isIqamah ? "Iqamah \(prayerName) dalam" : "Adzan \(prayerName) dalam"
    default:
        return isIqamah
            ? "The Iqamah of \(prayerName) is in"
            : "The Adhan of \(prayerName) is in"
    }
}

extension View {
    func widgetFittingLine() -> some View {
        lineLimit(1)
            .minimumScaleFactor(0.5)
            .truncationMode(.tail)
    }

    func widgetAccessoryScaleToFit(designSize: CGSize) -> some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / designSize.width,
                geometry.size.height / designSize.height,
                1
            )
            self
                .frame(width: designSize.width, height: designSize.height, alignment: .center)
                .scaleEffect(scale, anchor: .center)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                .clipped()
        }
    }

    func widgetFont(size: CGFloat, weight: Font.Weight = .regular, locale: Locale = Locale(identifier: "en")) -> some View {
        let isArabic = locale.identifier.hasPrefix("ar")
        let isUrdu = locale.identifier.hasPrefix("ur")
        let scale: CGFloat = isUrdu ? 1.25 : (isArabic ? 1.20 : 1.00)
        return self.font(Font(widgetUIFont(size: size * scale, weight: weight)))
    }
    
    func widgetFont(_ style: Font, locale: Locale = Locale(identifier: "en")) -> some View {
        // Map common styles to Gill Sans sizes if possible, or just use custom
        let size: CGFloat = switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
        let weight: Font.Weight = (style == .headline) ? .semibold : .regular
        return self.widgetFont(size: size, weight: weight, locale: locale)
    }
}

private func widgetUIFont(size: CGFloat, weight: Font.Weight) -> UIFont {
    let name: String = switch weight {
    case .bold, .heavy, .black: "GillSans-Bold"
    case .semibold: "GillSans-SemiBold"
    case .medium: "GillSans-Medium"
    case .light, .thin, .ultraLight: "GillSans-Light"
    default: "GillSans"
    }
    return UIFont(name: name, size: size)
        ?? UIFont.systemFont(ofSize: size, weight: weight.uiKitWeight)
}

private extension Font.Weight {
    var uiKitWeight: UIFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

extension Color {
    var widgetRelativeLuminance: Double {
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

#Preview(as: .systemSmall) {
    MasjidlyPrayerWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryInline) {
    MasjidlyPrayerWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryCircular) {
    MasjidlyPrayerWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryRectangular) {
    MasjidlyPrayerWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}
