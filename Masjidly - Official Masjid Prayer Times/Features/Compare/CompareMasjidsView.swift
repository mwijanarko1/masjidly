import SwiftUI

struct CompareMasjidsView: View {
    let model: CompareViewModel
    let settings: SettingsStore
    let appearance: HomeDesign.ResolvedTheme
    let locale: Locale
    let onAdd: () -> Void
    let onOpen: (Mosque) -> Void

    @State private var editing = false

    var body: some View {
        if model.listedMosques.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                listHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                grid
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(compareLS("compare.empty.title", locale: locale))
                .appFont(size: 22, weight: .semibold)
                .foregroundStyle(appearance.textColor)
                .multilineTextAlignment(.center)
            Text(compareLS("compare.empty.body", locale: locale))
                .appFont(size: 16)
                .foregroundStyle(appearance.textColor.opacity(0.75))
                .multilineTextAlignment(.center)
            Button {
                HapticFeedback.buttonTap()
                onAdd()
            } label: {
                Label(compareLS("compare.add", locale: locale), systemImage: "plus")
                    .appFont(size: 16, weight: .semibold)
                    .foregroundStyle(appearance.usesLightForeground ? Color.black : Color.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(appearance.textColor.opacity(0.92)))
            }
            .buttonStyle(.hapticPlain)
            .padding(.top, 8)
            .accessibilityIdentifier("Compare.AddMasjid")
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Compare.EmptyState")
    }

    // MARK: - Top row

