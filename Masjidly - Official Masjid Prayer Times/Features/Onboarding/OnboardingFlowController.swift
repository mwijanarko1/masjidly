import Foundation
import Observation

@Observable
@MainActor
final class OnboardingFlowController {
    private let settings: SettingsStore
    private let homeViewModel: HomeViewModel
    private let settingsViewModel: SettingsViewModel
    private let notificationScheduler: any PrayerNotificationScheduling

    var currentStep: OnboardingStep?
    var selectedLanguage: AppLanguage
    var selectedMosqueId = ""
    var notificationDraft = OnboardingNotificationDraft.defaultEnabled
    var isSelectingMosque = false
    var isCompletingNotifications = false

    var isActive: Bool {
        currentStep != nil
    }

    init(
        settings: SettingsStore,
        homeViewModel: HomeViewModel,
        settingsViewModel: SettingsViewModel,
        notificationScheduler: any PrayerNotificationScheduling
    ) {
        self.settings = settings
        self.homeViewModel = homeViewModel
        self.settingsViewModel = settingsViewModel
        self.notificationScheduler = notificationScheduler
        selectedLanguage = settings.appLanguage
        // Do not seed from settings: load may have resolved the default MWHS slug.
        selectedMosqueId = ""
        notificationDraft = .defaultEnabled
    }

    func startIfNeeded() {
        guard !settings.hasCompletedOnboarding else {
            currentStep = nil
            return
        }
        guard !homeViewModel.mosques.isEmpty || !settingsViewModel.mosques.isEmpty else {
            currentStep = nil
            return
        }
        // Fresh onboarding always starts without a mosque so location can prefill closest.
        selectedMosqueId = ""
        notificationDraft = .defaultEnabled
        currentStep = .chooseLanguage
    }

    func selectLanguage(_ language: AppLanguage) {
        guard currentStep == .chooseLanguage else { return }
        selectedLanguage = language
        settings.appLanguage = language
        currentStep = .requestLocation
    }

    func continueAfterLocationStep() {
        guard currentStep == .requestLocation else { return }
        currentStep = .chooseMosque
    }

    /// Prefills the closest mosque once when the user has not chosen one yet.
    /// Allowed on the location step (before advancing) and the mosque step.
    func applyClosestMosqueIfNeeded(from mosques: [Mosque], latitude: Double, longitude: Double) {
        guard selectedMosqueId.isEmpty else { return }
        guard currentStep == .requestLocation || currentStep == .chooseMosque else { return }
        guard let closest = ClosestMosquePromptDecision.closestMosque(
            in: mosques,
            userLatitude: latitude,
            userLongitude: longitude
        ) else { return }
        selectedMosqueId = closest.id
    }

    func selectMosque(_ mosque: Mosque) async {
        guard currentStep == .chooseMosque, !isSelectingMosque else { return }
        isSelectingMosque = true
        defer { isSelectingMosque = false }

        selectedMosqueId = mosque.id
        settings.selectedMosqueId = mosque.id
        settings.selectedMosqueSlug = mosque.slug
        settings.selectedCityGroupingKey = mosque.cityGroupingKey
        settings.selectedCountryGroupingKey = MosqueDefaults.countryGroupingKey(for: mosque)
        homeViewModel.selectedMosque = mosque
        if settingsViewModel.mosques.isEmpty {
            settingsViewModel.mosques = homeViewModel.mosques
        }
        do {
            try await homeViewModel.refreshPrayerPayload(for: mosque)
            await homeViewModel.refreshWidgetSnapshotForCurrentMosque()
        } catch {
            homeViewModel.lastError = error.localizedDescription
        }

        currentStep = .notifications
    }

    func completeNotificationSetup() async {
        guard currentStep == .notifications, !isCompletingNotifications else { return }
        isCompletingNotifications = true
        defer { isCompletingNotifications = false }

        let draft = notificationDraft
        var next = settings.notifications
        next.adhanEnabled = draft.adhanEnabled
        next.iqamahEnabled = draft.iqamahEnabled
        next.preAdhanReminderMinutes = draft.preAdhanReminderMinutes
        next.preIqamahReminderMinutes = draft.preIqamahReminderMinutes
        next.fajr = draft.fajr
        next.dhuhrJummah = draft.dhuhrJummah
        next.asr = draft.asr
        next.maghrib = draft.maghrib
        next.isha = draft.isha
        next.adhanFajr = draft.adhanFajr
        next.adhanDhuhrJummah = draft.adhanDhuhrJummah
        next.adhanAsr = draft.adhanAsr
        next.adhanMaghrib = draft.adhanMaghrib
        next.adhanIsha = draft.adhanIsha
        next.iqamahFajr = draft.iqamahFajr
        next.iqamahDhuhrJummah = draft.iqamahDhuhrJummah
        next.iqamahAsr = draft.iqamahAsr
        next.iqamahMaghrib = draft.iqamahMaghrib
        next.iqamahIsha = draft.iqamahIsha
        next.masterEnabled =
            draft.adhanEnabled
            || draft.iqamahEnabled
            || draft.preAdhanReminderMinutes != nil
            || draft.preIqamahReminderMinutes != nil
            || draft.adhanFajr || draft.adhanDhuhrJummah || draft.adhanAsr || draft.adhanMaghrib || draft.adhanIsha
            || draft.iqamahFajr || draft.iqamahDhuhrJummah || draft.iqamahAsr || draft.iqamahMaghrib || draft.iqamahIsha
        settings.notifications = next

        if next.masterEnabled {
            _ = try? await notificationScheduler.requestAuthorizationIfNeeded()
            if let mosque = homeViewModel.selectedMosque {
                try? await notificationScheduler.rescheduleUpcomingPrayerNotifications(
                    mosque: mosque,
                    days: 7,
                    settings: next,
                    locale: settings.resolvedLocale,
                    asrIqamahPreference: settings.asrIqamahPreference
                )
            }
        } else {
            await notificationScheduler.cancelAllPrayerNotifications()
        }

        settings.lastSeenBuildVersion = WhatsNew.fullVersionString
        settings.hasCompletedOnboarding = true
        currentStep = nil
    }
}

#if DEBUG
extension OnboardingFlowController {
    /// Resets onboarding so language + location + mosque + notifications can be exercised again.
    func restartTutorialFromDeveloperTools() {
        settings.hasCompletedOnboarding = false
        selectedMosqueId = ""
        notificationDraft = .defaultEnabled
        selectedLanguage = settings.appLanguage
        currentStep = .chooseLanguage
    }
}
#endif
