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
    let prayerTimesCache: PrayerTimesDiskCache
    let homeViewModel: HomeViewModel
    let settingsViewModel: SettingsViewModel
    let onboardingFlowController: OnboardingFlowController
    let appReviewPromptCoordinator: AppReviewPromptCoordinator
    /// Attached at launch so Prayer Focus follows the active mosque and reconciles on every activation.
    let prayerFocus = PrayerFocusController.shared

    init() {
        let s = SettingsStore()
        let conv = ConvexService()
        let repo = ConvexPrayerRepository(service: conv)
        let cache = PrayerTimesDiskCache()
        let sched = PrayerNotificationScheduler(repository: repo, diskCache: cache)
        let widgets = WidgetPrayerSnapshotService(repository: repo, settings: s, diskCache: cache)
        settings = s
        convexService = conv
        repository = repo
        notificationScheduler = sched
        widgetSnapshotService = widgets
        prayerTimesCache = cache
        homeViewModel = HomeViewModel(repository: repo, settings: s, notificationScheduler: sched, widgetSnapshotWriter: widgets, diskCache: cache)
        settingsViewModel = SettingsViewModel(repository: repo, settings: s, notificationScheduler: sched, diskCache: cache)
        onboardingFlowController = OnboardingFlowController(
            settings: s,
            homeViewModel: homeViewModel,
            settingsViewModel: settingsViewModel,
            notificationScheduler: sched
        )
        appReviewPromptCoordinator = AppReviewPromptCoordinator(settings: s)
        let home = homeViewModel
        prayerFocus.attach(settings: s) { await home.refreshWidgetSnapshotForCurrentMosque() }
    }
}
