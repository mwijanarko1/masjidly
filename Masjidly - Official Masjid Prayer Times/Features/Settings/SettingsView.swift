import Observation
import SwiftUI

private func LS(_ key: String, locale: Locale) -> String {
    String(localized: String.LocalizationValue(stringLiteral: key), bundle: .main, locale: locale)
}

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    let timeTheme: HomeDesign.TimeTheme
    var onDismiss: (() -> Void)? = nil
    @Environment(SettingsStore.self) private var settings
    @Environment(OnboardingFlowController.self) private var onboarding
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    /// QuranScroll-style blending: same visual treatment as the screen behind each row — here the
    /// prayer gradient shows through instead of painting lighter “cards” on top.
    private var listRowBlend: Color { Color.clear }

    /// Shared horizontal inset so every row lines up on the same vertical rails.
    private var settingsRowInsets: EdgeInsets {
        EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    mosquePickerRow
                } header: {
                    mosqueSectionHeader
                }
                .listRowInsets(settingsRowInsets)
                .listRowBackground(listRowBlend)

                Section {
                    languagePickerRow
                } header: {
                    sectionCaption(localized("settings.language.title"))
                }
                .listRowInsets(settingsRowInsets)
                .listRowBackground(listRowBlend)

                Section {
                    SettingsToggleRow(
                        title: localized("settings.time.24h.title"),
                        isOn: Bindable(settings).uses24HourTime,
                        timeTheme: timeTheme
                    )
                } header: {
                    sectionCaption(localized("settings.section.display.title"))
                }
                .listRowInsets(settingsRowInsets)
                .listRowBackground(listRowBlend)

                Section {
                    SettingsToggleRow(
                        title: localized("settings.notifications.master.title"),
                        isOn: masterNotificationsBinding,
                        timeTheme: timeTheme
                    )

                    if settings.notifications.masterEnabled {
                        NotificationToggleRow(title: "Adhan", isOn: notificationChannelBinding(\.adhanEnabled), timeTheme: timeTheme)
                        NotificationToggleRow(title: "Iqamah", isOn: notificationChannelBinding(\.iqamahEnabled), timeTheme: timeTheme)
                        adhanReminderPickerRow
                        iqamahReminderPickerRow
                        NotificationToggleRow(title: localized("settings.notification.fajr"), isOn: binding(\.fajr), timeTheme: timeTheme)
                        NotificationToggleRow(title: localized("settings.notification.dhuhr_jummah"), isOn: binding(\.dhuhrJummah), timeTheme: timeTheme)
                        NotificationToggleRow(title: localized("settings.notification.asr"), isOn: binding(\.asr), timeTheme: timeTheme)
                        NotificationToggleRow(title: localized("settings.notification.maghrib"), isOn: binding(\.maghrib), timeTheme: timeTheme)
                        NotificationToggleRow(title: localized("settings.notification.isha"), isOn: binding(\.isha), timeTheme: timeTheme)
                    }
                } header: {
                    sectionCaption(localized("settings.notifications.title"))
                }
                .listRowInsets(settingsRowInsets)
                .listRowBackground(listRowBlend)

                #if DEBUG
                Section {
                    Button {
                        print("[Settings] Test tutorial tapped (dev)")
                    } label: {
                        Text("Test tutorial")
                            .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                            .foregroundColor(timeTheme.textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(settingsRowInsets)
                    .listRowBackground(listRowBlend)
                } header: {
                    sectionCaption("Development")
                }
                #endif
            }
            // Plain style avoids the default inset-grouped gray capsules on top of our gradient.
            .listStyle(.plain)
            .listSectionSpacing(20)
            .listRowSeparatorTint(timeTheme.textColor.opacity(0.18))
            .scrollContentBackground(.hidden)
            .background(settingsBackground)
            .navigationTitle(localized("settings.navigation.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(timeTheme.textColor)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .onboardingHighlight(onboarding.currentStep == .closeSettings)
                    .accessibilityIdentifier("Onboarding.SettingsClose")
                }
            }
        }
        .accessibilityIdentifier("tabSettings")
        .task {
            await model.load()
        }
        .overlay {
            if onboarding.currentStep == .closeSettings {
                OnboardingCoachMarkView(
                    title: "Close Settings",
                    message: "Tap the close button to finish setup.",
                    timeTheme: timeTheme,
                    variant: .belowTopChrome
                )
                .allowsHitTesting(false)
            }
        }
    }

    private func localized(_ key: String) -> String {
        LS(key, locale: locale)
    }

    private var mosqueSectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("settings.section.mosque.title"))
                .font(HomeDesign.Typography.app(size: 13, weight: .semibold))
                .foregroundColor(timeTheme.textColor.opacity(0.52))
                .textCase(.uppercase)
                .tracking(0.4)
                .multilineTextAlignment(.leading)
            Text(localized("settings.section.mosque.subtitle"))
                .font(HomeDesign.Typography.app(size: 14, weight: .regular))
                .foregroundColor(timeTheme.textColor.opacity(0.62))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .textCase(nil)
    }

    private func sectionCaption(_ title: String) -> some View {
        Text(title)
            .font(HomeDesign.Typography.app(size: 13, weight: .semibold))
            .foregroundColor(timeTheme.textColor.opacity(0.52))
            .textCase(.uppercase)
            .tracking(0.4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
    }

    private var mosquePickerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(localized("settings.mosque.picker"))
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            Picker("", selection: mosqueSelectionBinding) {
                ForEach(model.mosques) { m in
                    Text(m.name).tag(m.id)
                }
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }

    private var languagePickerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(localized("settings.language.picker"))
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            Picker("", selection: Bindable(settings).appLanguage) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(LS(lang.catalogOptionKey, locale: locale))
                        .tag(lang)
                }
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }

    private var adhanReminderPickerRow: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Adhan reminder")
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: adhanReminderMinutesBinding) {
                Text("None").tag(nil as Int?)
                Text("5 min").tag(5 as Int?)
                Text("10 min").tag(10 as Int?)
                Text("15 min").tag(15 as Int?)
                Text("30 min").tag(30 as Int?)
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
            .fixedSize()
        }
        .frame(minHeight: 44)
    }

    private var iqamahReminderPickerRow: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Iqamah reminder")
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: iqamahReminderMinutesBinding) {
                Text("None").tag(nil as Int?)
                Text("5 min").tag(5 as Int?)
                Text("10 min").tag(10 as Int?)
                Text("15 min").tag(15 as Int?)
                Text("30 min").tag(30 as Int?)
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
            .fixedSize()
        }
        .frame(minHeight: 44)
    }

    private var mosqueSelectionBinding: Binding<String> {
        Binding(
            get: {
                if let id = settings.selectedMosqueId, model.mosques.contains(where: { $0.id == id }) {
                    return id
                }
                return model.mosques.first?.id ?? ""
            },
            set: { id in
                guard let m = model.mosques.first(where: { $0.id == id }) else { return }
                Task { await model.selectMosque(m) }
            }
        )
    }

    private var settingsBackground: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                gradient: timeTheme.gradient,
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(timeTheme.iconColor.opacity(0.12))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: 150, y: -100)
        }
        .ignoresSafeArea()
    }

    private var masterNotificationsBinding: Binding<Bool> {
        Binding(
            get: { settings.notifications.masterEnabled },
            set: { newValue in
                var n = settings.notifications
                n.masterEnabled = newValue
                settings.notifications = n
                Task { await model.onNotificationsChanged() }
            }
        )
    }

    private func notificationChannelBinding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.notifications[keyPath: keyPath] },
            set: { newValue in
                var n = settings.notifications
                n[keyPath: keyPath] = newValue
                n.masterEnabled = n.adhanEnabled || 
                                  n.iqamahEnabled || 
                                  n.preAdhanReminderMinutes != nil ||
                                  n.preIqamahReminderMinutes != nil
                settings.notifications = n
                Task { await model.onNotificationsChanged() }
            }
        )
    }

    private var adhanReminderMinutesBinding: Binding<Int?> {
        Binding(
            get: { settings.notifications.preAdhanReminderMinutes },
            set: { newValue in
                var n = settings.notifications
                n.preAdhanReminderMinutes = newValue
                n.masterEnabled = n.adhanEnabled || 
                                  n.iqamahEnabled || 
                                  n.preAdhanReminderMinutes != nil ||
                                  n.preIqamahReminderMinutes != nil
                settings.notifications = n
                Task { await model.onNotificationsChanged() }
            }
        )
    }

    private var iqamahReminderMinutesBinding: Binding<Int?> {
        Binding(
            get: { settings.notifications.preIqamahReminderMinutes },
            set: { newValue in
                var n = settings.notifications
                n.preIqamahReminderMinutes = newValue
                n.masterEnabled = n.adhanEnabled || 
                                  n.iqamahEnabled || 
                                  n.preAdhanReminderMinutes != nil ||
                                  n.preIqamahReminderMinutes != nil
                settings.notifications = n
                Task { await model.onNotificationsChanged() }
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.notifications[keyPath: keyPath] },
            set: { newValue in
                var n = settings.notifications
                n[keyPath: keyPath] = newValue
                settings.notifications = n
                Task { await model.onNotificationsChanged() }
            }
        )
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let timeTheme: HomeDesign.TimeTheme

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
        }
        .tint(timeTheme.textColor)
        .frame(minHeight: 44)
    }
}

private struct NotificationToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let timeTheme: HomeDesign.TimeTheme

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(HomeDesign.Typography.app(size: 17, weight: .regular))
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
        }
        .tint(timeTheme.textColor)
        .frame(minHeight: 44)
    }
}

#Preview {
    let settings = SettingsStore()
    let repo = ConvexPrayerRepository(service: ConvexService())
    let scheduler = PrayerNotificationScheduler(repository: repo)
    let model = SettingsViewModel(repository: repo, settings: settings, notificationScheduler: scheduler)
    let homeVM = HomeViewModel(repository: repo, settings: settings, notificationScheduler: scheduler)
    let onboarding = OnboardingFlowController(
        settings: settings,
        homeViewModel: homeVM,
        settingsViewModel: model,
        notificationScheduler: scheduler
    )
    return SettingsView(model: model, timeTheme: .dhuhr)
        .environment(settings)
        .environment(onboarding)
}
