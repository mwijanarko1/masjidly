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
    var selectedMosqueId = ""
    var notificationDraft = OnboardingNotificationDraft()
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
        selectedMosqueId = settings.selectedMosqueId ?? ""
        notificationDraft = OnboardingNotificationDraft(
            adhanEnabled: settings.notifications.adhanEnabled,
            iqamahEnabled: settings.notifications.iqamahEnabled,
            preAdhanReminderMinutes: settings.notifications.preAdhanReminderMinutes,
            preIqamahReminderMinutes: settings.notifications.preIqamahReminderMinutes
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
        currentStep = .chooseMosque
    }

    func selectMosque(_ mosque: Mosque) async {
        selectedMosqueId = mosque.id
        settings.selectedMosqueId = mosque.id
        settings.selectedMosqueSlug = mosque.slug
        settings.selectedCityGroupingKey = mosque.cityGroupingKey
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
                    locale: settings.resolvedLocale
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
            preIqamahReminderMinutes: settings.notifications.preIqamahReminderMinutes
        )
        currentStep = .chooseMosque
    }
}
#endif
