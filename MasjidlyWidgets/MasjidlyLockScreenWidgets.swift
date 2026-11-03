import SwiftUI
import WidgetKit

enum LockScreenDesign: CaseIterable {
    case rectProgress, rectStrip, rectListMorning, rectListEvening
    case circMinutes, circCode

    var family: WidgetFamily {
        switch self {
        case .rectProgress, .rectStrip, .rectListMorning, .rectListEvening: .accessoryRectangular
        case .circMinutes, .circCode: .accessoryCircular
        }
    }

    var kind: String {
        switch self {
        case .rectProgress: "MasjidlyLockProgress"
        case .rectStrip: "MasjidlyLockStrip"
        case .rectListMorning: "MasjidlyLockListMorning"
        case .rectListEvening: "MasjidlyLockListEvening"
        case .circMinutes: "MasjidlyLockMinutes"
        case .circCode: "MasjidlyLockCode"
        }
    }

    var displayName: String {
        switch self {
        case .rectProgress: "Prayer Progress"
        case .rectStrip: "Prayer Strip"
        case .rectListMorning: "Prayer List: Fajr to Dhuhr"
        case .rectListEvening: "Prayer List: Asr to Isha"
        case .circMinutes: "Minutes Left"
        case .circCode: "Prayer Code"
        }
    }

    var summary: String {
        switch self {
        case .rectProgress: "Next prayer with a progress bar and iqamah time."
        case .rectStrip: "All five prayers in a row with the next one highlighted."
        case .rectListMorning: "Fajr, Sunrise, and Dhuhr with adhan and iqamah columns."
        case .rectListEvening: "Asr, Maghrib, and Isha with adhan and iqamah columns."
        case .circMinutes: "Big minutes left until the next adhan or iqamah."
        case .circCode: "Short prayer code and adhan time inside a progress ring."
        }
    }
}

protocol LockScreenWidget: Widget {
    static var design: LockScreenDesign { get }
}

extension LockScreenWidget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.design.kind, provider: MasjidlyPrayerTimelineProvider()) { entry in
            MasjidlyLockScreenView(entry: entry, design: Self.design)
        }
        .configurationDisplayName(Self.design.displayName)
        .description(Self.design.summary)
        .supportedFamilies([Self.design.family])
    }
}

struct LockProgressWidget: LockScreenWidget { static let design = LockScreenDesign.rectProgress }
struct LockStripWidget: LockScreenWidget { static let design = LockScreenDesign.rectStrip }
struct LockListMorningWidget: LockScreenWidget { static let design = LockScreenDesign.rectListMorning }
struct LockListEveningWidget: LockScreenWidget { static let design = LockScreenDesign.rectListEvening }
struct LockMinutesWidget: LockScreenWidget { static let design = LockScreenDesign.circMinutes }
struct LockCodeWidget: LockScreenWidget { static let design = LockScreenDesign.circCode }

private struct LockScreenModel {
    let state: MasjidlyWidgetState
    let now: Date
    let locale: Locale

    init(_ entry: MasjidlyPrayerEntry) {
        state = entry.state
        now = entry.date
        locale = entry.locale
    }

    var isIqamah: Bool { state.iqamahDate != nil && state.targetDate == state.iqamahDate }
    var icon: String { MasjidlyWidgetState.iconName(forPrayerId: state.prayerId) }
    var adhan: LockScreenTime { LockScreenTime(state.adhanTime) }
    var iqamah: LockScreenTime { LockScreenTime(compactAccessoryIqamahLabel(state.iqamahTime)) }

    var remaining: TimeInterval? {
        guard let target = state.targetDate, target > now else { return nil }
        return target.timeIntervalSince(now)
    }

