import SwiftUI
import UIKit
import WidgetKit

enum HomeScreenDesign: CaseIterable {
    case card
    case row
    case small

    var family: WidgetFamily {
        switch self {
        case .card: .systemLarge
        case .row: .systemMedium
        case .small: .systemSmall
        }
    }

    var kind: String {
        switch self {
        case .card: "MasjidlyHomeCard"
        case .row: "MasjidlyHomeRow"
        case .small: "MasjidlyHomeSmall"
        }
    }

    var displayName: String {
        switch self {
        case .card: "Masjid Card"
        case .row: "Prayer Row"
        case .small: "Next Prayer"
        }
    }

    var summary: String {
        switch self {
        case .card: "Live countdown ring with all five prayers, adhan and iqamah, on a rose gradient."
        case .row: "All five prayers in a row with the next one highlighted, on a sky gradient."
        case .small: "The next prayer with a progress ring, its adhan time and the iqamah time."
        }
    }
}

protocol HomeScreenWidget: Widget {
    static var design: HomeScreenDesign { get }
}

extension HomeScreenWidget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.design.kind, provider: MasjidlyPrayerTimelineProvider()) { entry in
            MasjidlyHomeScreenView(entry: entry, design: Self.design)
        }
        .configurationDisplayName(Self.design.displayName)
        .description(Self.design.summary)
        .supportedFamilies([Self.design.family])
        .contentMarginsDisabled()
    }
}

struct MasjidCardWidget: HomeScreenWidget { static let design = HomeScreenDesign.card }
struct PrayerRowWidget: HomeScreenWidget { static let design = HomeScreenDesign.row }
struct NextPrayerWidget: HomeScreenWidget { static let design = HomeScreenDesign.small }

// MARK: - Model

private struct HomeScreenRow: Identifiable {
    let id: String
    let prayerId: String
    let name: String
    let adhan: String
    let iqamah: String
    let isNext: Bool
}

private struct HomeScreenModel {
    let state: MasjidlyWidgetState
    let now: Date
    let locale: Locale
    let rows: [HomeScreenRow]

