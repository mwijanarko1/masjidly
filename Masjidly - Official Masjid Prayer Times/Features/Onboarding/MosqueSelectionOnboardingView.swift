import SwiftUI

struct LanguageSelectionOnboardingView: View {
    let timeTheme: HomeDesign.TimeTheme
    @Binding var selectedLanguage: AppLanguage
    let onContinue: (AppLanguage) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(timeTheme.usesLightForeground ? 0.32 : 0.18),
                    Color.black.opacity(timeTheme.usesLightForeground ? 0.16 : 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            OnboardingTutorialChrome.card(timeTheme: timeTheme) {
                VStack(spacing: 22) {
                    VStack(spacing: 4) {
                        Text("Choose your language")
                            .appFont(size: 22, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor)
                            .kerning(-0.4)
                            .multilineTextAlignment(.center)
                        Text("اختر لغتك")
                            .appFont(size: 22, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor)
                            .multilineTextAlignment(.center)
                        Text("اپنی زبان منتخب کریں")
                            .appFont(size: 22, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor)
                            .multilineTextAlignment(.center)
                        Text("Pilih bahasa")
                            .appFont(size: 22, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor)
                            .multilineTextAlignment(.center)
                    }

                    Text("You can change this later in Settings.")
                        .appFont(size: 15, weight: .regular)
                        .foregroundStyle(timeTheme.textColor.opacity(0.75))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 10) {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                selectedLanguage = language
                            } label: {
                                HStack(spacing: 12) {
                                    Text(language.nativeDisplayName)
                                        .appFont(size: 17, weight: .semibold)
                                        .foregroundStyle(timeTheme.textColor)
                                    Spacer()
                                    if selectedLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(HomeDesign.Colors.accent)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(timeTheme.textColor.opacity(selectedLanguage == language ? 0.16 : 0.07))
                                )
                            }
                            .buttonStyle(.hapticPlain)
                            .accessibilityIdentifier("Onboarding.Language.\(language.resolvedLanguageCode)")
                        }
                    }

                    Button {
                        onContinue(selectedLanguage)
                    } label: {
                        Text("Continue")
                            .onboardingPrimaryCapsule()
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityIdentifier("Onboarding.LanguageContinue")
                }
                .padding(24)
            }
            .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
            .frame(maxWidth: 400)
            .padding(.horizontal, 24)
        }
    }
}

private extension AppLanguage {
    var nativeDisplayName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        case .urdu: return "اردو"
        case .indonesian: return "Bahasa Indonesia"
        }
    }
}

struct LocationPermissionOnboardingView: View {
    let timeTheme: HomeDesign.TimeTheme
    let onAllow: () -> Void
    let onSkip: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(timeTheme.usesLightForeground ? 0.32 : 0.18),
                    Color.black.opacity(timeTheme.usesLightForeground ? 0.16 : 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            OnboardingTutorialChrome.card(timeTheme: timeTheme) {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Text(localized("onboarding.location.title"))
                            .appFont(size: 23, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor)
                            .kerning(-0.5)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text(localized("onboarding.location.message"))
                            .appFont(size: 16)
                            .foregroundStyle(timeTheme.textColor.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 12) {
                        Button(action: onAllow) {
                            Text(localized("onboarding.location.turn_on"))
                                .onboardingPrimaryCapsule()
                        }
                        .buttonStyle(.hapticPlain)
                        .accessibilityIdentifier("Onboarding.LocationAllow")

                        Button(action: onSkip) {
                            Text(localized("onboarding.location.skip"))
                                .appFont(size: 16, weight: .semibold)
                                .foregroundStyle(timeTheme.textColor.opacity(0.72))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.hapticPlain)
                        .accessibilityIdentifier("Onboarding.LocationSkip")
                    }
                }
                .padding(24)
            }
            .padding(.horizontal, 18)
        }
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}

struct MosqueSelectionOnboardingView: View {
    let mosques: [Mosque]
    let timeTheme: HomeDesign.TimeTheme
    var showsBackdrop: Bool = true
    @Binding var selectedMosqueId: String
    let isContinuing: Bool
    let onContinue: (Mosque) -> Void
    @Environment(\.locale) private var locale
    @State private var countryGroupingKey: String
    @State private var cityGroupingKey: String
    @State private var isSyncing = false
    @State private var activePicker: ActivePicker?

    private enum ActivePicker: Identifiable {
        case country, city, mosque
        var id: String {
            switch self {
            case .country: return "country"
            case .city: return "city"
            case .mosque: return "mosque"
            }
        }
    }