    var progress: Double {
        guard let start = state.progressStartDate, let end = state.targetDate, end > start else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    var abbreviatedRemaining: String {
        let minutes = Int((remaining ?? 0) / 60)
        let units = timeUnits
        if minutes >= 60 {
            return "\(minutes / 60)\(units.hour) \(String(format: "%02d", minutes % 60))\(units.minute)"
        }
        return minutes > 0 ? "\(minutes)\(units.minute)" : "<1\(units.minute)"
    }

    private var timeUnits: (hour: String, minute: String) {
        switch String(locale.identifier.prefix(2)) {
        case "ar": ("س", "د")
        case "ur": ("گ", "م")
        case "id": ("j", "m")
        default: ("h", "m")
        }
    }

    var minuteUnit: String { timeUnits.minute }

    /// Short prayer code for the circular widgets. Arabic and Urdu keep the full name.
    var code: String {
        let lang = String(locale.identifier.prefix(2))
        if lang == "ar" || lang == "ur" { return state.prayerName }
        if state.prayerName.lowercased().hasPrefix("jum") { return "JUM" }
        switch state.prayerId.lowercased() {
        case "fajr": return "FJR"
        case "dhuhr": return "DHR"
        case "asr": return "ASR"
        case "maghrib": return "MGH"
        case "isha": return "ISH"
        default: return String(state.prayerName.prefix(3)).uppercased()
        }
    }

    var iqamahCaption: String {
        widgetLS(isIqamah ? "widget.iqamah" : "widget.adhan", locale: locale).uppercased()
    }

    /// One row per prayer in the group. Friday Jummah rows stand in for Dhuhr.
    func listRows(for group: ListGroup) -> [MasjidlyWidgetPrayerRow] {
        let all = state.rows + [state.sunriseRow].compactMap { $0 }
        return group.prayerIds.compactMap { id in
            let matches = all.filter { $0.id == id || (id == "dhuhr" && $0.id.hasPrefix("jummah")) }
            return matches.first(where: \.isNext) ?? matches.first
        }
    }
}

private enum ListGroup {
    case morning, evening

    var prayerIds: [String] {
        switch self {
        case .morning: ["fajr", "sunrise", "dhuhr"]
        case .evening: ["asr", "maghrib", "isha"]
        }
    }
}

private struct LockScreenTime {
    let clock: String
    let meridiem: String

    init(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let clock = trimmed.prefix { $0.isNumber || $0 == ":" || $0 == "٫" }
        if clock.isEmpty {
            self.clock = trimmed
            meridiem = ""
        } else {
            self.clock = String(clock)
            meridiem = trimmed.dropFirst(clock.count).trimmingCharacters(in: .whitespaces)
        }
    }
}

struct MasjidlyLockScreenView: View {
    let entry: MasjidlyPrayerEntry
    let design: LockScreenDesign

