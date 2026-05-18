import SwiftUI

struct MosqueSelectionOnboardingView: View {
    let mosques: [Mosque]
    let timeTheme: HomeDesign.TimeTheme
    @Binding var selectedMosqueId: String
    let onContinue: (Mosque) -> Void
    @Environment(\.locale) private var locale
    @State private var cityGroupingKey: String = ""

    private var cityOptions: [(key: String, label: String)] {
        MosqueDefaults.cityOptions(from: mosques)
    }

    private var mosquesInSelectedCity: [Mosque] {
        guard !cityGroupingKey.isEmpty else { return mosques }
        return MosqueDefaults.mosques(inCityGroupingKey: cityGroupingKey, mosques: mosques)
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
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text(localized("settings.city.picker"))
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor.opacity(0.55))
                            .textCase(.uppercase)
                            .tracking(0.4)

                        Picker(localized("settings.city.picker"), selection: $cityGroupingKey) {
                            ForEach(cityOptions, id: \.key) { opt in
                                Text(opt.label).tag(opt.key)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(timeTheme.textColor)
                        .appFont(size: 18, weight: .medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("Onboarding.CityPicker")

                        Text(localized("settings.section.mosque.title"))
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor.opacity(0.55))
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .padding(.top, 4)

                        Picker(localized("settings.section.mosque.title"), selection: $selectedMosqueId) {
                            ForEach(mosquesInSelectedCity) { mosque in
                                Text(mosque.name).tag(mosque.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(timeTheme.textColor)
                        .appFont(size: 18, weight: .medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("Onboarding.MosquePicker")
                    }

                    Button {
                        guard let mosque = mosquesInSelectedCity.first(where: { $0.id == selectedMosqueId }) ?? mosquesInSelectedCity.first else { return }
                        onContinue(mosque)
                    } label: {
                        Text(localized("onboarding.continue"))
                            .onboardingPrimaryCapsule()
                    }
                    .buttonStyle(.plain)
                    .disabled(mosquesInSelectedCity.isEmpty)
                    .opacity(mosquesInSelectedCity.isEmpty ? 0.45 : 1)
                    .accessibilityIdentifier("Onboarding.MosqueContinue")
                }
                .padding(24)
            }
            .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
            .frame(maxWidth: 380)
            .padding(.horizontal, 24)
        }
        .onAppear {
            seedCityIfNeeded()
        }
        .onChange(of: cityGroupingKey) { _, newKey in
            syncMosqueToCity(newKey)
        }
        .onChange(of: selectedMosqueId) { _, newId in
            if let m = mosques.first(where: { $0.id == newId }), m.cityGroupingKey != cityGroupingKey {
                cityGroupingKey = m.cityGroupingKey
            }
        }
    }

    private func seedCityIfNeeded() {
        if cityGroupingKey.isEmpty {
            if let m = mosques.first(where: { $0.id == selectedMosqueId }) {
                cityGroupingKey = m.cityGroupingKey
            } else if let firstKey = cityOptions.first?.key {
                cityGroupingKey = firstKey
            }
        }
        syncMosqueToCity(cityGroupingKey)
    }

    private func syncMosqueToCity(_ key: String) {
        let list = MosqueDefaults.mosques(inCityGroupingKey: key, mosques: mosques)
        guard let first = list.first else { return }
        if !list.contains(where: { $0.id == selectedMosqueId }) {
            selectedMosqueId = first.id
        }
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}
