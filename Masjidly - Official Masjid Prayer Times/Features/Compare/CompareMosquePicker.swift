import SwiftUI

/// Multi-select masjid picker for Compare. Masjids from every city, grouped by city, with search.
struct CompareMosquePicker: View {
    let mosques: [Mosque]
    let homeMosqueId: String?
    let model: CompareViewModel
    let appearance: HomeDesign.ResolvedTheme
    let locale: Locale

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var visible: [Mosque] { MosqueDefaults.visibleMosques(mosques) }

    private var groups: [(key: String, label: String, mosques: [Mosque])] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty
            ? visible
            : visible.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.cityDisplayName.localizedCaseInsensitiveContains(query)
            }
        return MosqueDefaults.cityOptions(from: filtered).map { option in
            (option.key, option.label, MosqueDefaults.mosques(inCityGroupingKey: option.key, mosques: filtered))
        }
    }

    var body: some View {
        ZStack {
            AtmosphericSkyBackground(sky: appearance.sky)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                if !model.canAddMore {
                    Text(compareLS("compare.limit", locale: locale))
                        .appFont(size: 13, weight: .medium)
                        .foregroundStyle(appearance.textColor.opacity(0.7))
                        .padding(.top, 8)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups, id: \.key) { group in
                            Section {
                                ForEach(group.mosques) { mosque in
                                    row(mosque)
                                }
                            } header: {
                                Text(group.label)
                                    .appFont(size: 13, weight: .semibold)
                                    .foregroundStyle(appearance.textColor.opacity(0.65))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.ultraThinMaterial)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(appearance.usesLightForeground ? .dark : .light)
    }

    private var header: some View {
        HStack {
            Text(compareLS("compare.add", locale: locale))
                .appFont(size: 20, weight: .semibold)
                .foregroundStyle(appearance.textColor)
            Spacer()
            Button {
                HapticFeedback.buttonTap()
                dismiss()
            } label: {
                Text(compareLS("compare.done", locale: locale))
                    .appFont(size: 16, weight: .semibold)
                    .foregroundStyle(appearance.usesLightForeground ? Color.black : Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(appearance.textColor.opacity(0.92)))
            }
            .buttonStyle(.hapticPlain)
            .accessibilityIdentifier("Compare.Picker.Done")
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(appearance.textColor.opacity(0.6))
            TextField(compareLS("compare.search", locale: locale), text: $search)
                .appFont(size: 16)
                .foregroundStyle(appearance.textColor)
                .autocorrectionDisabled()
                .accessibilityIdentifier("Compare.Picker.Search")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(appearance.textColor.opacity(0.1)))
    }

    private func row(_ mosque: Mosque) -> some View {
        let listed = model.isListed(mosque)
        let isYours = model.isYours(mosque)
        let disabled = isYours || (!listed && !model.canAddMore)
        return Button {
            HapticFeedback.buttonTap()
            if listed {
                model.remove(mosque)
            } else {
                model.add(mosque)
            }
        } label: {
            HStack(spacing: 12) {
                Text(mosque.name)
                    .appFont(size: 16, weight: mosque.id == homeMosqueId ? .semibold : .regular)
                    .foregroundStyle(appearance.textColor)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: listed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(listed ? HomeDesign.Colors.accent : appearance.textColor.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .opacity(isYours ? 0.6 : (disabled ? 0.4 : 1))
        }
        .buttonStyle(.hapticPlain)
        .disabled(disabled)
        .accessibilityAddTraits(listed ? .isSelected : [])
        .accessibilityIdentifier("Compare.Picker.Row.\(mosque.slug)")
    }
}