    var body: some View {
        let model = LockScreenModel(entry)
        Group {
            if entry.state.kind != .content {
                unavailable
            } else {
                switch design {
                case .rectProgress: ProgressDesign(model: model)
                case .rectStrip: StripDesign(model: model)
                case .rectListMorning: ListDesign(model: model, group: .morning)
                case .rectListEvening: ListDesign(model: model, group: .evening)
                case .circMinutes: MinutesDesign(model: model)
                case .circCode: CodeDesign(model: model)
                }
            }
        }
        .environment(\.layoutDirection, ["ar", "ur"].contains(String(entry.locale.identifier.prefix(2))) ? .rightToLeft : .leftToRight)
        .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var unavailable: some View {
        switch design.family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "exclamationmark")
                    .font(.system(size: 17, weight: .semibold))
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("Masjidly")
                    .widgetFont(size: 17, weight: .semibold, locale: entry.locale)
                    .widgetFittingLine()
                Text(widgetLS("widget.open_app", locale: entry.locale))
                    .widgetFont(size: 12, locale: entry.locale)
                    .foregroundStyle(.secondary)
                    .widgetFittingLine()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Shared pieces

private struct CountdownLabel: View {
    let model: LockScreenModel
    var size: CGFloat = 11

    var body: some View {
        if let remaining = model.remaining, let target = model.state.targetDate {
            Group {
                if remaining < 7_200 {
                    Text(String(format: widgetLS("widget.in_format", locale: model.locale), model.abbreviatedRemaining))
                } else {
                    timerWithConnector(target: target)
                }
            }
            .widgetFont(size: size, weight: .medium, locale: model.locale)
            .widgetFittingLine(minimumScale: 0.7)
        }
    }
}

/// Live H:MM:SS timer. A timer Text takes all the width it is offered, so it gets a measured width.
private struct LockScreenTimer: View {
    let model: LockScreenModel
    let target: Date
    let size: CGFloat
    var weight: Font.Weight = .medium

    var body: some View {
        let font = widgetUIFont(size: size, weight: weight)
        let hourDigits = max(1, String(max(1, Int(model.remaining ?? 0) / 3_600)).count)
        let sample = "\(String(repeating: "9", count: hourDigits)):59:59" as NSString
        let width = ceil(sample.size(withAttributes: [.font: font]).width) + 3
        Text(timerInterval: model.now...target, countsDown: true, showsHours: true)
            .font(Font(font))
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .frame(width: width)
            .environment(\.locale, Locale(identifier: "en_GB"))
    }
}

extension CountdownLabel {
    /// The live timer wrapped in the localized "in %@" connector, so it reads like the static countdown.
    fileprivate func timerWithConnector(target: Date) -> some View {
        let parts = widgetLS("widget.in_format", locale: model.locale).components(separatedBy: "%@")
        let prefix = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let suffix = parts.dropFirst().first?.trimmingCharacters(in: .whitespaces) ?? ""
        return HStack(spacing: 3) {
            if !prefix.isEmpty { Text(prefix) }
            LockScreenTimer(model: model, target: target, size: size)
            if !suffix.isEmpty { Text(suffix) }
        }
    }
}

private struct MasjidNameLabel: View {
    let model: LockScreenModel
    var size: CGFloat = 9

    var body: some View {
        Text(model.state.mosqueDisplayName)
            .widgetFont(size: size, weight: .semibold, locale: model.locale)
            .foregroundStyle(.secondary)
            .widgetFittingLine(minimumScale: 0.7)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let knob = geometry.size.height
            let travel = max(0, geometry.size.width - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.3)).frame(height: knob * 0.4)
                Capsule().fill(.primary).frame(width: knob / 2 + travel * progress, height: knob * 0.4)
                Circle().fill(.primary).frame(width: knob, height: knob).offset(x: travel * progress)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct CircularFace<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            content.widgetAccessoryScaleToFit(designSize: CGSize(width: 54, height: 54))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .widgetAccentable()
    }
}

// MARK: - Rectangular designs

private struct ProgressDesign: View {
    let model: LockScreenModel

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            MasjidNameLabel(model: model)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 4) {
                Image(systemName: model.icon).font(.system(size: 13, weight: .semibold))
                Text(model.state.prayerName)
                    .widgetFont(size: 15, weight: .bold, locale: model.locale)
                    .widgetFittingLine()
                CountdownLabel(model: model)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(model.adhan.clock)
                        .widgetFont(size: 24, weight: .light, locale: model.locale)
                        .monospacedDigit()
                    Text(model.adhan.meridiem)
                        .widgetFont(size: 10, locale: model.locale)
                        .foregroundStyle(.secondary)
                }
                .widgetFittingLine()
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(widgetLS("widget.iqamah", locale: model.locale).uppercased())
                        .widgetFont(size: 7, weight: .semibold, locale: model.locale)
                        .foregroundStyle(.secondary)
                    Text(model.iqamah.clock)
                        .widgetFont(size: 14, weight: .bold, locale: model.locale)
                        .monospacedDigit()
                }
                .widgetFittingLine()
            }
            ProgressBar(progress: model.progress).frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetAccentable()
    }
}