    init(
        mosques: [Mosque],
        timeTheme: HomeDesign.TimeTheme,
        showsBackdrop: Bool = true,
        selectedMosqueId: Binding<String>,
        isContinuing: Bool,
        onContinue: @escaping (Mosque) -> Void
    ) {
        self.mosques = mosques
        self.timeTheme = timeTheme
        self.showsBackdrop = showsBackdrop
        self._selectedMosqueId = selectedMosqueId
        self.isContinuing = isContinuing
        self.onContinue = onContinue

        // Seed country/city for valid pickers. Only preselect a mosque when one was provided
        // (e.g. closest-from-location). Never invent a default mosque.
        let visible = MosqueDefaults.visibleMosques(mosques)
        let preselected = visible.first(where: { $0.id == selectedMosqueId.wrappedValue })
        if let m = preselected {
            let ck = MosqueDefaults.countryGroupingKey(for: m)
            self._countryGroupingKey = State(initialValue: ck)
            self._cityGroupingKey = State(initialValue: m.cityGroupingKey)
        } else {
            let firstCountryKey = MosqueDefaults.countryOptions(from: mosques).first?.key ?? ""
            let firstCityKey = MosqueDefaults.cityOptions(from: mosques, countryKey: firstCountryKey).first?.key ?? ""
            self._countryGroupingKey = State(initialValue: firstCountryKey)
            self._cityGroupingKey = State(initialValue: firstCityKey)
        }
    }

    private var countryOptions: [(key: String, label: String)] {
        MosqueDefaults.countryOptions(from: mosques)
    }

    private var cityOptions: [(key: String, label: String)] {
        MosqueDefaults.cityOptions(from: mosques, countryKey: countryGroupingKey)
    }

    private var mosquesInSelectedCity: [Mosque] {
        let countryMosques: [Mosque]
        if countryGroupingKey.isEmpty {
            countryMosques = MosqueDefaults.visibleMosques(mosques)
        } else {
            countryMosques = MosqueDefaults.mosques(inCountryGroupingKey: countryGroupingKey, mosques: mosques)
        }
        guard !cityGroupingKey.isEmpty else { return countryMosques }
        return MosqueDefaults.mosques(inCityGroupingKey: cityGroupingKey, mosques: countryMosques)
    }

    private var selectedMosqueDisplayName: String {
        if let selected = mosquesInSelectedCity.first(where: { $0.id == selectedMosqueId }) {
            return selected.name
        }
        // Empty selection must not look like a default mosque is chosen.
        return ""
    }

