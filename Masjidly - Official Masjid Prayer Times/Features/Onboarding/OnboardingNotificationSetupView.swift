import SwiftUI

struct OnboardingNotificationSetupView: View {
    let timeTheme: HomeDesign.TimeTheme
    @Binding var draft: OnboardingNotificationDraft
    let isSaving: Bool
    let onContinue: () -> Void
    @Environment(\.locale) private var locale
    @State private var adhanExpanded = true
    @State private var iqamahExpanded = true

    private let reminderOptions: [Int?] = [nil, 5, 10, 15, 30]

    private let prayerKeys: [(key: String, labelKey: String)] = [
        ("fajr", "settings.notification.fajr"),
        ("dhuhrJummah", "settings.notification.dhuhr_jummah"),
        ("asr", "settings.notification.asr"),
        ("maghrib", "settings.notification.maghrib"),
        ("isha", "settings.notification.isha"),
    ]

    var body: some View {
        GeometryReader { proxy in
            let minimumTopMargin: CGFloat = 80
            let topMargin = max(proxy.safeAreaInsets.top + 32, minimumTopMargin)
            let bottomMargin = proxy.safeAreaInsets.bottom + 24
            let availableHeight = max(280, proxy.size.height - topMargin - bottomMargin)

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

                VStack {
                    OnboardingTutorialChrome.card(timeTheme: timeTheme) {
                        VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localized("onboarding.notifications.title"))
                            .appFont(size: 23, weight: .semibold)
                            .foregroundStyle(timeTheme.textColor)
                            .kerning(-0.5)

                        Text(localized("onboarding.notifications.message"))
                            .appFont(size: 16, weight: .regular)
                            .foregroundStyle(timeTheme.textColor.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Scrollable prayer sections
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Adhan collapsible section
                            CollapsiblePrayerSection(
                                title: localized("onboarding.notifications.prayers_adhan"),
                                expanded: $adhanExpanded,
                                prayerKeys: prayerKeys,
                                draft: $draft,
                                channelType: .adhan,
                                timeTheme: timeTheme,
                                localized: localized
                            )

                            Divider()
                                .background(timeTheme.textColor.opacity(0.12))

                            // Iqamah collapsible section
                            CollapsiblePrayerSection(
                                title: localized("onboarding.notifications.prayers_iqamah"),
                                expanded: $iqamahExpanded,
                                prayerKeys: prayerKeys,
                                draft: $draft,
                                channelType: .iqamah,
                                timeTheme: timeTheme,
                                localized: localized
                            )

                            Divider()
                                .background(timeTheme.textColor.opacity(0.12))
                                .padding(.vertical, 4)

                            // Reminders section
                            VStack(alignment: .leading, spacing: 12) {
                                Text(localized("settings.reminders.title"))
                                    .appFont(size: 16, weight: .semibold)
                                    .foregroundStyle(timeTheme.textColor.opacity(0.6))
                                    .kerning(0.5)

                                HStack {
                                    Text(localized("settings.reminder.before_adhan"))
                                        .appFont(size: 16, weight: .regular)
                                        .foregroundStyle(timeTheme.textColor)
                                    Spacer()
                                    Picker(localized("settings.reminder.adhan_picker"), selection: $draft.preAdhanReminderMinutes) {
                                        ForEach(reminderOptions, id: \.self) { minutes in
                                            Text(reminderLabel(for: minutes)).tag(minutes)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(timeTheme.textColor)
                                    .accessibilityIdentifier("Onboarding.AdhanReminderPicker")
                                }

                                HStack {
                                    Text(localized("settings.reminder.before_iqamah"))
                                        .appFont(size: 16, weight: .regular)
                                        .foregroundStyle(timeTheme.textColor)
                                    Spacer()
                                    Picker(localized("settings.reminder.iqamah_picker"), selection: $draft.preIqamahReminderMinutes) {
                                        ForEach(reminderOptions, id: \.self) { minutes in
                                            Text(reminderLabel(for: minutes)).tag(minutes)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(timeTheme.textColor)
                                    .accessibilityIdentifier("Onboarding.IqamahReminderPicker")
                                }
                            }
                        }
                    }

                    Button {
                        onContinue()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(HomeDesign.Colors.activeGradient, in: Capsule())
                            } else {
                                Text(localized("onboarding.finish"))
                                    .onboardingPrimaryCapsule()
                            }
                        }
                    }
                    .buttonStyle(.hapticPlain)
                    .disabled(isSaving)
                    .accessibilityIdentifier("Onboarding.NotificationFinish")
                }
                        .toggleStyle(.switch)
                        .padding(24)
                    }
                    .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
                    .frame(
                        maxWidth: 400,
                        maxHeight: availableHeight,
                        alignment: .leading
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.top, topMargin)
                .padding(.bottom, bottomMargin)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
    }

    private func reminderLabel(for minutes: Int?) -> String {
        guard let minutes else { return localized("settings.reminder.off") }
        let format = localized("settings.reminder.minutes_format")
        return String(format: format, locale: locale, arguments: [minutes])
    }

    private func localized(_ key: String) -> String {
        LocaleBundle.string(forKey: key, locale: locale)
    }
}

// MARK: - Collapsible Prayer Section

private enum PrayerChannelType {
    case adhan
    case iqamah
}

private struct CollapsiblePrayerSection: View {
    let title: String
    @Binding var expanded: Bool
    let prayerKeys: [(key: String, labelKey: String)]
    @Binding var draft: OnboardingNotificationDraft
    let channelType: PrayerChannelType
    let timeTheme: HomeDesign.TimeTheme
    let localized: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(timeTheme.textColor)
                        .frame(width: 18, height: 18)
                    Text(title)
                        .appFont(size: 18, weight: .semibold)
                        .foregroundStyle(timeTheme.textColor)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
            }
            .buttonStyle(.hapticPlain)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(Array(prayerKeys.enumerated()), id: \.element.key) { index, prayer in
                        if index > 0 {
                            Divider()
                                .background(timeTheme.textColor.opacity(0.12))
                                .padding(.vertical, 2)
                        }
                        prayerToggle(prayer: prayer)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func prayerToggle(prayer: (key: String, labelKey: String)) -> some View {
        let getter: () -> Bool = {
            switch (channelType, prayer.key) {
            case (.adhan, "fajr"): return draft.adhanFajr
            case (.adhan, "dhuhrJummah"): return draft.adhanDhuhrJummah
            case (.adhan, "asr"): return draft.adhanAsr
            case (.adhan, "maghrib"): return draft.adhanMaghrib
            case (.adhan, "isha"): return draft.adhanIsha
            case (.iqamah, "fajr"): return draft.iqamahFajr
            case (.iqamah, "dhuhrJummah"): return draft.iqamahDhuhrJummah
            case (.iqamah, "asr"): return draft.iqamahAsr
            case (.iqamah, "maghrib"): return draft.iqamahMaghrib
            case (.iqamah, "isha"): return draft.iqamahIsha
            default: return true
            }
        }

        let setter: (Bool) -> Void = { newValue in
            switch (channelType, prayer.key) {
            case (.adhan, "fajr"): draft.adhanFajr = newValue
            case (.adhan, "dhuhrJummah"): draft.adhanDhuhrJummah = newValue
            case (.adhan, "asr"): draft.adhanAsr = newValue
            case (.adhan, "maghrib"): draft.adhanMaghrib = newValue
            case (.adhan, "isha"): draft.adhanIsha = newValue
            case (.iqamah, "fajr"): draft.iqamahFajr = newValue
            case (.iqamah, "dhuhrJummah"): draft.iqamahDhuhrJummah = newValue
            case (.iqamah, "asr"): draft.iqamahAsr = newValue
            case (.iqamah, "maghrib"): draft.iqamahMaghrib = newValue
            case (.iqamah, "isha"): draft.iqamahIsha = newValue
            default: break
            }
        }

        let binding = Binding<Bool>(get: getter, set: setter)

        Toggle(isOn: binding) {
            Text(localized(prayer.labelKey))
                .appFont(size: 16, weight: .medium)
                .foregroundStyle(timeTheme.textColor)
        }
        .tint(HomeDesign.Colors.accent)
        .frame(minHeight: 48)
        .padding(.vertical, 4)
        .padding(.trailing, 2)
    }
}
