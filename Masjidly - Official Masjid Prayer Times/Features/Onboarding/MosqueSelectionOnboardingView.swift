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

struct MosqueSelectionOnboardingView: View {
    let mosques: [Mosque]
    let timeTheme: HomeDesign.TimeTheme
    @Binding var selectedMosqueId: String
    let isContinuing: Bool
    let onContinue: (Mosque) -> Void
    @Environment(\.locale) private var locale
    @State private var countryGroupingKey: String
    @State private var cityGroupingKey: String
    @State private var isSyncing = false

    init(
        mosques: [Mosque],
        timeTheme: HomeDesign.TimeTheme,
        selectedMosqueId: Binding<String>,
        isContinuing: Bool,
        onContinue: @escaping (Mosque) -> Void
    ) {
        self.mosques = mosques
        self.timeTheme = timeTheme
        self._selectedMosqueId = selectedMosqueId
        self.isContinuing = isContinuing
        self.onContinue = onContinue

        // Seed country/city upfront so Pickers never see an empty invalid tag.
        let visible = MosqueDefaults.visibleMosques(mosques)
        let preselected = visible.first(where: { $0.id == selectedMosqueId.wrappedValue })
            ?? visible.first(where: { $0.slug == MosqueDefaults.defaultSlug })
            ?? visible.first
        if let m = preselected {
            let ck = MosqueDefaults.countryGroupingKey(for: m)
            self._countryGroupingKey = State(initialValue: ck)
            self._cityGroupingKey = State(initialValue: m.cityGroupingKey)
        } else {
            let firstCountryKey = MosqueDefaults.countryOptions(from: mosques).first?.key ?? ""
            self._countryGroupingKey = State(initialValue: firstCountryKey)
            let firstCityKey = MosqueDefaults.cityOptions(from: mosques, countryKey: firstCountryKey).first?.key ?? ""
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
        return mosquesInSelectedCity.first?.name ?? ""
    }

    var body: some View {
        ZStack {
            // Airy, atmospheric background gradient
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
                        OnboardingMenuPickerRow(
                            title: localized("settings.country.picker"),
                            value: countryOptions.first(where: { $0.key == countryGroupingKey })?.label ?? "",
                            options: countryOptions.map { OnboardingPickerOption(id: $0.key, label: $0.label) },
                            selection: $countryGroupingKey,
                            textColor: timeTheme.textColor
                        )
                        .accessibilityIdentifier("Onboarding.CountryPicker")

                        OnboardingPickerDivider(timeTheme: timeTheme)

                        OnboardingMenuPickerRow(
                            title: localized("settings.city.picker"),
                            value: cityOptions.first(where: { $0.key == cityGroupingKey })?.label ?? "",
                            options: cityOptions.map { OnboardingPickerOption(id: $0.key, label: $0.label) },
                            selection: $cityGroupingKey,
                            textColor: timeTheme.textColor
                        )
                        .accessibilityIdentifier("Onboarding.CityPicker")

                        OnboardingPickerDivider(timeTheme: timeTheme)

                        OnboardingMenuPickerRow(
                            title: localized("settings.mosque.picker"),
                            value: selectedMosqueDisplayName,
                            options: mosquesInSelectedCity.map { OnboardingPickerOption(id: $0.id, label: $0.name) },
                            selection: $selectedMosqueId,
                            textColor: timeTheme.textColor
                        )
                        .accessibilityIdentifier("Onboarding.MosquePicker")
                    }

                    Button {
                        guard let mosque = mosquesInSelectedCity.first(where: { $0.id == selectedMosqueId }) ?? mosquesInSelectedCity.first else { return }
                        onContinue(mosque)
                    } label: {
                        Text(localized("onboarding.continue"))
                            .onboardingPrimaryCapsule()
                    }
                    .buttonStyle(.hapticPlain)
                    .disabled(mosquesInSelectedCity.isEmpty || isContinuing)
                    .opacity(mosquesInSelectedCity.isEmpty || isContinuing ? 0.45 : 1)
                    .accessibilityIdentifier("Onboarding.MosqueContinue")
                }
                .padding(24)
            }
            .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
            .frame(maxWidth: 420)
            .padding(.horizontal, 18)
        }
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
        guard let first = list.first else { return }
        if !list.contains(where: { $0.id == selectedMosqueId }) {
            selectedMosqueId = first.id
        }
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}

private struct OnboardingPickerOption: Identifiable, Equatable {
    let id: String
    let label: String
}

private struct OnboardingMenuPickerRow: View, Equatable {
    let title: String
    let value: String
    let options: [OnboardingPickerOption]
    @Binding var selection: String
    let textColor: Color

    static func == (lhs: OnboardingMenuPickerRow, rhs: OnboardingMenuPickerRow) -> Bool {
        lhs.title == rhs.title && lhs.value == rhs.value && lhs.options == rhs.options
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .appFont(size: 18, weight: .regular)
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 14)

            Menu {
                ForEach(options) { option in
                    Button {
                        selection = option.id
                    } label: {
                        if option.id == selection {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 7) {
                    Text(value)
                        .appFont(size: 18, weight: .regular)
                        .foregroundStyle(textColor)
                        .lineLimit(nil)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Image(systemName: "chevron.down")
                        .appFont(size: 14, weight: .semibold)
                        .foregroundStyle(textColor.opacity(0.7))
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
            }
            .tint(textColor)
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
        .padding(.horizontal, 24)
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