    private var listHeader: some View {
        HStack(spacing: 4) {
            HStack(spacing: 16) {
                typeTab(.adhan, key: "timetable.header.adhan")
                typeTab(.jamaat, key: "timetable.header.iqamah")
            }
            Spacer()
            if model.listedMosques.count > 1 {
            Button {
                HapticFeedback.buttonTap()
                withAnimation(.easeInOut(duration: 0.2)) { editing.toggle() }
            } label: {
                Text(compareLS(editing ? "compare.done" : "compare.edit", locale: locale))
                    .appFont(size: 15, weight: .semibold)
                    .foregroundStyle(appearance.textColor)
                    .padding(.horizontal, 8)
                    .frame(height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)
            .accessibilityIdentifier("Compare.EditToggle")
            }
            Button {
                HapticFeedback.buttonTap()
                onAdd()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(appearance.textColor)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)
            .accessibilityIdentifier("Compare.AddMasjid")
            .accessibilityLabel(Text(compareLS("compare.add", locale: locale)))
        }
    }

    private func typeTab(_ type: CompareTimeType, key: String) -> some View {
        let selected = model.gridTimeType == type
        return Button {
            HapticFeedback.buttonTap()
            withAnimation(.easeInOut(duration: 0.2)) { model.gridTimeType = type }
        } label: {
            Text(compareLS(key, locale: locale))
                .appFont(size: 16, weight: selected ? .semibold : .regular)
                .foregroundStyle(appearance.textColor.opacity(selected ? 1 : 0.55))
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(appearance.textColor)
                        .frame(height: 2)
                        .opacity(selected ? 1 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("Compare.Masjids.Type.\(type.rawValue)")
    }

    // MARK: - Grid

    private var grid: some View {
        let rows = model.rows
        let multiCity = Set(rows.map(\.mosque.cityGroupingKey)).count > 1
        let isJummah = model.isFriday

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(ComparePrayer.allCases, id: \.self) { prayer in
                        headerCell(prayer, isJummah: isJummah)
                    }
                }
                .padding(.top, 8)

                ForEach(rows) { row in
                    rowBlock(row, showCity: multiCity, isJummah: isJummah)
                }

                if rows.count == 1 {
                    Text(compareLS("compare.empty.body", locale: locale))
                        .appFont(size: 14)
                        .foregroundStyle(appearance.textColor.opacity(0.6))
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .onChange(of: model.listedMosques.count) { _, count in
            if count <= 1 { editing = false }
        }
    }

    private func headerCell(_ prayer: ComparePrayer, isJummah: Bool) -> some View {
        let name = PrayerLocalization.displayName(canonicalEnglish: prayer.canonicalName(isJummah: isJummah), locale: locale)
        let sort = model.sort
        let active = sort?.prayer == prayer
        let state = active
            ? compareLS(sort!.ascending ? "compare.sort.asc" : "compare.sort.desc", locale: locale)
            : ""
        return Button {
            HapticFeedback.buttonTap()
            model.tapHeader(prayer)
        } label: {
            HStack(spacing: 2) {
                Text(name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if active {
                    Image(systemName: sort!.ascending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .appFont(size: 13, weight: active ? .semibold : .regular)
            .foregroundStyle(appearance.textColor.opacity(active ? 1 : 0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(Text(state.isEmpty ? name : "\(name), \(state)"))
        .accessibilityIdentifier("Compare.Header.\(prayer.rawValue)")
    }

    // MARK: - Row

    private func rowBlock(
        _ row: CompareViewModel.Row,
        showCity: Bool,
        isJummah: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            nameLine(row, showCity: showCity)
            timesLine(row, isJummah: isJummah)
        }
        .padding(.vertical, 14)
    }

    private func nameLine(_ row: CompareViewModel.Row, showCity: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            if editing && !row.isYours {
                Button {
                    HapticFeedback.buttonTap()
                    withAnimation(.easeInOut(duration: 0.2)) { model.remove(row.mosque) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.red)
                        .frame(width: 24, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel(Text("\(compareLS("compare.remove", locale: locale)) \(row.mosque.name)"))
                .accessibilityIdentifier("Compare.Remove.\(row.mosque.slug)")
                .transition(.opacity)
            }
            Button {
                onOpen(row.mosque)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.mosque.name)
                        .appFont(size: 16, weight: .semibold)
                        .foregroundStyle(appearance.textColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if let note = noteText(row, showCity: showCity) {
                        Text(note)
                            .appFont(size: 12)
                            .foregroundStyle(appearance.textColor.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)
            .contextMenu {
                Button {
                    onOpen(row.mosque)
                } label: {
                    Label(compareLS("compare.openOnHome", locale: locale), systemImage: "house")
                }
                if !row.isYours {
                    Button(role: .destructive) {
                        model.remove(row.mosque)
                    } label: {
                        Label(compareLS("compare.remove", locale: locale), systemImage: "trash")
                    }
                }
            }
            .accessibilityIdentifier("Compare.Row.\(row.mosque.slug)")
        }
    }

    private func noteText(_ row: CompareViewModel.Row, showCity: Bool) -> String? {
        var parts: [String] = []
        if row.isYours { parts.append(compareLS("compare.yours", locale: locale)) }
        if showCity { parts.append(row.mosque.cityDisplayName) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func timesLine(
        _ row: CompareViewModel.Row,
        isJummah: Bool
    ) -> some View {
        if let times = row.times {
            HStack(alignment: .top, spacing: 0) {
                ForEach(ComparePrayer.allCases, id: \.self) { prayer in
                    cell(row: row, times: times, prayer: prayer, isJummah: isJummah)
                }
            }
        } else if case .loaded = row.state {
            HStack(alignment: .top, spacing: 0) {
                ForEach(ComparePrayer.allCases, id: \.self) { _ in
                    Text("-")
                        .appFont(size: 17)
                        .foregroundStyle(appearance.textColor.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            statusCell(row)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cell(row: CompareViewModel.Row, times: CompareDayTimes, prayer: ComparePrayer, isJummah: Bool) -> some View {
        let slots = times.iqamah[prayer] ?? []
        let delta = row.deltas[prayer]
        let adhan = times.adhan[prayer]
        let adhanSelected = model.gridTimeType == .adhan
        return VStack(spacing: 2) {
            if let adhan {
                Text(PrayerTimesEngine.formatPrayerTimeHeroParts(adhan, uses24Hour: settings.uses24HourTime, locale: locale).clock)
                    .appFont(size: adhanSelected ? 17 : 11, weight: adhanSelected ? .semibold : .regular)
                    .foregroundStyle(appearance.textColor.opacity(adhanSelected ? 1 : 0.5))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if adhanSelected {
                Text("-")
                    .appFont(size: 17)
                    .foregroundStyle(appearance.textColor.opacity(0.4))
            }
            if slots.isEmpty {
                if !adhanSelected {
                    Text("-")
                        .appFont(size: 17)
                        .foregroundStyle(appearance.textColor.opacity(0.4))
                }
            } else {
                ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                    if slot.minutes != nil {
                        Text(PrayerTimesEngine.formatPrayerTimeHeroParts(slot.raw, uses24Hour: settings.uses24HourTime, locale: locale).clock)
                            .appFont(size: adhanSelected ? 11 : 17, weight: adhanSelected ? .regular : .semibold)
                            .foregroundStyle(appearance.textColor.opacity(adhanSelected ? 0.5 : 1))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text(slot.raw)
                            .appFont(size: 11)
                            .foregroundStyle(appearance.textColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            if let delta {
                deltaPill(delta)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cellAccessibilityLabel(row: row, prayer: prayer, slots: slots, adhan: adhan, delta: delta, isJummah: isJummah)))
    }

    /// Earlier than yours is green, later is orange, the same is quiet.
    private func deltaPill(_ delta: Int) -> some View {
        let tint: Color = delta < 0 ? .green : (delta > 0 ? .orange : appearance.textColor)
        return Text(CompareDelta.displayLabel(delta))
            .appFont(size: 13, weight: .bold)
            .monospacedDigit()
            .foregroundStyle(delta == 0 ? appearance.textColor.opacity(0.6) : appearance.textColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(delta == 0 ? 0.12 : 0.30)))
            .overlay(Capsule().strokeBorder(tint.opacity(delta == 0 ? 0 : 0.55), lineWidth: 1))
    }

    private func cellAccessibilityLabel(row: CompareViewModel.Row, prayer: ComparePrayer, slots: [CompareSlot], adhan: String?, delta: Int?, isJummah: Bool) -> String {
        let prayerName = PrayerLocalization.displayName(canonicalEnglish: prayer.canonicalName(isJummah: isJummah), locale: locale)
        let value = slots.isEmpty
            ? "-"
            : slots.map { PrayerTimesEngine.formatPrayerTimeForDisplay($0.raw, uses24Hour: settings.uses24HourTime, locale: locale) }
                .joined(separator: ", ")
        var text = String(format: compareLS("compare.a11y.cell", locale: locale), row.mosque.name, prayerName, value)
        if let adhan {
            let adhanTime = PrayerTimesEngine.formatPrayerTimeForDisplay(adhan, uses24Hour: settings.uses24HourTime, locale: locale)
            text += ", \(compareLS("timetable.header.adhan", locale: locale)) \(adhanTime)"
        }
        if let delta {
            text += ", " + String(format: compareLS("compare.a11y.delta", locale: locale), CompareDelta.label(delta))
        }
        return text
    }

    @ViewBuilder
    private func statusCell(_ row: CompareViewModel.Row) -> some View {
        switch row.state {
        case .idle, .loading:
            ProgressView()
                .tint(appearance.textColor)
                .padding(.vertical, 6)
        case .offline:
            Text(compareLS("compare.error.offline", locale: locale))
                .appFont(size: 13)
                .foregroundStyle(appearance.textColor.opacity(0.7))
                .padding(.vertical, 6)
        case .failed:
            Button {
                Task { await model.loadMasjids() }
            } label: {
                Text(compareLS("compare.error.load", locale: locale))
                    .appFont(size: 13, weight: .medium)
                    .foregroundStyle(appearance.textColor.opacity(0.85))
                    .underline()
            }
            .buttonStyle(.hapticPlain)
            .padding(.vertical, 6)
        case .loaded:
            Text("-")
                .appFont(size: 17)
                .foregroundStyle(appearance.textColor.opacity(0.4))
                .padding(.vertical, 6)
        }
    }
}
