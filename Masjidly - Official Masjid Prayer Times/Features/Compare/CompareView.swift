import SwiftUI

func compareLS(_ key: String, locale: Locale) -> String {
    LocaleBundle.string(forKey: key, locale: locale)
}

struct CompareView: View {
    let mosques: [Mosque]
    let homeMosque: Mosque?
    let timeTheme: HomeDesign.TimeTheme
    let settings: SettingsStore
    let onOpenMosque: (Mosque) -> Void

    @State private var model: CompareViewModel
    @State private var showingPicker = false
    @Environment(\.dismiss) private var dismiss

    private var locale: Locale { settings.resolvedLocale }
    private var appearance: HomeDesign.ResolvedTheme { settings.resolvedAppearance(for: timeTheme) }

    init(
        mosques: [Mosque],
        homeMosque: Mosque?,
        timeTheme: HomeDesign.TimeTheme,
        settings: SettingsStore,
        store: CompareDataStore,
        initialDate: Date,
        onOpenMosque: @escaping (Mosque) -> Void
    ) {
        self.mosques = mosques
        self.homeMosque = homeMosque
        self.timeTheme = timeTheme
        self.settings = settings
        self.onOpenMosque = onOpenMosque
        _model = State(initialValue: CompareViewModel(
            mosques: mosques,
            homeMosque: homeMosque,
            settings: settings,
            store: store,
            initialDate: initialDate
        ))
    }

    private struct LoadKey: Hashable {
        let mode: CompareMode
        let day: TimeInterval
        let city: String
        let listed: [String]
    }

    private var loadKey: LoadKey {
        LoadKey(
            mode: model.mode,
            day: model.date.timeIntervalSince1970,
            city: model.mode == .byTime ? model.cityKey : "",
            listed: model.mode == .masjids ? model.listedMosques.map(\.id) : []
        )
    }

    var body: some View {
        ZStack {
            AtmosphericSkyBackground(sky: appearance.sky)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                modeSwitch
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                dayStepper
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                content
            }
        }
        .preferredColorScheme(appearance.usesLightForeground ? .dark : .light)
        .accessibilityIdentifier("Compare.Root")
        .task(id: loadKey) {
            switch model.mode {
            case .masjids: await model.loadMasjids()
            case .byTime: await model.loadFind()
            }
        }
        .onDisappear { model.cancelLoading() }
        .sheet(isPresented: $showingPicker) {
            CompareMosquePicker(
                mosques: mosques,
                homeMosqueId: homeMosque?.id,
                model: model,
                appearance: appearance,
                locale: locale
            )
            .environment(\.locale, locale)
            .environment(\.layoutDirection, settings.appLanguage.layoutDirection)
            .environment(\.appFontName, settings.appFontName)
        }
    }

    // MARK: - Chrome

    private var headerBar: some View {
        ZStack {
            Text(compareLS("compare.title", locale: locale))
                .appFont(size: 20, weight: .medium)
                .foregroundStyle(appearance.textColor)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button {
                    HapticFeedback.buttonTap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .appFont(size: 16, weight: .bold)
                        .foregroundColor(appearance.textColor)
                        .padding(8)
                        .background(Circle().fill(appearance.textColor.opacity(0.1)))
                }
                .buttonStyle(.hapticPlain)
                .accessibilityIdentifier("Compare.Close")
                .accessibilityLabel(Text(compareLS("compare.close", locale: locale)))
                Spacer()
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            modeSegment(.masjids, title: compareLS("compare.mode.masjids", locale: locale))
            modeSegment(.byTime, title: compareLS("compare.mode.byTime", locale: locale))
        }
        .padding(4)
        .background(Capsule().fill(appearance.textColor.opacity(0.1)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Compare.ModePicker")
    }

    private func modeSegment(_ mode: CompareMode, title: String) -> some View {
        let selected = model.mode == mode
        return Button {
            HapticFeedback.buttonTap()
            model.mode = mode
        } label: {
            Text(title)
                .appFont(size: 15, weight: selected ? .semibold : .regular)
                .foregroundStyle(selected
                    ? (appearance.usesLightForeground ? Color.black : Color.white)
                    : appearance.textColor.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? appearance.textColor.opacity(0.92) : Color.clear))
        }
        .buttonStyle(.hapticPlain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("Compare.Mode.\(mode.rawValue)")
    }

    private var dayStepper: some View {
        HStack {
            stepButton(systemName: "chevron.left", id: "Compare.DayPrev", delta: -1)
            Spacer()
            Text(dayTitle)
                .appFont(size: 17, weight: .medium)
                .foregroundStyle(appearance.textColor)
                .accessibilityIdentifier("Compare.DayTitle")
            Spacer()
            stepButton(systemName: "chevron.right", id: "Compare.DayNext", delta: 1)
        }
    }

    private func stepButton(systemName: String, id: String, delta: Int) -> some View {
        Button {
            HapticFeedback.buttonTap()
            model.stepDay(delta)
        } label: {
            Image(systemName: systemName)
                .appFont(size: 16, weight: .medium)
                .foregroundStyle(appearance.textColor)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.hapticPlain)
        .accessibilityIdentifier(id)
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter.string(from: model.date)
    }

    @ViewBuilder
    private var content: some View {
        switch model.mode {
        case .masjids:
            CompareMasjidsView(
                model: model,
                settings: settings,
                appearance: appearance,
                locale: locale,
                onAdd: { showingPicker = true },
                onOpen: openOnHome
            )
        case .byTime:
            CompareFindView(
                model: model,
                settings: settings,
                appearance: appearance,
                locale: locale,
                onOpen: openOnHome
            )
        }
    }

    private func openOnHome(_ mosque: Mosque) {
        HapticFeedback.buttonTap()
        onOpenMosque(mosque)
        dismiss()
    }
}