    init(_ entry: MasjidlyPrayerEntry) {
        state = entry.state
        now = entry.date
        locale = entry.locale

        var collapsed: [HomeScreenRow] = []
        for row in entry.state.rows {
            let iqamah = row.iqamahs.joined(separator: ", ")
            if row.id.hasPrefix("jummah_"), let last = collapsed.last, last.prayerId == "dhuhr" {
                collapsed[collapsed.count - 1] = HomeScreenRow(
                    id: last.id, prayerId: last.prayerId, name: last.name, adhan: last.adhan,
                    iqamah: last.iqamah + ", " + iqamah,
                    isNext: last.isNext || row.isNext
                )
                continue
            }
            let isJummah = row.id.hasPrefix("jummah_")
            collapsed.append(HomeScreenRow(
                id: isJummah ? "dhuhr" : row.id,
                prayerId: isJummah ? "dhuhr" : row.id,
                name: isJummah ? row.name.replacingOccurrences(of: #"\s*\d+$"#, with: "", options: .regularExpression) : row.name,
                adhan: row.adhan,
                iqamah: iqamah,
                isNext: row.isNext
            ))
        }
        rows = collapsed
    }

    var isIqamah: Bool { state.iqamahDate != nil && state.targetDate == state.iqamahDate }

    var remaining: TimeInterval? {
        guard let target = state.targetDate, target > now else { return nil }
        return target.timeIntervalSince(now)
    }

    var progress: Double {
        guard let start = state.progressStartDate, let end = state.targetDate, end > start else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    var languageCode: String { String(locale.identifier.prefix(2)) }

    var layoutDirection: LayoutDirection {
        ["ar", "ur"].contains(languageCode) ? .rightToLeft : .leftToRight
    }

    var abbreviatedRemaining: String {
        let minutes = Int((remaining ?? 0) / 60)
        let units: (hour: String, minute: String) = switch languageCode {
        case "ar": ("س", "د")
        case "ur": ("گ", "م")
        case "id": ("j", "m")
        default: ("h", "m")
        }
        if minutes >= 60 {
            return "\(minutes / 60)\(units.hour) \(String(format: "%02d", minutes % 60))\(units.minute)"
        }
        return minutes > 0 ? "\(minutes)\(units.minute)" : "<1\(units.minute)"
    }

    func dateText(format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        formatter.dateFormat = format
        return formatter.string(from: state.displayDate).uppercased()
    }

    func caption(_ key: String) -> String {
        widgetLS(key, locale: locale).uppercased()
    }

    /// The snapshot formats "5:40AM"; the design wants "5:40 AM".
    static func spacedMeridiem(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"(\d)\s*([AaPp][Mm])"#, with: "$1 $2", options: .regularExpression)
    }

    /// Splits "5:40AM" into ("5:40", "AM"). 24 hour times have no meridiem. Only the first of several
    /// comma separated times is used, so five columns stay narrow.
    static func timeParts(_ raw: String) -> (clock: String, meridiem: String) {
        let first = raw.split(separator: ",").first.map(String.init) ?? raw
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        let clock = trimmed.prefix { $0.isNumber || $0 == ":" || $0 == "٫" }
        if clock.isEmpty { return (trimmed, "") }
        let meridiem = trimmed.dropFirst(clock.count).trimmingCharacters(in: .whitespaces)
        return (String(clock), meridiem)
    }
}

/// A time with a small AM/PM beside it when the app is set to 12 hour time.
private struct TimeWithMeridiem: View {
    let raw: String
    let clockSize: CGFloat
    let meridiemSize: CGFloat
    let ink: Color
    let locale: Locale
    var clockWeight: Font.Weight = .regular

    var body: some View {
        let parts = HomeScreenModel.timeParts(raw)
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(parts.clock)
                .widgetFont(size: clockSize, weight: clockWeight, locale: locale)
            if !parts.meridiem.isEmpty {
                Text(parts.meridiem)
                    .widgetFont(size: meridiemSize, weight: .regular, locale: locale)
            }
        }
        .foregroundStyle(ink)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

// MARK: - Host view

struct MasjidlyHomeScreenView: View {
    let entry: MasjidlyPrayerEntry
    let design: HomeScreenDesign

    var body: some View {
        let model = HomeScreenModel(entry)
        let theme = MasjidlyWidgetTheme.resolvedTheme(for: entry.state.prayerId)
        let gradientSet = MasjidlyWidgetTheme.resolvedGradientSet(for: entry.state.prayerId)
        let customColors = MasjidlyWidgetTheme.resolvedCustomGradientColors(for: entry.state.prayerId)
        let palette = HomeScreenPalette(
            ink: MasjidlyWidgetTheme.resolvedWidgetTextColor(theme: theme, gradientSet: gradientSet, customColors: customColors)
        )
        Group {
            if entry.state.kind != .content {
                unavailable
            } else {
                switch design {
                case .card: HomeCardDesign(model: model, palette: palette)
                case .row: HomeRowDesign(model: model, palette: palette)
                case .small: HomeSmallDesign(model: model, palette: palette)
                }
            }
        }
        .environment(\.layoutDirection, model.layoutDirection)
        .containerBackground(for: .widget) {
            if entry.state.kind != .content {
                Color(hex: "111111")
            } else {
                MasjidlyPrayerWidgetView(entry: entry)
                    .backgroundView(for: theme, gradientSet: gradientSet, customColors: customColors)
            }
        }
    }

    private var unavailable: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .widgetFont(.title3, locale: entry.locale)
            Text(widgetLS("widget.unavailable", locale: entry.locale))
                .widgetFont(size: 14, weight: .medium, locale: entry.locale)
            Text(widgetLS("widget.open_app", locale: entry.locale))
                .widgetFont(.caption2, locale: entry.locale)
                .opacity(0.6)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Colours derived from the prayer-time sky theme, so light and dark skies both stay legible.
private struct HomeScreenPalette {
    let ink: Color

    var highlight: Color { ink.widgetRowHighlight }
}

// MARK: - Countdown

private struct HomeCountdown: View {
    let model: HomeScreenModel
    let ink: Color
    let fontSize: CGFloat

    var body: some View {
        if model.remaining != nil, let target = model.state.targetDate {
            timer(target: target)
        } else {
            Text(model.state.adhanTime)
                .font(Font(widgetUIFont(size: fontSize, weight: .light)))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    /// Prefix and widths for the live timer. The timer is sized to the digits it will actually show, because
    /// a fixed sample leaves blank space on the right under 10 minutes, when the system drops the tens digit.
    struct Layout {
        let prefix: String
        let showsHours: Bool
        let timerWidth: CGFloat
        let totalWidth: CGFloat
    }

    static func layout(remaining: TimeInterval, fontSize: CGFloat) -> Layout {
        let font = widgetUIFont(size: fontSize, weight: .light)
        let showsHours = remaining >= 3_600
        // Entries start on exact minute boundaries, so an entry that begins at exactly 10:00 or 10:00:00
        // spends its whole minute below the boundary. Treat the boundary itself as already under it.
        let prefix: String
        let sample: String
        if showsHours {
            prefix = remaining <= 36_000 ? "0" : ""
            sample = String(repeating: "9", count: max(1, String(Int(remaining) / 3_600).count)) + ":59:59"
        } else if remaining <= 600 {
            prefix = "00:0"
            sample = "9:59"
        } else {
            prefix = "00:"
            sample = "59:59"
        }
        func width(_ text: String) -> CGFloat {
            ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
        let timerWidth = width(sample) + 2
        return Layout(prefix: prefix, showsHours: showsHours, timerWidth: timerWidth, totalWidth: width(prefix) + timerWidth)
    }

    /// Native WidgetKit timer with a literal prefix so hours and minutes always show two digits.
    private func timer(target: Date) -> some View {
        let font = widgetUIFont(size: fontSize, weight: .light)
        let layout = Self.layout(remaining: max(0, target.timeIntervalSince(model.now)), fontSize: fontSize)

        return HStack(spacing: 0) {
            Text(layout.prefix)
            Text(timerInterval: model.now...target, countsDown: true, showsHours: layout.showsHours)
                .monospacedDigit()
                .multilineTextAlignment(.leading)
                .frame(width: layout.timerWidth, alignment: .leading)
                .environment(\.locale, Locale(identifier: "en_GB"))
        }
        .font(Font(font))
        .foregroundStyle(ink)
        .lineLimit(1)
    }
}

// MARK: - Large card

private struct HomeCardDesign: View {
    let model: HomeScreenModel
    let palette: HomeScreenPalette
    private var ink: Color { palette.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            hero.padding(.top, 8)
            Rectangle().fill(ink.opacity(0.18)).frame(height: 1).padding(.top, 8)
            columnHeaders.padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(model.rows) { row in
                    prayerRow(row)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private let adhanWidth: CGFloat = 92
    private let iqamahWidth: CGFloat = 86

    private var header: some View {
        HStack(spacing: 8) {
            Text(model.state.mosqueDisplayName)
                .widgetFont(size: 17, weight: .medium, locale: model.locale)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 4)
            Text(model.dateText(format: "EEEE · d MMM"))
                .widgetFont(size: 12, weight: .medium, locale: model.locale)
                .kerning(1.6)
                .foregroundStyle(ink.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
        }
    }

    private var hero: some View {
        let state = model.state
        let headline = widgetHeadline(prayerName: state.prayerName, isIqamah: model.isIqamah, locale: model.locale)
        return HStack(alignment: .center, spacing: 12) {
            ProgressRing(
                prayerId: state.prayerId,
                progress: model.progress,
                size: 64,
                lineWidth: 3,
                ink: ink,
                track: ink.opacity(0.18)
            )
            VStack(alignment: .center, spacing: 0) {
                Text(headline)
                    .widgetFont(size: 13, weight: .regular, locale: model.locale)
                    .foregroundStyle(ink.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HomeCountdown(model: model, ink: ink, fontSize: 46)
                if let remaining = model.remaining {
                    unitLabels(remaining: remaining)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func unitLabels(remaining: TimeInterval) -> some View {
        let width = HomeCountdown.layout(remaining: remaining, fontSize: 46).totalWidth
        return HStack(spacing: 0) {
            ForEach(["widget.unit.hours", "widget.unit.minutes", "widget.unit.seconds"], id: \.self) { key in
                Text(unitCaption(key))
                    .widgetFont(size: 10, weight: .medium, locale: model.locale)
                    .kerning(1.6)
                    .foregroundStyle(ink.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private func unitCaption(_ key: String) -> String {
        switch (key, model.languageCode) {
        case ("widget.unit.hours", "ar"): "ساعة"
        case ("widget.unit.minutes", "ar"): "دقيقة"
        case ("widget.unit.seconds", "ar"): "ثانية"
        case ("widget.unit.hours", "ur"): "گھنٹے"
        case ("widget.unit.minutes", "ur"): "منٹ"
        case ("widget.unit.seconds", "ur"): "سیکنڈ"
        case ("widget.unit.hours", "id"): "JAM"
        case ("widget.unit.minutes", "id"): "MNT"
        case ("widget.unit.seconds", "id"): "DTK"
        case ("widget.unit.hours", _): "HRS"
        case ("widget.unit.minutes", _): "MIN"
        default: "SEC"
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(model.caption("widget.adhan"))
                .foregroundStyle(ink.opacity(0.7))
                .frame(width: adhanWidth, alignment: .trailing)
            Text(model.caption("widget.iqamah"))
                .foregroundStyle(ink.opacity(0.5))
                .frame(width: iqamahWidth, alignment: .trailing)
        }
        .widgetFont(size: 10, weight: .medium, locale: model.locale)
        .kerning(1.4)
        .lineLimit(1)
    }

    private func prayerRow(_ row: HomeScreenRow) -> some View {
        HStack(spacing: 0) {
            WidgetPrayerSunPhaseIcon(prayerId: row.prayerId, color: ink, size: 30)
            Text(row.name)
                .widgetFont(size: 17, weight: .regular, locale: model.locale)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.leading, 10)
            Spacer(minLength: 4)
            Text(HomeScreenModel.spacedMeridiem(row.adhan))
                .widgetFont(size: 17, weight: .regular, locale: model.locale)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: adhanWidth, alignment: .trailing)
            Text(HomeScreenModel.spacedMeridiem(row.iqamah))
                .widgetFont(size: 15, weight: .regular, locale: model.locale)
                .foregroundStyle(ink.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: iqamahWidth, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background {
            if row.isNext {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.highlight)
            }
        }
        .padding(.horizontal, -10)
    }
}

// MARK: - Medium row

private struct HomeRowDesign: View {
    let model: HomeScreenModel
    let palette: HomeScreenPalette
    private var ink: Color { palette.ink }

    var body: some View {
        VStack(spacing: 6) {
            header
            HStack(alignment: .top, spacing: 0) {
                ForEach(model.rows.prefix(5)) { row in
                    column(row)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle().fill(ink).frame(width: 8, height: 8)
            Text(model.state.prayerName)
                .widgetFont(size: 17, weight: .bold, locale: model.locale)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if model.remaining != nil {
                Text(String(format: widgetLS("widget.in_format", locale: model.locale), model.abbreviatedRemaining))
                    .widgetFont(size: 14, weight: .regular, locale: model.locale)
                    .foregroundStyle(ink.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 4)
            Text(model.caption("widget.adhan"))
                .foregroundStyle(ink.opacity(0.7))
                .fixedSize()
            Text(model.caption("widget.iqamah"))
                .foregroundStyle(ink.opacity(0.5))
                .fixedSize()
        }
        .widgetFont(size: 9, weight: .medium, locale: model.locale)
        .kerning(1.2)
        .lineLimit(1)
    }

    private func column(_ row: HomeScreenRow) -> some View {
        VStack(spacing: 4) {
            WidgetPrayerSunPhaseIcon(prayerId: row.prayerId, color: ink, size: 48)
            Text(row.name)
                .widgetFont(size: 14, weight: .regular, locale: model.locale)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            TimeWithMeridiem(raw: row.adhan, clockSize: 19, meridiemSize: 9, ink: ink, locale: model.locale)
            TimeWithMeridiem(raw: row.iqamah, clockSize: 15, meridiemSize: 8, ink: ink.opacity(0.65), locale: model.locale)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            if row.isNext {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.highlight)
            }
        }
    }
}

// MARK: - Small card

private struct HomeSmallDesign: View {
    let model: HomeScreenModel
    let palette: HomeScreenPalette
    private var ink: Color { palette.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 2)
            TimeWithMeridiem(
                raw: model.state.adhanTime, clockSize: 38, meridiemSize: 11,
                ink: ink, locale: model.locale, clockWeight: .light
            )
            .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 2)
            if !model.state.iqamahTime.isEmpty {
                iqamahPanel
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ProgressRing(
                prayerId: model.state.prayerId,
                progress: model.progress,
                size: 40,
                lineWidth: 2.5,
                ink: ink,
                track: ink.opacity(0.18)
            )
            VStack(alignment: .leading, spacing: 0) {
                Text(model.state.prayerName)
                    .widgetFont(size: 19, weight: .regular, locale: model.locale)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if model.remaining != nil {
                    Text(String(format: widgetLS("widget.in_format", locale: model.locale), model.abbreviatedRemaining))
                        .widgetFont(size: 12, weight: .regular, locale: model.locale)
                        .foregroundStyle(ink.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var iqamahPanel: some View {
        HStack(spacing: 6) {
            Text(widgetLS("widget.iqamah", locale: model.locale))
                .widgetFont(size: 12, weight: .regular, locale: model.locale)
                .foregroundStyle(ink.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            TimeWithMeridiem(raw: model.state.iqamahTime, clockSize: 14, meridiemSize: 9, ink: ink, locale: model.locale)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.highlight))
    }
}

// MARK: - Shared pieces

private struct ProgressRing: View {
    let prayerId: String
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let ink: Color
    let track: Color

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            WidgetPrayerSunPhaseIcon(prayerId: prayerId, color: ink, size: size - lineWidth * 2)
        }
        .frame(width: size, height: size)
    }
}

private func widgetHeadline(prayerName: String, isIqamah: Bool, locale: Locale) -> String {
    switch String(locale.identifier.prefix(2)) {
    case "ar": isIqamah ? "الإقامة ل\(prayerName) بعد" : "الأذان ل\(prayerName) بعد"
    case "ur": isIqamah ? "\(prayerName) کی اقامت میں" : "\(prayerName) کا اذان میں"
    case "id": isIqamah ? "Iqamah \(prayerName) dalam" : "Adzan \(prayerName) dalam"
    default: isIqamah ? "The Iqamah of \(prayerName) is in" : "The Adhan of \(prayerName) is in"
    }
}
