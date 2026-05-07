import Observation
import SwiftUI

@Observable
@MainActor
final class AppEnvironment {
    let settings: SettingsStore
    let convexService: ConvexService
    let repository: ConvexPrayerRepository
    let notificationScheduler: PrayerNotificationScheduler
    let homeViewModel: HomeViewModel
    let settingsViewModel: SettingsViewModel

    init() {
        let s = SettingsStore()
        let conv = ConvexService()
        let repo = ConvexPrayerRepository(service: conv)
        let sched = PrayerNotificationScheduler(repository: repo)
        settings = s
        convexService = conv
        repository = repo
        notificationScheduler = sched
        homeViewModel = HomeViewModel(repository: repo, settings: s, notificationScheduler: sched)
        settingsViewModel = SettingsViewModel(repository: repo, settings: s, notificationScheduler: sched)
    }
}
