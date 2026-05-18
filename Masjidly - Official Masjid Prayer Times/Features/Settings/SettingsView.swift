import Observation
import SwiftUI
import CoreLocation
import UIKit

private func LS(_ key: String, locale: Locale) -> String {
    LocaleBundle.string(forKey: key, locale: locale)
}

struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    let timeTheme: HomeDesign.TimeTheme
    var onDismiss: (() -> Void)? = nil
    @Environment(SettingsStore.self) private var settings
    @Environment(OnboardingFlowController.self) private var onboarding
    @Environment(AppReviewPromptCoordinator.self) private var reviewPrompt
    @Environment(\.dismiss) private var dismiss
    /// Derive locale directly from the observable SettingsStore so that changing
    /// the in-app language inside this sheet instantly re-localizes every string.
    private var locale: Locale { settings.resolvedLocale }
    @State private var locationAuthStatus: CLAuthorizationStatus = {
        let manager = CLLocationManager()
        return manager.authorizationStatus
    }()

    private var shouldShowLocationRecovery: Bool {
        settings.hideQiblaCompass || locationAuthStatus == .denied || locationAuthStatus == .restricted
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                settingsTitleHeaderRow

                settingsSectionBlock(titleKey: "settings.section.mosque.title") {
                    VStack(spacing: 0) {
                        cityPickerRow
                            .padding(.vertical, 12)
                        settingsRowDivider
                        mosquePickerRow
                            .padding(.vertical, 12)
                    }
                }

                settingsSectionBlock(titleKey: "settings.section.display.title") {
                    SettingsToggleRow(
                        title: localized("settings.time.24h.title"),
                        isOn: Bindable(settings).uses24HourTime,
                        timeTheme: timeTheme
                    )
                    .padding(.vertical, 12)
                }

                settingsSectionBlock(titleKey: "settings.section.language.title") {
                    languagePickerRow
                        .padding(.vertical, 12)
                }

                settingsSectionBlock(titleKey: "settings.section.qibla.title") {
                    SettingsToggleRow(
                        title: localized("settings.qibla.enabled.title"),
                        isOn: qiblaEnabledBinding,
                        timeTheme: timeTheme
                    )
                    .padding(.vertical, 12)
                }

                if shouldShowLocationRecovery {
                    settingsSectionBlock(titleKey: "settings.section.location.title") {
                        locationRecoveryRow
                            .padding(.vertical, 12)
                    }
                }

                settingsSectionBlock(titleKey: "settings.notifications.title") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            title: localized("settings.notifications.master.title"),
                            isOn: masterNotificationsBinding,
                            timeTheme: timeTheme
                        )
                        .padding(.vertical, 12)

                        if settings.notifications.masterEnabled {
                            settingsRowDivider
                            NotificationToggleRow(title: localized("notification.channel.adhan"), isOn: notificationChannelBinding(\.adhanEnabled), timeTheme: timeTheme)
                                .padding(.vertical, 12)
                            settingsRowDivider
                            NotificationToggleRow(title: localized("notification.channel.iqamah"), isOn: notificationChannelBinding(\.iqamahEnabled), timeTheme: timeTheme)
                                .padding(.vertical, 12)
                            settingsRowDivider
                            adhanReminderPickerRow
                                .padding(.vertical, 12)
                            settingsRowDivider
                            iqamahReminderPickerRow
                                .padding(.vertical, 12)
                        }
                    }
                }

                settingsSectionBlock(titleKey: "settings.section.contact.title") {
                    VStack(spacing: 10) {
                        contactActionButton(
                            title: localized("settings.contact.feedback.title")
                        ) {
                            openSupportEmail(.feedback)
                        }
                        contactActionButton(
                            title: localized("settings.contact.prayer_times.title")
                        ) {
                            openSupportEmail(.prayerTimes)
                        }
                    }
                }

                #if DEBUG
                settingsSectionBlock(titleKey: "settings.section.development.title") {
                    VStack(spacing: 10) {
                        Button {
                            onboarding.restartTutorialFromDeveloperTools()
                            onDismiss?()
                            dismiss()
                        } label: {
                            developmentChrome {
                                Text(localized("settings.development.test_tutorial"))
                                    .appFont(size: 17, weight: .medium)
                                    .foregroundColor(timeTheme.textColor)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(TestNotificationType.allCases, id: \.rawValue) { testType in
                            Button {
                                Task { await model.fireTestNotification(testType) }
                            } label: {
                                developmentChrome {
                                    HStack(alignment: .center, spacing: 12) {
                                        Text(testNotificationTitle(testType))
                                            .appFont(size: 17, weight: .medium)
                                            .foregroundColor(timeTheme.textColor)
                                        Spacer(minLength: 8)
                                        Text(testDescription(testType))
                                            .appFont(size: 13, weight: .regular)
                                            .foregroundColor(timeTheme.textColor.opacity(0.55))
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            reviewPrompt.resetAndPresentEnjoymentPromptForTesting()
                            onDismiss?()
                            dismiss()
                        } label: {
                            developmentChrome {
                                Text(localized("settings.development.test_review_prompt"))
                                    .appFont(size: 17, weight: .medium)
                                    .foregroundColor(timeTheme.textColor)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                #endif
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
        .preferredColorScheme(timeTheme.usesLightForeground ? .dark : .light)
        .accessibilityIdentifier("tabSettings")
        .task {
            await model.load()
        }
        .onAppear {
            locationAuthStatus = CLLocationManager().authorizationStatus
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            locationAuthStatus = CLLocationManager().authorizationStatus
        }
        .overlay {
            Group {
                if onboarding.currentStep == .exploreSettings {
                    OnboardingCoachMarkView(
                        title: localized("onboarding.explore_settings.title"),
                        message: localized("onboarding.explore_settings.message"),
                        timeTheme: timeTheme,
                        variant: .floatingBottom,
                        primaryButtonTitle: localized("onboarding.continue"),
                        onPrimaryButton: { onboarding.acknowledgeSettingsExplore() },
                        primaryButtonAccessibilityIdentifier: "Onboarding.SettingsExploreContinue"
                    )
                } else if onboarding.currentStep == .closeSettings {
                    OnboardingCoachMarkView(
                        title: localized("onboarding.close_settings.title"),
                        message: localized("onboarding.close_settings.message"),
                        timeTheme: timeTheme,
                        variant: .belowTopChrome
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        LS(key, locale: locale)
    }

    private var settingsTitleHeaderRow: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(localized("settings.navigation.title"))
                .appFont(size: 34, weight: .bold)
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Button {
                onDismiss?()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .appFont(size: 16, weight: .bold)
                    .foregroundColor(timeTheme.textColor)
                    .padding(8)
                    .background(Circle().fill(timeTheme.textColor.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .onboardingHighlight(onboarding.currentStep == .closeSettings, timeTheme: timeTheme)
            .accessibilityIdentifier("Onboarding.SettingsClose")
        }
        .padding(.bottom, 4)
    }

    private func settingsSectionBlock(titleKey: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionCaption(localized(titleKey))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsRowDivider: some View {
        Rectangle()
            .fill(timeTheme.textColor.opacity(0.18))
            .frame(height: 0.5)
    }

    private func sectionCaption(_ title: String) -> some View {
        Text(title)
            .appFont(size: 13, weight: .semibold)
            .foregroundColor(timeTheme.textColor.opacity(0.52))
            .textCase(.uppercase)
            .tracking(0.4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private var locationRecoveryRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("settings.location.recovery.message"))
                .appFont(size: 15, weight: .regular)
                .foregroundColor(timeTheme.textColor.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if locationAuthStatus == .notDetermined {
                    let manager = CLLocationManager()
                    manager.requestWhenInUseAuthorization()
                    locationAuthStatus = .notDetermined
                } else {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            } label: {
                Text(locationButtonLabel)
                    .appFont(size: 16, weight: .semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(timeTheme.textColor.opacity(0.25))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Settings.LocationRecoveryAction")
        }
    }

    private var locationButtonLabel: String {
        switch locationAuthStatus {
        case .notDetermined:
            localized("settings.location.allow")
        default:
            localized("settings.location.open_settings")
        }
    }

    private var qiblaEnabledBinding: Binding<Bool> {
        Binding(
            get: { !settings.hideQiblaCompass },
            set: { isEnabled in
                settings.hideQiblaCompass = !isEnabled
                if isEnabled, locationAuthStatus == .notDetermined {
                    CLLocationManager().requestWhenInUseAuthorization()
                    locationAuthStatus = CLLocationManager().authorizationStatus
                }
            }
        )
    }

    @ViewBuilder
    private func insetListRowChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(timeTheme.textColor.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(timeTheme.textColor.opacity(0.22), lineWidth: 1)
            )
    }

    private func contactActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            insetListRowChrome {
                Text(title)
                    .appFont(size: 17, weight: .medium)
                    .foregroundColor(timeTheme.textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func openSupportEmail(_ category: MasjidlySupportMail.Category) {
        let mosqueName: String? = {
            guard let id = settings.selectedMosqueId else { return nil }
            return model.mosques.first { $0.id == id }?.name
        }()
        let ctx = MasjidlySupportMail.currentContext(mosqueName: mosqueName)
        guard let url = MasjidlySupportMail.mailtoURL(category: category, locale: locale, context: ctx) else { return }
        UIApplication.shared.open(url)
    }

    #if DEBUG
    @ViewBuilder
    private func developmentChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        insetListRowChrome(content: content)
    }

    private func testNotificationTitle(_ type: TestNotificationType) -> String {
        let format = localized("settings.development.test_notification_format")
        let name: String
        switch type {
        case .adhan: name = localized("notification.channel.adhan")
        case .iqamah: name = localized("notification.channel.iqamah")
        case .reminder: name = localized("settings.development.notification_type.reminder")
        case .all: name = localized("settings.development.notification_type.all")
        }
        return String(format: format, locale: locale, arguments: [name])
    }

    private func testDescription(_ type: TestNotificationType) -> String {
        switch type {
        case .adhan, .iqamah, .reminder: return localized("settings.development.instant")
        case .all: return localized("settings.development.three_instant")
        }
    }
    #endif

    private var cityOptions: [(key: String, label: String)] {
        MosqueDefaults.cityOptions(from: model.mosques)
    }

    private var effectiveCityGroupingKey: String {
        if let k = settings.selectedCityGroupingKey,
           !MosqueDefaults.mosques(inCityGroupingKey: k, mosques: model.mosques).isEmpty {
            return k
        }
        if let id = settings.selectedMosqueId,
           let m = model.mosques.first(where: { $0.id == id }) {
            return m.cityGroupingKey
        }
        return cityOptions.first?.key ?? ""
    }

    private var mosquesInSelectedCity: [Mosque] {
        let key = effectiveCityGroupingKey
        guard !key.isEmpty else { return model.mosques }
        return MosqueDefaults.mosques(inCityGroupingKey: key, mosques: model.mosques)
    }

    private var cityPickerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(localized("settings.city.picker"))
                .appFont(size: 17, weight: .regular)
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            Picker("", selection: citySelectionBinding) {
                ForEach(cityOptions, id: \.key) { opt in
                    Text(opt.label)
                        .appFont(size: 17)
                        .tag(opt.key)
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
            Text(localized("settings.language.app"))
                .appFont(size: 17, weight: .regular)
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            Picker("", selection: Bindable(settings).appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(localized(language.displayNameKey))
                        .appFont(size: 17)
                        .tag(language)
                }
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }

    private var mosquePickerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(localized("settings.mosque.picker"))
                .appFont(size: 17, weight: .regular)
                .foregroundColor(timeTheme.textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            Picker("", selection: mosqueSelectionBinding) {
                ForEach(mosquesInSelectedCity) { m in
                    Text(m.name)
                        .appFont(size: 17)
                        .tag(m.id)
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
            Text(localized("settings.reminder.before_adhan"))
                .appFont(size: 17, weight: .regular)
                .foregroundColor(timeTheme.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: adhanReminderMinutesBinding) {
                reminderOptionText(nil).tag(nil as Int?)
                reminderOptionText(5).tag(5 as Int?)
                reminderOptionText(10).tag(10 as Int?)
                reminderOptionText(15).tag(15 as Int?)
                reminderOptionText(30).tag(30 as Int?)
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
            .fixedSize()
        }
        .frame(minHeight: 44)
    }

    private var iqamahReminderPickerRow: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(localized("settings.reminder.before_iqamah"))
                .appFont(size: 17, weight: .regular)
                .foregroundColor(timeTheme.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: iqamahReminderMinutesBinding) {
                reminderOptionText(nil).tag(nil as Int?)
                reminderOptionText(5).tag(5 as Int?)
                reminderOptionText(10).tag(10 as Int?)
                reminderOptionText(15).tag(15 as Int?)
                reminderOptionText(30).tag(30 as Int?)
            }
            .pickerStyle(.menu)
            .tint(timeTheme.textColor)
            .fixedSize()
        }
        .frame(minHeight: 44)
    }

    private var citySelectionBinding: Binding<String> {
        Binding(
            get: { effectiveCityGroupingKey },
            set: { newKey in
                settings.selectedCityGroupingKey = newKey
                let inCity = MosqueDefaults.mosques(inCityGroupingKey: newKey, mosques: model.mosques)
                guard let first = inCity.first else { return }
                if inCity.contains(where: { $0.id == settings.selectedMosqueId }) { return }
                Task { await model.selectMosque(first) }
            }
        )
    }

    private var mosqueSelectionBinding: Binding<String> {
        Binding(
            get: {
                if let id = settings.selectedMosqueId,
                   mosquesInSelectedCity.contains(where: { $0.id == id }) {
                    return id
                }
                return mosquesInSelectedCity.first?.id ?? ""
            },
            set: { id in
                guard let m = mosquesInSelectedCity.first(where: { $0.id == id }) else { return }
                Task { await model.selectMosque(m) }
            }
        )
    }

    private func reminderOptionText(_ minutes: Int?) -> some View {
        let label: String
        if let minutes {
            let format = localized("settings.reminder.minutes_format")
            label = String(format: format, locale: locale, arguments: [minutes])
        } else {
            label = localized("settings.reminder.none")
        }
        return Text(label).appFont(size: 17)
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

}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let timeTheme: HomeDesign.TimeTheme

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .appFont(size: 17, weight: .regular)
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
                .appFont(size: 17, weight: .regular)
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
    let cache = PrayerTimesDiskCache()
    let model = SettingsViewModel(repository: repo, settings: settings, notificationScheduler: scheduler, diskCache: cache)
    let homeVM = HomeViewModel(repository: repo, settings: settings, notificationScheduler: scheduler, diskCache: cache)
    let onboarding = OnboardingFlowController(
        settings: settings,
        homeViewModel: homeVM,
        settingsViewModel: model,
        notificationScheduler: scheduler
    )
    let review = AppReviewPromptCoordinator(settings: settings)
    return SettingsView(model: model, timeTheme: .dhuhr)
        .environment(settings)
        .environment(onboarding)
        .environment(review)
}
