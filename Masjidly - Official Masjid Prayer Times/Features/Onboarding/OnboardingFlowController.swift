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
    var notificationDraft = OnboardingNotificationDraft()
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
        selectedMosqueId = settings.selectedMosqueId ?? ""
        notificationDraft = OnboardingNotificationDraft(
            adhanEnabled: settings.notifications.adhanEnabled,
            iqamahEnabled: settings.notifications.iqamahEnabled,
            preAdhanReminderMinutes: settings.notifications.preAdhanReminderMinutes,
            preIqamahReminderMinutes: settings.notifications.preIqamahReminderMinutes,
            fajr: settings.notifications.fajr,
            dhuhrJummah: settings.notifications.dhuhrJummah,
            asr: settings.notifications.asr,
            maghrib: settings.notifications.maghrib,
            isha: settings.notifications.isha,
            adhanFajr: settings.notifications.adhanFajr,
            adhanDhuhrJummah: settings.notifications.adhanDhuhrJummah,
            adhanAsr: settings.notifications.adhanAsr,
            adhanMaghrib: settings.notifications.adhanMaghrib,
            adhanIsha: settings.notifications.adhanIsha,
            iqamahFajr: settings.notifications.iqamahFajr,
            iqamahDhuhrJummah: settings.notifications.iqamahDhuhrJummah,
            iqamahAsr: settings.notifications.iqamahAsr,
            iqamahMaghrib: settings.notifications.iqamahMaghrib,
            iqamahIsha: settings.notifications.iqamahIsha
        )
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
        if selectedMosqueId.isEmpty {
            selectedMosqueId = settings.selectedMosqueId ?? homeViewModel.mosques.first?.id ?? settingsViewModel.mosques.first?.id ?? ""
        }
        currentStep = .chooseLanguage
    }

    func selectLanguage(_ language: AppLanguage) {
        guard currentStep == .chooseLanguage else { return }
        selectedLanguage = language
        settings.appLanguage = language
        currentStep = .chooseMosque
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
        currentStep = .prayerShortcut(index: 0)
    }

    func handlePrayerShortcutTap(index: Int) {
        guard case .prayerShortcut(let expectedIndex) = currentStep,
              expectedIndex == 0,
              (0...5).contains(index) else { return }
        currentStep = .qiblaCountdown
    }

    func skipToTutorialEnd() {
        currentStep = .notifications
    }

    func completeQiblaCountdownStep() {
        guard currentStep == .qiblaCountdown else { return }
        currentStep = .qibla
    }

    func completeQiblaOnboardingAllowingLocationRequest() {
        guard currentStep == .qibla else { return }
        currentStep = .openTimetable
    }

    func completeQiblaOnboardingDeferringLocation() {
        guard currentStep == .qibla else { return }
        settings.hideQiblaCompass = true
        currentStep = .openTimetable
    }

    func handleTimetableOpened() {
        guard currentStep == .openTimetable else { return }
        currentStep = .exploreTimetable
    }

    func acknowledgeTimetableExplore() {
        guard currentStep == .exploreTimetable else { return }
        currentStep = .closeTimetable
    }

    func handleTimetableClosed() {
        guard currentStep == .closeTimetable else { return }
        currentStep = .openSettings
    }

    func handleSettingsOpened() {
        guard currentStep == .openSettings else { return }
        currentStep = .exploreSettings
    }

    func acknowledgeSettingsExplore() {
        guard currentStep == .exploreSettings else { return }
        currentStep = .closeSettings
    }

    func handleSettingsClosed() {
        guard currentStep == .closeSettings else { return }
        currentStep = .notifications
    }

    func completeNotificationSetup() async {
        guard currentStep == .notifications, !isCompletingNotifications else { return }
        isCompletingNotifications = true
        defer { isCompletingNotifications = false }

        var next = settings.notifications
        next.adhanEnabled = notificationDraft.adhanEnabled
        next.iqamahEnabled = notificationDraft.iqamahEnabled
        next.preAdhanReminderMinutes = notificationDraft.preAdhanReminderMinutes
        next.preIqamahReminderMinutes = notificationDraft.preIqamahReminderMinutes
        next.fajr = notificationDraft.fajr
        next.dhuhrJummah = notificationDraft.dhuhrJummah
        next.asr = notificationDraft.asr
        next.maghrib = notificationDraft.maghrib
        next.isha = notificationDraft.isha
        next.masterEnabled = notificationDraft.adhanEnabled || 
                            notificationDraft.iqamahEnabled || 
                            notificationDraft.preAdhanReminderMinutes != nil ||
                            notificationDraft.preIqamahReminderMinutes != nil
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
    /// Resets onboarding state so the full tutorial overlay can be exercised again from the home screen.
    func restartTutorialFromDeveloperTools() {
        settings.hasCompletedOnboarding = false
        settings.hideQiblaCompass = false
        if selectedMosqueId.isEmpty {
            selectedMosqueId = settings.selectedMosqueId ?? homeViewModel.mosques.first?.id ?? settingsViewModel.mosques.first?.id ?? ""
        }
        notificationDraft = OnboardingNotificationDraft(
            adhanEnabled: settings.notifications.adhanEnabled,
            iqamahEnabled: settings.notifications.iqamahEnabled,
            preAdhanReminderMinutes: settings.notifications.preAdhanReminderMinutes,
            preIqamahReminderMinutes: settings.notifications.preIqamahReminderMinutes,
            fajr: settings.notifications.fajr,
            dhuhrJummah: settings.notifications.dhuhrJummah,
            asr: settings.notifications.asr,
            maghrib: settings.notifications.maghrib,
            isha: settings.notifications.isha,
            adhanFajr: settings.notifications.adhanFajr,
            adhanDhuhrJummah: settings.notifications.adhanDhuhrJummah,
            adhanAsr: settings.notifications.adhanAsr,
            adhanMaghrib: settings.notifications.adhanMaghrib,
            adhanIsha: settings.notifications.adhanIsha,
            iqamahFajr: settings.notifications.iqamahFajr,
            iqamahDhuhrJummah: settings.notifications.iqamahDhuhrJummah,
            iqamahAsr: settings.notifications.iqamahAsr,
            iqamahMaghrib: settings.notifications.iqamahMaghrib,
            iqamahIsha: settings.notifications.iqamahIsha
        )
        selectedLanguage = settings.appLanguage
        currentStep = .chooseLanguage
    }
}
#endif
