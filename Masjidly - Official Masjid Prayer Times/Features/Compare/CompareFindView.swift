import SwiftUI

struct CompareFindView: View {
    @Bindable var model: CompareViewModel
    let settings: SettingsStore
    let appearance: HomeDesign.ResolvedTheme
    let locale: Locale
    let onOpen: (Mosque) -> Void

    @State private var showingTimeSheet = false
    @State private var cityOpen = false

    var body: some View {
        let result = model.findResult
        let progress = model.loadProgress
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                controls
                resultsHeader
                if result.hits.isEmpty && !model.isLoadingFind {
                    emptyResults
                } else {
                    ForEach(result.hits) { hit in
                        resultRow(hit)
                    }
                }
                footer(result: result, progress: progress)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showingTimeSheet) { timeSheet }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            cityPicker

            HStack(spacing: 0) {
                TextTabs(
                    options: [
                        (CompareTimeType.adhan, compareLS("compare.find.adhan", locale: locale), "Compare.Find.Type.adhan"),
                        (CompareTimeType.jamaat, compareLS("compare.find.jamaat", locale: locale), "Compare.Find.Type.jamaat"),
                    ],
                    selection: model.query.type,
                    appearance: appearance,
                    fontSize: 16,
                    equalWidth: false
                ) { model.query.type = $0 }
                .accessibilityIdentifier("Compare.Find.Type")

                Spacer(minLength: 40)

                TextTabs(
                    options: [
                        (CompareDirection.before, compareLS("compare.find.before", locale: locale), "Compare.Find.Direction.before"),
                        (CompareDirection.after, compareLS("compare.find.after", locale: locale), "Compare.Find.Direction.after"),
                    ],
                    selection: model.query.direction,
                    appearance: appearance,
                    fontSize: 16,
                    equalWidth: false
                ) { model.query.direction = $0 }
                .accessibilityIdentifier("Compare.Find.Direction")
            }

            TextTabs(
                options: prayerOptions,
                selection: model.query.prayer,
                appearance: appearance,
                fontSize: 14,
                equalWidth: true
            ) { model.query.prayer = $0 }
            .accessibilityIdentifier("Compare.Find.Prayer")

            timeStepper
                .frame(maxWidth: .infinity)

