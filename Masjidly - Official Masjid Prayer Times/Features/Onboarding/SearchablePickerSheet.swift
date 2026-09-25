import SwiftUI

struct SearchablePickerOption: Identifiable, Equatable, Hashable {
    let id: String
    let label: String
}

/// Compact glass-select dropdown panel: search + scrollable options under a picker row.
struct SearchableDropdownPanel: View {
    let options: [SearchablePickerOption]
    let selectedId: String
    let timeTheme: HomeDesign.TimeTheme
    var searchPlaceholder: String = "Search…"
    var autoFocusSearch: Bool = false
    let onSelect: (String) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [SearchablePickerOption] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return options }
        return options.filter {
            $0.label.lowercased().contains(q) || $0.id.lowercased().contains(q)
        }
    }

    private var selectedBackground: Color {
        HomeDesign.Colors.accent.opacity(timeTheme.usesLightForeground ? 0.32 : 0.16)
    }

    /// Fixed height so the option list cannot collapse inside nested ScrollViews/cards.
    private var listHeight: CGFloat {
        let rowHeight: CGFloat = 44
        let count = max(filtered.count, 1)
        return min(260, CGFloat(count) * rowHeight + 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .appFont(size: 14, weight: .medium)
                    .foregroundStyle(timeTheme.textColor.opacity(0.45))

                TextField(searchPlaceholder, text: $query)
                    .appFont(size: 14, weight: .regular)
                    .foregroundStyle(timeTheme.textColor)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($searchFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(timeTheme.textColor.opacity(timeTheme.usesLightForeground ? 0.18 : 0.12))
                    .frame(height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    if filtered.isEmpty {
                        Text("No matches.")
                            .appFont(size: 13, weight: .regular)
                            .foregroundStyle(timeTheme.textColor.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(filtered) { option in
                            Button {
                                HapticFeedback.buttonTap()
                                onSelect(option.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                        .appFont(size: 13, weight: .semibold)
                                        .foregroundStyle(timeTheme.textColor)
                                        .opacity(option.id == selectedId ? 1 : 0)
                                        .frame(width: 16)

                                    Text(option.label)
                                        .appFont(size: 14, weight: .medium)
                                        .foregroundStyle(timeTheme.textColor)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(option.id == selectedId ? selectedBackground : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.hapticPlain)
                        }
                    }
                }
                .padding(4)
            }
            .frame(height: listHeight)
        }
        .background {
            dropdownChrome
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(timeTheme.textColor.opacity(timeTheme.usesLightForeground ? 0.18 : 0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(timeTheme.usesLightForeground ? 0.28 : 0.12), radius: 16, y: 8)
        .onAppear {
            guard autoFocusSearch else { return }
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
    }

    private var dropdownChrome: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(.ultraThinMaterial)
            if timeTheme.usesLightForeground {
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.92), Color.white.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

/// Label + value row with an inline searchable dropdown panel.
struct SearchablePickerField: View {
    let title: String
    let value: String
    let options: [SearchablePickerOption]
    let selectedId: String
    let timeTheme: HomeDesign.TimeTheme
    var searchPlaceholder: String = "Search…"
    var titleFontSize: CGFloat = 17
    var valueFontSize: CGFloat = 17
    var minRowHeight: CGFloat = 44
    var horizontalPadding: CGFloat = 0
    var multilineValue: Bool = false
    let isOpen: Bool
    let onToggle: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(alignment: multilineValue ? .top : .firstTextBaseline, spacing: 12) {
                    Text(title)
                        .appFont(size: titleFontSize, weight: .regular)
                        .foregroundStyle(timeTheme.textColor)
                        .lineLimit(1)
                        .layoutPriority(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 12)

                    HStack(alignment: .top, spacing: 6) {
                        Text(value)
                            .appFont(size: valueFontSize, weight: .regular)
                            .foregroundStyle(timeTheme.textColor)
                            .lineLimit(multilineValue ? nil : 1)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: multilineValue)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Image(systemName: "chevron.down")
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor.opacity(0.7))
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                            .animation(.easeInOut(duration: 0.22), value: isOpen)
                            .padding(.top, multilineValue ? 2 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, minHeight: minRowHeight, alignment: .center)
                .padding(.horizontal, horizontalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)

            if isOpen {
                SearchableDropdownPanel(
                    options: options,
                    selectedId: selectedId,
                    timeTheme: timeTheme,
                    searchPlaceholder: searchPlaceholder,
                    onSelect: onSelect
                )
                .padding(.horizontal, max(horizontalPadding, 8))
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isOpen)
    }
}
