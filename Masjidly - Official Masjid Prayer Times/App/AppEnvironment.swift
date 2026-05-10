import Observation
import SwiftUI

@Observable
@MainActor
final class AppEnvironment {
    let settings: SettingsStore
    let convexService: ConvexService
    let repository: ConvexPrayerRepository
    let notificationScheduler: PrayerNotificationScheduler
    let widgetSnapshotService: WidgetPrayerSnapshotService
    let homeViewModel: HomeViewModel
    let settingsViewModel: SettingsViewModel
    let onboardingFlowController: OnboardingFlowController

    init() {
        let s = SettingsStore()
        let conv = ConvexService()
        let repo = ConvexPrayerRepository(service: conv)
        let sched = PrayerNotificationScheduler(repository: repo)
        let widgets = WidgetPrayerSnapshotService(repository: repo, settings: s)
        settings = s
        convexService = conv
        repository = repo
        notificationScheduler = sched
        widgetSnapshotService = widgets
        homeViewModel = HomeViewModel(repository: repo, settings: s, notificationScheduler: sched, widgetSnapshotWriter: widgets)
        settingsViewModel = SettingsViewModel(repository: repo, settings: s, notificationScheduler: sched)
        onboardingFlowController = OnboardingFlowController(
            settings: s,
            homeViewModel: homeViewModel,
            settingsViewModel: settingsViewModel,
            notificationScheduler: sched
        )
    }
}