private struct StripDesign: View {
    let model: LockScreenModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MasjidNameLabel(model: model)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 4) {
                Text(model.state.prayerName)
                    .widgetFont(size: 13, weight: .bold, locale: model.locale)
                    .widgetFittingLine()
                CountdownLabel(model: model, size: 12)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 0) {
                ForEach(model.state.rows.prefix(5)) { row in
                    VStack(spacing: 1) {
                        Image(systemName: MasjidlyWidgetState.iconName(forPrayerId: row.id))
                            .font(.system(size: 11, weight: .medium))
                        Text(LockScreenTime(row.adhan).clock)
                            .widgetFont(size: 11, weight: row.isNext ? .bold : .semibold, locale: model.locale)
                            .monospacedDigit()
                            .widgetFittingLine(minimumScale: 0.7)
                        Text(LockScreenTime(compactAccessoryIqamahLabel(row.iqamahs.first ?? "")).clock)
                            .widgetFont(size: 9, locale: model.locale)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .widgetFittingLine(minimumScale: 0.7)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background {
                        if row.isNext {
                            RoundedRectangle(cornerRadius: 7).fill(.primary.opacity(0.22))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetAccentable()
    }
}

private struct ListDesign: View {
    let model: LockScreenModel
    let group: ListGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MasjidNameLabel(model: model, size: 11)
                .frame(maxWidth: .infinity, alignment: .center)
            ForEach(model.listRows(for: group)) { row in
                HStack(spacing: 4) {
                    marker(for: row)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(row.name)
                            .widgetFont(size: 15, weight: row.isNext ? .bold : .medium, locale: model.locale)
                            .widgetFittingLine(minimumScale: 0.7)
                        if row.isTomorrow {
                            Text("(\(widgetLS("widget.tomorrow_short", locale: model.locale)))")
                                .widgetFont(size: 11, weight: .medium, locale: model.locale)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 2) {
                        time(LockScreenTime(row.adhan).clock, bold: row.isNext)
                        time(LockScreenTime(compactAccessoryIqamahLabel(row.iqamahs.first ?? "")).clock, bold: false)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetAccentable()
    }

    private func time(_ text: String, bold: Bool) -> some View {
        Text(text)
            .widgetFont(size: 14, weight: bold ? .bold : .regular, locale: model.locale)
            .monospacedDigit()
            .widgetFittingLine(minimumScale: 0.7)
            .frame(width: 32, alignment: .trailing)
    }

    @ViewBuilder
    private func marker(for row: MasjidlyWidgetPrayerRow) -> some View {
        if row.isPassed {
            Circle().fill(.primary).frame(width: 9, height: 9)
        } else {
            Circle().strokeBorder(.primary, lineWidth: row.isNext ? 2.5 : 1.5).frame(width: 9, height: 9)
        }
    }
}

// MARK: - Circular designs

private struct MinutesDesign: View {
    let model: LockScreenModel

    var body: some View {
        CircularFace {
            VStack(spacing: 0) {
                Text(model.isIqamah ? model.iqamahCaption : model.state.prayerName.uppercased())
                    .widgetFont(size: 8, weight: .bold, locale: model.locale)
                    .foregroundStyle(.secondary)
                    .widgetFittingLine()
                remaining
            }
            .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var remaining: some View {
        if let seconds = model.remaining, let target = model.state.targetDate {
            let minutes = Int(ceil(seconds / 60))
            if minutes < 100 {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(minutes)")
                        .widgetFont(size: 30, weight: .bold, locale: model.locale)
                        .monospacedDigit()
                    Text(model.minuteUnit)
                        .widgetFont(size: 11, weight: .semibold, locale: model.locale)
                }
                .widgetFittingLine(minimumScale: 0.6)
            } else {
                LockScreenTimer(model: model, target: target, size: 14, weight: .bold)
            }
        } else {
            Text(model.adhan.clock)
                .widgetFont(size: 20, weight: .bold, locale: model.locale)
                .monospacedDigit()
                .widgetFittingLine()
        }
    }
}

private struct CodeDesign: View {
    let model: LockScreenModel

    var body: some View {
        CircularFace {
            ZStack {
                Circle().stroke(.primary.opacity(0.3), lineWidth: 2.5)
                Circle().trim(from: 0, to: model.progress)
                    .stroke(.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(model.code)
                        .widgetFont(size: 14, weight: .bold, locale: model.locale)
                        .tracking(1)
                        .widgetFittingLine()
                    Text(model.adhan.clock)
                        .widgetFont(size: 15, weight: .semibold, locale: model.locale)
                        .monospacedDigit()
                        .widgetFittingLine()
                }
                .padding(.horizontal, 7)
            }
            .padding(4)
        }
    }
}

#Preview(as: .accessoryRectangular) {
    LockProgressWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryRectangular) {
    LockStripWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryRectangular) {
    LockListMorningWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryRectangular) {
    LockListEveningWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryCircular) {
    LockMinutesWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}

#Preview(as: .accessoryCircular) {
    LockCodeWidget()
} timeline: {
    MasjidlyPrayerEntry(date: Date(), state: .placeholder)
}