    var body: some View {
        Group {
            if showsBackdrop {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(timeTheme.usesLightForeground ? 0.32 : 0.18),
                            Color.black.opacity(timeTheme.usesLightForeground ? 0.16 : 0.08),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    pickerCard
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 18)
                }
            } else {
                pickerCard
            }
        }
        .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
        .onChange(of: countryGroupingKey) { _, newKey in
            guard !isSyncing else { return }
            // Jump directly to the first valid city to avoid "" as an invalid Picker tag.
            let inCountryMosques: [Mosque]
            if newKey.isEmpty {
                inCountryMosques = MosqueDefaults.visibleMosques(mosques)
            } else {
                inCountryMosques = MosqueDefaults.mosques(inCountryGroupingKey: newKey, mosques: mosques)
            }
            let inCountryOpts = MosqueDefaults.cityOptions(from: mosques, countryKey: newKey)
            if let m = inCountryMosques.first(where: { $0.id == selectedMosqueId }),
               m.cityGroupingKey != cityGroupingKey {
                cityGroupingKey = m.cityGroupingKey
            } else if let firstKey = inCountryOpts.first?.key {
                cityGroupingKey = firstKey
            }
        }
        .onChange(of: cityGroupingKey) { _, newKey in
            guard !isSyncing else { return }
            syncMosqueToCity(newKey)
        }
        .onChange(of: selectedMosqueId) { _, newId in
            guard let m = mosques.first(where: { $0.id == newId }) else { return }
            isSyncing = true
            let newCountry = MosqueDefaults.countryGroupingKey(for: m)
            if newCountry != countryGroupingKey {
                countryGroupingKey = newCountry
            }
            if m.cityGroupingKey != cityGroupingKey {
                cityGroupingKey = m.cityGroupingKey
            }
            isSyncing = false
        }
    }

    private var pickerCard: some View {
        OnboardingTutorialChrome.card(timeTheme: timeTheme) {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(localized("onboarding.mosque.title"))
                        .appFont(size: 23, weight: .semibold)
                        .foregroundStyle(timeTheme.textColor)
                        .kerning(-0.5)
                        .multilineTextAlignment(.center)

                    Text(localized("onboarding.mosque.message"))
                        .appFont(size: 16, weight: .regular)
                        .foregroundStyle(timeTheme.textColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    pickerSection(
                        kind: .country,
                        title: localized("settings.country.picker"),
                        value: countryOptions.first(where: { $0.key == countryGroupingKey })?.label ?? "",
                        options: countryOptions.map { SearchablePickerOption(id: $0.key, label: $0.label) },
                        selectedId: countryGroupingKey,
                        searchPlaceholder: "Search countries…",
                        accessibilityId: "Onboarding.CountryPicker",
                        onSelect: { countryGroupingKey = $0 }
                    )

                    OnboardingPickerDivider(timeTheme: timeTheme)

                    pickerSection(
                        kind: .city,
                        title: localized("settings.city.picker"),
                        value: cityOptions.first(where: { $0.key == cityGroupingKey })?.label ?? "",
                        options: cityOptions.map { SearchablePickerOption(id: $0.key, label: $0.label) },
                        selectedId: cityGroupingKey,
                        searchPlaceholder: "Search cities…",
                        accessibilityId: "Onboarding.CityPicker",
                        onSelect: { cityGroupingKey = $0 }
                    )

                    OnboardingPickerDivider(timeTheme: timeTheme)

                    pickerSection(
                        kind: .mosque,
                        title: localized("settings.mosque.picker"),
                        value: selectedMosqueDisplayName,
                        options: mosquesInSelectedCity.map { SearchablePickerOption(id: $0.id, label: $0.name) },
                        selectedId: selectedMosqueId,
                        searchPlaceholder: "Search mosques…",
                        accessibilityId: "Onboarding.MosquePicker",
                        onSelect: { selectedMosqueId = $0 }
                    )
                }

                Button {
                    guard let mosque = mosquesInSelectedCity.first(where: { $0.id == selectedMosqueId }) else { return }
                    onContinue(mosque)
                } label: {
                    Text(localized("onboarding.continue"))
                        .onboardingPrimaryCapsule()
                }
                .buttonStyle(.hapticPlain)
                .disabled(selectedMosqueId.isEmpty || mosquesInSelectedCity.isEmpty || isContinuing)
                .opacity(selectedMosqueId.isEmpty || mosquesInSelectedCity.isEmpty || isContinuing ? 0.45 : 1)
                .accessibilityIdentifier("Onboarding.MosqueContinue")
            }
            .padding(24)
        }
    }

    private func pickerSection(
        kind: ActivePicker,
        title: String,
        value: String,
        options: [SearchablePickerOption],
        selectedId: String,
        searchPlaceholder: String,
        accessibilityId: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        let isOpen = activePicker == kind
        return SearchablePickerField(
            title: title,
            value: value,
            options: options,
            selectedId: selectedId,
            timeTheme: timeTheme,
            searchPlaceholder: searchPlaceholder,
            titleFontSize: 18,
            valueFontSize: 18,
            minRowHeight: 52,
            horizontalPadding: 24,
            multilineValue: kind == .mosque,
            isOpen: isOpen,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    activePicker = isOpen ? nil : kind
                }
            },
            onSelect: { id in
                onSelect(id)
                withAnimation(.easeInOut(duration: 0.22)) {
                    activePicker = nil
                }
            }
        )
        .accessibilityIdentifier(accessibilityId)
    }

    private func syncMosqueToCity(_ key: String) {
        let countryMosques: [Mosque]
        if countryGroupingKey.isEmpty {
            countryMosques = MosqueDefaults.visibleMosques(mosques)
        } else {
            countryMosques = MosqueDefaults.mosques(inCountryGroupingKey: countryGroupingKey, mosques: mosques)
        }
        let list: [Mosque]
        if key.isEmpty {
            list = countryMosques
        } else {
            list = MosqueDefaults.mosques(inCityGroupingKey: key, mosques: countryMosques)
        }
        // Keep an empty selection empty so location (or the user) chooses the mosque.
        guard !selectedMosqueId.isEmpty else { return }
        if !list.contains(where: { $0.id == selectedMosqueId }) {
            selectedMosqueId = list.first?.id ?? ""
        }
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}

private struct OnboardingPickerDivider: View {
    let timeTheme: HomeDesign.TimeTheme

    var body: some View {
        Rectangle()
            .fill(timeTheme.textColor.opacity(0.12))
            .frame(height: 0.5)
            .padding(.horizontal, 24)
    }
}
