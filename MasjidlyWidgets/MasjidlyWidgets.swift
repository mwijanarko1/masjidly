import SwiftUI
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
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MasjidlyPrayerEntry>) -> Void) {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        guard let snapshot = MasjidlyWidgetSnapshotStore().readSnapshot() else {
            completion(Timeline(entries: [entry(for: now)], policy: .after(now.addingTimeInterval(1_800))))
            return
        }

        let state = MasjidlyWidgetResolver.resolve(snapshot: snapshot, now: now)
        let locale = AppLanguage(persistedRawValue: snapshot.appLanguageRawValue).resolvedLocale()

        guard state.kind == .content, let target = state.targetDate else {
            completion(Timeline(entries: [MasjidlyPrayerEntry(date: now, state: state, locale: locale)], policy: .after(now.addingTimeInterval(1_800))))
            return
        }

        let untilAdhan = target.timeIntervalSince(now)
        let isAccessory = context.family == .accessoryCircular
            || context.family == .accessoryRectangular
            || context.family == .accessoryInline

        if isAccessory, untilAdhan > 0, untilAdhan < 2 * 3_600 {
            let startOfMinute = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)) ?? now
            let minuteCount = min(max(Int(ceil(untilAdhan / 60)) + 20, 8), 90)
            var entries: [MasjidlyPrayerEntry] = (0..<minuteCount).compactMap { offset in
                guard let d = calendar.date(byAdding: .minute, value: offset, to: startOfMinute) else { return nil }
                return MasjidlyPrayerEntry(date: d, state: MasjidlyWidgetResolver.resolve(snapshot: snapshot, now: d), locale: locale)
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

    private func entry(for date: Date) -> MasjidlyPrayerEntry {
        guard let snapshot = MasjidlyWidgetSnapshotStore().readSnapshot() else {
            return MasjidlyPrayerEntry(date: date, state: .missing)
        }
        let locale = AppLanguage(persistedRawValue: snapshot.appLanguageRawValue).resolvedLocale()
        return MasjidlyPrayerEntry(date: date, state: MasjidlyWidgetResolver.resolve(snapshot: snapshot, now: date), locale: locale)
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
        let theme = MasjidlyWidgetTheme.theme(for: entry.state.prayerId)
        
        Group {
            if entry.state.kind != .content {
                unavailableView
            } else {
                switch family {
                case .systemSmall:
                    smallView(theme: theme)
                case .systemMedium:
                    mediumView(theme: theme)
                case .systemLarge:
                    largeView(theme: theme)
                case .accessoryInline:
                    Text(accessoryInlineText)
                case .accessoryCircular:
                    accessoryCircularView
                case .accessoryRectangular:
                    accessoryRectangularView
                default:
                    smallView(theme: theme)
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
                backgroundView(for: theme)
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
                .widgetFont(size: 12, weight: .medium, locale: entry.locale)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(widgetLS("widget.open_app", locale: entry.locale))
                .widgetFont(.caption2, locale: entry.locale)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
    }

    private func backgroundView(for theme: MasjidlyWidgetTheme.TimeTheme) -> some View {
        GeometryReader { geo in
            ZStack {
                // 1. Base Sky
                LinearGradient(
                    colors: theme.skyColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // 2. Stars (for dark themes)
                if theme == .fajr || theme == .isha || theme == .tahajjud {
                    starField(in: geo.size, intensity: theme == .tahajjud ? 0.08 : 0.04)
                }
                
                // 3. Horizon Glow
                if let glow = theme.glowColor {
                    RadialGradient(
                        colors: [glow.opacity(0.4), glow.opacity(0.15), .clear],
                        center: UnitPoint(x: 0.5, y: 0.85),
                        startRadius: 0,
                        endRadius: geo.size.height * 1.2
                    )
                    .blendMode(.screen)
                }
                
                // 4. Atmosphere Depth
                LinearGradient(
                    colors: [Color.black.opacity(0.1), .clear, Color.black.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
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

    private func smallView(theme: MasjidlyWidgetTheme.TimeTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.state.iconName)
                    .widgetFont(.subheadline, locale: entry.locale)
                    .foregroundStyle(theme.textColor.opacity(0.8))
                Text(entry.state.prayerName)
                    .widgetFont(size: 14, weight: .medium, locale: entry.locale)
                    .foregroundStyle(theme.textColor.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)

            Text(entry.state.adhanTime)
                .widgetFont(size: 36, weight: .light, locale: entry.locale)
                .foregroundStyle(theme.textColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            if !entry.state.iqamahTime.isEmpty {
                Text(String(format: widgetLS("widget.iqamah_format", locale: entry.locale), entry.state.iqamahTime))
                    .widgetFont(size: 12, weight: .regular, locale: entry.locale)
                    .foregroundStyle(theme.textColor.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(16)
    }

    private var currentDateMediumString: String {
        let formatter = DateFormatter()
        formatter.locale = entry.locale
        formatter.dateFormat = "EEEE · d MMM"
        return formatter.string(from: entry.date)
    }

    private func mediumView(theme: MasjidlyWidgetTheme.TimeTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentDateMediumString.uppercased())
                .widgetFont(size: 10, weight: .semibold, locale: entry.locale)
                .kerning(1.0)
                .foregroundStyle(theme.textColor.opacity(0.5))
            
            HStack {
                Text(widgetLS("widget.prayer", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .leading)
                Text(widgetLS("widget.adhan", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .center)
                Text(widgetLS("widget.iqamah", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .widgetFont(size: 9, weight: .bold, locale: entry.locale)
            .foregroundStyle(theme.textColor.opacity(0.4))
            .textCase(.uppercase)
            
            VStack(spacing: 3) {
                ForEach(entry.state.rows.prefix(6)) { row in
                    HStack {
                        Text(row.name)
                            .widgetFont(size: 13, weight: row.isNext ? .bold : .regular, locale: entry.locale)
                            .foregroundStyle(row.isPassed ? theme.textColor.opacity(0.35) : theme.textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(row.adhan)
                            .widgetFont(size: 13, weight: row.isNext ? .bold : .semibold, locale: entry.locale)
                            .monospacedDigit()
                            .foregroundStyle(row.isPassed ? theme.textColor.opacity(0.35) : theme.textColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        HStack {
                            Spacer()
                            Text(row.iqamahs.first ?? "")
                                .widgetFont(size: 12, weight: .regular, locale: entry.locale)
                                .monospacedDigit()
                                .foregroundStyle(row.isPassed ? theme.textColor.opacity(0.2) : theme.textColor.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
    }

    private var fullDateString: String {
        let formatter = DateFormatter()
        formatter.locale = entry.locale
        formatter.dateFormat = "MMMM, EEEE d"
        return formatter.string(from: entry.date)
    }

    private func largeView(theme: MasjidlyWidgetTheme.TimeTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(fullDateString.uppercased())
                .widgetFont(size: 11, weight: .semibold, locale: entry.locale)
                .kerning(1.0)
                .foregroundStyle(theme.textColor.opacity(0.5))
            
            // Summary Card
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: entry.state.iconName)
                    Text(entry.state.prayerName)
                }
                .widgetFont(size: 16, weight: .medium, locale: entry.locale)
                .foregroundStyle(theme.textColor.opacity(0.8))
                
                HStack(alignment: .lastTextBaseline) {
                    Text(entry.state.adhanTime)
                        .widgetFont(size: 44, weight: .light, locale: entry.locale)
                        .foregroundStyle(theme.textColor)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if !entry.state.iqamahTime.isEmpty {
                        Text(String(format: widgetLS("widget.iqamah_format", locale: entry.locale), entry.state.iqamahTime))
                            .widgetFont(size: 14, weight: .regular, locale: entry.locale)
                            .monospacedDigit()
                            .foregroundStyle(theme.textColor.opacity(0.6))
                    }
                }
            }
            .padding(.bottom, 4)
            
            Rectangle()
                .fill(theme.textColor.opacity(0.15))
                .frame(height: 1)
            
            HStack {
                Text(widgetLS("widget.prayer", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .leading)
                Text(widgetLS("widget.adhan", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .center)
                Text(widgetLS("widget.iqamah", locale: entry.locale)).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .widgetFont(size: 9, weight: .bold, locale: entry.locale)
            .foregroundStyle(theme.textColor.opacity(0.4))
            .textCase(.uppercase)
            
            // 3-column list
            VStack(spacing: 8) {
                ForEach(entry.state.rows) { row in
                    HStack(alignment: .top) {
                        Text(row.name)
                            .widgetFont(size: 15, weight: row.isNext ? .bold : .regular, locale: entry.locale)
                            .foregroundStyle(row.isPassed ? theme.textColor.opacity(0.35) : theme.textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(row.adhan)
                            .widgetFont(size: 15, weight: row.isNext ? .bold : .semibold, locale: entry.locale)
                            .monospacedDigit()
                            .foregroundStyle(row.isPassed ? theme.textColor.opacity(0.35) : theme.textColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(row.iqamahs, id: \.self) { iq in
                                Text(iq)
                                    .widgetFont(size: 14, weight: .regular, locale: entry.locale)
                                    .monospacedDigit()
                                    .foregroundStyle(row.isPassed ? theme.textColor.opacity(0.2) : theme.textColor.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var accessoryCircularView: some View {
        let s = entry.state
        let now = entry.date
        let target = s.targetDate
        let until = target.map { $0.timeIntervalSince(now) } ?? 0
        let showCountdown = until > 0 && until <= 45 * 60
        let progress: CGFloat = {
            guard let start = s.progressStartDate, let end = target, until > 0, end > start else { return 0 }
            let span = end.timeIntervalSince(start)
            guard span > 0 else { return 0 }
            return CGFloat(min(1, max(0, now.timeIntervalSince(start) / span)))
        }()

        return ZStack {
            AccessoryWidgetBackground()
            AccessoryCircularProgressRing(progress: progress, lineWidth: 3)
                .padding(1)
            VStack(spacing: 0) {
                Image(systemName: s.iconName)
                    .widgetFont(size: 11, weight: .semibold, locale: entry.locale)
                    .symbolRenderingMode(.hierarchical)
                if showCountdown {
                    Text(countdownAbbrev(until: until))
                        .widgetFont(size: 15, weight: .semibold, locale: entry.locale)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(s.prayerName)
                        .widgetFont(size: 9, weight: .medium, locale: entry.locale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                } else {
                    Text(s.adhanTime)
                        .widgetFont(size: 14, weight: .semibold, locale: entry.locale)
                        .monospacedDigit()
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    Text(s.prayerName)
                        .widgetFont(size: 9, weight: .medium, locale: entry.locale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .padding(.horizontal, 2)
        }
        .widgetAccentable()
    }

    private var accessoryRectangularView: some View {
        let s = entry.state
        let hasFollowing = !s.followingPrayerName.isEmpty && !s.followingAdhanTime.isEmpty

        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: s.iconName)
                    .widgetFont(size: 16, weight: .semibold, locale: entry.locale)
                    .symbolRenderingMode(.hierarchical)
                Text(s.prayerName)
                    .widgetFont(size: 17, weight: .semibold, locale: entry.locale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(s.adhanTime)
                    .widgetFont(size: 17, weight: .bold, locale: entry.locale)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if !s.iqamahTime.isEmpty {
                HStack(spacing: 6) {
                    Text(widgetLS("widget.iqamah", locale: entry.locale))
                        .widgetFont(size: 12, weight: .medium, locale: entry.locale)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(s.iqamahTime)
                        .widgetFont(size: 13, weight: .medium, locale: entry.locale)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if hasFollowing {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("↓")
                        .widgetFont(size: 12, weight: .medium, locale: entry.locale)
                        .foregroundStyle(.tertiary)
                    Text(s.followingPrayerName)
                        .widgetFont(size: 13, weight: .medium, locale: entry.locale)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("·")
                        .widgetFont(.caption, locale: entry.locale)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                    Text(s.followingAdhanTime)
                        .widgetFont(size: 13, weight: .semibold, locale: entry.locale)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            }
        }
        .widgetAccentable()
    }

    private var accessoryInlineText: String {
        let s = entry.state
        let now = entry.date
        if let t = s.targetDate {
            let until = t.timeIntervalSince(now)
            if until > 0, until <= 45 * 60 {
                return "\(s.prayerName) \(countdownAbbrev(until: until))"
            }
        }
        return "\(s.prayerName) \(s.adhanTime)"
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

// MARK: - Lock screen circular progress

private struct AccessoryCircularProgressRing: View {
    var progress: CGFloat
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

enum MasjidlyWidgetTheme {
    enum TimeTheme: String {
        case fajr, sunrise, dhuhr, asr, maghrib, isha, tahajjud
        
        var skyColors: [Color] {
            switch self {
            case .fajr: return [Color(hex: "020326"), Color(hex: "06114F"), Color(hex: "0B1E6D"), Color(hex: "3B2A5A")]
            case .sunrise: return [Color(hex: "6B7280"), Color(hex: "C084FC"), Color(hex: "FB923C"), Color(hex: "F59E0B")]
            case .dhuhr: return [Color(hex: "E0F2FE"), Color(hex: "7DD3FC"), Color(hex: "38BDF8")]
            case .asr: return [Color(hex: "93C5FD"), Color(hex: "FDE68A"), Color(hex: "FDBA74")]
            case .maghrib: return [Color(hex: "6D3FA9"), Color(hex: "A855F7"), Color(hex: "F472B6"), Color(hex: "FB7185")]
            case .isha: return [Color(hex: "000000"), Color(hex: "020617"), Color(hex: "0F172A")]
            case .tahajjud: return [Color(hex: "000000"), Color(hex: "01030A"), Color(hex: "020617")]
            }
        }
        
        var glowColor: Color? {
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
        
        var textColor: Color {
            switch self {
            case .fajr, .isha, .tahajjud: return .white
            default: return Color(hex: "111111")
            }
        }
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

extension View {
    func widgetFont(size: CGFloat, weight: Font.Weight = .regular, locale: Locale = Locale(identifier: "en")) -> some View {
        let isArabic = locale.identifier.hasPrefix("ar")
        let isUrdu = locale.identifier.hasPrefix("ur")
        let scale: CGFloat = isUrdu ? 1.25 : (isArabic ? 1.20 : 1.00)
        return self.font(.custom("Gill Sans", size: size * scale).weight(weight))
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
