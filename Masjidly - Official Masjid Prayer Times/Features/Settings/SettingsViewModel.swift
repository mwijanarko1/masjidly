import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let repository: any PrayerRepository
    private let settings: SettingsStore
    private let notificationScheduler: any PrayerNotificationScheduling

    var mosques: [Mosque] = []
    var loadError: String?

    init(
        repository: any PrayerRepository,
        settings: SettingsStore,
        notificationScheduler: any PrayerNotificationScheduling
    ) {
        self.repository = repository
        self.settings = settings
        self.notificationScheduler = notificationScheduler
    }

    func load() async {
        loadError = nil
        do {
            let all = try await repository.listMosques()
            mosques = MosqueDefaults.visibleMosques(all)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func selectMosque(_ mosque: Mosque) async {
        settings.selectedMosqueId = mosque.id
        settings.selectedMosqueSlug = mosque.slug
        await applyNotificationPolicy()
    }

    func onNotificationsChanged() async {
        await applyNotificationPolicy()
    }

    private func applyNotificationPolicy() async {
        let n = settings.notifications
        if n.masterEnabled, let slug = settings.selectedMosqueSlug,
           let mosque = mosques.first(where: { $0.slug == slug }) ?? mosques.first(where: { $0.id == settings.selectedMosqueId }) {
            try? await notificationScheduler.rescheduleUpcomingPrayerNotifications(mosque: mosque, days: 7, settings: n)
        } else {
            await notificationScheduler.cancelAllPrayerNotifications()
        }
    }
}