            if let prayer = model.query.prayer, let yours = model.yourJamaatMinutes(for: prayer) {
                laterThanYoursButton(yours: yours)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var prayerOptions: [(ComparePrayer?, String, String)] {
        var options: [(ComparePrayer?, String, String)] = [
            (nil, compareLS("compare.find.any", locale: locale), "Compare.Find.Prayer.any"),
        ]
        for prayer in ComparePrayer.allCases {
            options.append((
                prayer,
                PrayerLocalization.displayName(canonicalEnglish: prayer.canonicalName(isJummah: model.isFriday), locale: locale),
                "Compare.Find.Prayer.\(prayer.rawValue)"
            ))
        }
        return options
    }

    private var cityPicker: some View {
        SearchablePickerField(
            title: compareLS("compare.find.city", locale: locale),
            value: model.cityLabel,
            options: model.cityOptions.map { SearchablePickerOption(id: $0.key, label: $0.label) },
            selectedId: model.cityKey,
            timeTheme: appearance.timeTheme,
            searchPlaceholder: "Search cities…",
            centersRow: true,
            isOpen: cityOpen,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.22)) { cityOpen.toggle() }
            },
            onSelect: { key in
                model.cityKey = key
                withAnimation(.easeInOut(duration: 0.22)) { cityOpen = false }
            }
        )
        .accessibilityIdentifier("Compare.Find.City")
    }

    /// Bare minus, a large time and plus. Tap the time for an exact wheel.
    private var timeStepper: some View {
        HStack(spacing: 12) {
            stepButton(systemName: "minus", delta: -5, labelKey: "compare.find.nudgeEarlier", id: "Compare.Find.NudgeEarlier")
            Button {
                HapticFeedback.buttonTap()
                showingTimeSheet = true
            } label: {
                HStack(spacing: 8) {
                    Text(timeText)
                        .appFont(size: 40, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(appearance.textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(appearance.textColor.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(appearance.textColor.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(appearance.textColor.opacity(0.25), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)
            .accessibilityLabel(Text("\(compareLS("compare.find.time", locale: locale)): \(timeText)"))
            .accessibilityIdentifier("Compare.Find.Time")
            stepButton(systemName: "plus", delta: 5, labelKey: "compare.find.nudgeLater", id: "Compare.Find.NudgeLater")
        }
    }

    private func stepButton(systemName: String, delta: Int, labelKey: String, id: String) -> some View {
        Button {
            HapticFeedback.buttonTap()
            model.nudgeMinutes(delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(appearance.textColor.opacity(0.75))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(Text(compareLS(labelKey, locale: locale)))
        .accessibilityIdentifier(id)
    }

    private var timeSheet: some View {
        ZStack {
            AtmosphericSkyBackground(sky: appearance.sky)
                .ignoresSafeArea()
            VStack(spacing: 4) {
                HStack {
                    Text(compareLS("compare.find.time", locale: locale))
                        .appFont(size: 18, weight: .semibold)
                        .foregroundStyle(appearance.textColor)
                    Spacer()
                    Button {
                        HapticFeedback.buttonTap()
                        showingTimeSheet = false
                    } label: {
                        Text(compareLS("compare.done", locale: locale))
                            .appFont(size: 16, weight: .semibold)
                            .foregroundStyle(appearance.usesLightForeground ? Color.black : Color.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(appearance.textColor.opacity(0.92)))
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("Compare.Find.TimeDone")
                }
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.timeZone, PrayerTimesEngine.sheffieldTimeZone)
                    .environment(\.locale, Locale(identifier: settings.uses24HourTime ? "en_GB" : "en_US"))
                    .accessibilityIdentifier("Compare.Find.TimeWheel")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .preferredColorScheme(appearance.usesLightForeground ? .dark : .light)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private func laterThanYoursButton(yours: Int) -> some View {
        let clock = String(format: "%02d:%02d", yours / 60, yours % 60)
        let shown = PrayerTimesEngine.formatPrayerTimeForDisplay(clock, uses24Hour: settings.uses24HourTime, locale: locale)
        return Button {
            HapticFeedback.buttonTap()
            model.searchLaterThanYours()
        } label: {
            Text(String(format: compareLS("compare.find.laterThanYours", locale: locale), shown))
                .appFont(size: 14, weight: .medium)
                .foregroundStyle(appearance.textColor.opacity(0.75))
                .underline()
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityIdentifier("Compare.Find.LaterThanYours")
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
                let minutes = model.query.minutes
                return cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: model.date) ?? model.date
            },
            set: { newValue in
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = PrayerTimesEngine.sheffieldTimeZone
                let parts = cal.dateComponents([.hour, .minute], from: newValue)
                model.query.minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    // MARK: - Results

    private var timeText: String {
        let hh = String(format: "%02d:%02d", model.query.minutes / 60, model.query.minutes % 60)
        return PrayerTimesEngine.formatPrayerTimeForDisplay(hh, uses24Hour: settings.uses24HourTime, locale: locale)
    }

    private var headerKey: String {
        switch (model.query.type, model.query.direction) {
        case (.jamaat, .after): return "compare.find.header.jamaatAfter"
        case (.jamaat, .before): return "compare.find.header.jamaatBefore"
        case (.adhan, .after): return "compare.find.header.adhanAfter"
        case (.adhan, .before): return "compare.find.header.adhanBefore"
        }
    }

    private var emptyKey: String {
        switch (model.query.type, model.query.direction) {
        case (.jamaat, .after): return "compare.find.empty"
        case (.jamaat, .before): return "compare.find.empty.jamaatBefore"
        case (.adhan, .after): return "compare.find.empty.adhanAfter"
        case (.adhan, .before): return "compare.find.empty.adhanBefore"
        }
    }

    private var resultsHeader: some View {
        Text(String(format: compareLS(headerKey, locale: locale), timeText, model.cityLabel))
            .appFont(size: 16, weight: .semibold)
            .foregroundStyle(appearance.textColor)
            .padding(.top, 4)
    }

    private var emptyResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: compareLS(emptyKey, locale: locale), timeText))
                .appFont(size: 15)
                .foregroundStyle(appearance.textColor.opacity(0.75))
            if model.isToday {
                Button {
                    HapticFeedback.buttonTap()
                    model.stepDay(1)
                } label: {
                    Text(compareLS("compare.find.nextDay", locale: locale))
                        .appFont(size: 14, weight: .semibold)
                        .foregroundStyle(appearance.usesLightForeground ? Color.black : Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(appearance.textColor.opacity(0.92)))
                }
                .buttonStyle(.hapticPlain)
                .accessibilityIdentifier("Compare.Find.NextDay")
            }
        }
    }

    private func resultRow(_ hit: CompareFindHit) -> some View {
        let isJummah = model.isFriday
        let prayerName = PrayerLocalization.displayName(canonicalEnglish: hit.prayer.canonicalName(isJummah: isJummah), locale: locale)
        let time = PrayerTimesEngine.formatPrayerTimeForDisplay(hit.raw, uses24Hour: settings.uses24HourTime, locale: locale)
        let relative = relativeText(for: hit)
        return HStack(alignment: .center, spacing: 10) {
            Button {
                onOpen(hit.mosque)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        if model.query.prayer == nil {
                            Text(prayerName)
                                .appFont(size: 12, weight: .medium)
                                .foregroundStyle(appearance.textColor.opacity(0.6))
                        }
                        Text(time)
                            .appFont(size: 18, weight: .semibold)
                            .foregroundStyle(appearance.textColor)
                    }
                    .frame(minWidth: 72, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.mosque.name)
                            .appFont(size: 15, weight: .medium)
                            .foregroundStyle(appearance.textColor)
                            .multilineTextAlignment(.leading)
                        if let relative {
                            Text(relative)
                                .appFont(size: 12)
                                .foregroundStyle(appearance.textColor.opacity(0.6))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(resultAccessibilityLabel(prayerName: prayerName, time: time, mosque: hit.mosque.name, relative: relative)))
            .accessibilityIdentifier("Compare.Result.\(hit.mosque.slug).\(hit.prayer.rawValue).\(hit.raw)")
        }
        .padding(.vertical, 6)
    }

    private func relativeText(for hit: CompareFindHit) -> String? {
        guard let delta = model.relativeMinutes(for: hit) else { return nil }
        if delta >= 0 {
            return String(format: compareLS("compare.find.inMinutes", locale: locale), delta)
        }
        return String(format: compareLS("compare.find.minutesAgo", locale: locale), -delta)
    }

    private func resultAccessibilityLabel(prayerName: String, time: String, mosque: String, relative: String?) -> String {
        var text = String(format: compareLS("compare.a11y.result", locale: locale), prayerName, time, mosque)
        if let relative { text += ", " + relative }
        return text
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(result: CompareFindResult, progress: (loaded: Int, total: Int)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if result.noFixedTimeCount > 0 {
                Text(String(format: compareLS("compare.find.noFixedTime", locale: locale), result.noFixedTimeCount))
                    .appFont(size: 13)
                    .foregroundStyle(appearance.textColor.opacity(0.65))
            }
            if model.isLoadingFind {
                Text(String(format: compareLS("compare.find.loading", locale: locale), progress.loaded, progress.total))
                    .appFont(size: 13)
                    .foregroundStyle(appearance.textColor.opacity(0.65))
            }
            if model.failedCount > 0 && !model.isLoadingFind {
                HStack(spacing: 10) {
                    Text(String(format: compareLS("compare.find.failed", locale: locale), model.failedCount))
                        .appFont(size: 13)
                        .foregroundStyle(appearance.textColor.opacity(0.65))
                    Button {
                        Task { await model.loadFind() }
                    } label: {
                        Text(compareLS("compare.retry", locale: locale))
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(appearance.textColor)
                            .underline()
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("Compare.Find.Retry")
                }
            }
        }
        .padding(.top, 8)
    }
}

/// Plain text tabs. The chosen option is solid with an underline, the rest are dimmed.
private struct TextTabs<Value: Hashable>: View {
    let options: [(Value, String, String)]
    let selection: Value
    let appearance: HomeDesign.ResolvedTheme
    let fontSize: CGFloat
    let equalWidth: Bool
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: equalWidth ? 0 : 16) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.0 == selection
                Button {
                    HapticFeedback.buttonTap()
                    onSelect(option.0)
                } label: {
                    VStack(spacing: 4) {
                        Text(option.1)
                            .appFont(size: fontSize, weight: selected ? .semibold : .regular)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(appearance.textColor.opacity(selected ? 1 : 0.55))
                        Capsule()
                            .fill(appearance.textColor)
                            .frame(height: 2)
                            .opacity(selected ? 1 : 0)
                    }
                    .frame(maxWidth: equalWidth ? .infinity : nil)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.hapticPlain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(option.2)
            }
        }
        .animation(.easeOut(duration: 0.18), value: selection)
    }
}
