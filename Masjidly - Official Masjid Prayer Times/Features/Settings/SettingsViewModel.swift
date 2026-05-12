import Foundation
import Observation
import UserNotifications

enum TestNotificationType: String, CaseIterable {
    case adhan = "Adhan"
    case iqamah = "Iqamah"
    case reminder = "Reminder"
    case all = "All Three"
}

@Observable
@MainActor
final class SettingsViewModel {
    private let repository: any PrayerRepository
    private let settings: SettingsStore
    private let notificationScheduler: any PrayerNotificationScheduling
    private let diskCache: PrayerTimesDiskCache

    var mosques: [Mosque] = []
    var loadError: String?

    init(
        repository: any PrayerRepository,
        settings: SettingsStore,
        notificationScheduler: any PrayerNotificationScheduling,
        diskCache: PrayerTimesDiskCache
    ) {
        self.repository = repository
        self.settings = settings
        self.notificationScheduler = notificationScheduler
        self.diskCache = diskCache
    }

    func load() async {
        loadError = nil

        // Hydrate from cache first for instant display.
        if let cached = diskCache.loadMosques() {
            mosques = MosqueDefaults.visibleMosques(cached)
        }

        // Then fetch from Convex and save to cache.
        do {
            let all = try await repository.listMosques()
            mosques = MosqueDefaults.visibleMosques(all)
            try? diskCache.saveMosques(all)
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

    func fireTestNotification(_ type: TestNotificationType) async {
        do {
            _ = try await notificationScheduler.requestAuthorizationIfNeeded()
        } catch {
            return
        }
        let auth = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard auth == .authorized || auth == .provisional else { return }

        let slug = settings.selectedMosqueSlug ?? ""

        switch type {
        case .adhan:
            let copy = PrayerNotificationContent.adhanCopy(prayerKey: "maghrib", isFriday: false)
            await enqueueTestNotification(
                title: copy.title,
                body: copy.body,
                categoryIdentifier: PrayerNotificationContent.CategoryID.adhan,
                sound: PrayerNotificationContent.sound(for: settings.notifications, channel: .adhan),
                userInfo: PrayerNotificationContent.debugUserInfo(kind: .adhan, prayerKey: "maghrib", mosqueSlug: slug)
            )
        case .iqamah:
            let copy = PrayerNotificationContent.iqamahCopy(prayerKey: "maghrib", isFriday: false)
            await enqueueTestNotification(
                title: copy.title,
                body: copy.body,
                categoryIdentifier: PrayerNotificationContent.CategoryID.iqamah,
                sound: PrayerNotificationContent.sound(for: settings.notifications, channel: .iqamah),
                userInfo: PrayerNotificationContent.debugUserInfo(kind: .iqamah, prayerKey: "maghrib", mosqueSlug: slug)
            )
        case .reminder:
            let copy = PrayerNotificationContent.beforeAdhanReminderCopy(prayerKey: "maghrib", isFriday: false, minutes: 10)
            await enqueueTestNotification(
                title: copy.title,
                body: copy.body,
                categoryIdentifier: PrayerNotificationContent.CategoryID.reminder,
                sound: PrayerNotificationContent.sound(for: settings.notifications, channel: .reminder),
                userInfo: PrayerNotificationContent.debugUserInfo(kind: .reminderBeforeAdhan, prayerKey: "maghrib", mosqueSlug: slug)
            )
        case .all:
            let adhan = PrayerNotificationContent.adhanCopy(prayerKey: "maghrib", isFriday: false)
            await enqueueTestNotification(
                title: adhan.title,
                body: adhan.body,
                categoryIdentifier: PrayerNotificationContent.CategoryID.adhan,
                sound: PrayerNotificationContent.sound(for: settings.notifications, channel: .adhan),
                userInfo: PrayerNotificationContent.debugUserInfo(kind: .adhan, prayerKey: "maghrib", mosqueSlug: slug)
            )
            let iq = PrayerNotificationContent.iqamahCopy(prayerKey: "maghrib", isFriday: false)
            await enqueueTestNotification(
                title: iq.title,
                body: iq.body,
                categoryIdentifier: PrayerNotificationContent.CategoryID.iqamah,
                sound: PrayerNotificationContent.sound(for: settings.notifications, channel: .iqamah),
                userInfo: PrayerNotificationContent.debugUserInfo(kind: .iqamah, prayerKey: "maghrib", mosqueSlug: slug)
            )
            let rem = PrayerNotificationContent.beforeAdhanReminderCopy(prayerKey: "maghrib", isFriday: false, minutes: 10)
            await enqueueTestNotification(
                title: rem.title,
                body: rem.body,
                categoryIdentifier: PrayerNotificationContent.CategoryID.reminder,
                sound: PrayerNotificationContent.sound(for: settings.notifications, channel: .reminder),
                userInfo: PrayerNotificationContent.debugUserInfo(kind: .reminderBeforeAdhan, prayerKey: "maghrib", mosqueSlug: slug)
            )
        }
    }

    /// Immediate delivery (`trigger: nil`), unique identifiers per fire — same approach as Al Muraja’ah / QuranScroll test hooks.
    private func enqueueTestNotification(
        title: String,
        body: String,
        categoryIdentifier: String,
        sound: UNNotificationSound,
        userInfo: [AnyHashable: Any]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = userInfo
        let identifier = "masjidly.debug.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UNUserNotificationCenter.current().add(request) { _ in
                continuation.resume()
            }
        }
    }

    private func applyNotificationPolicy() async {
        let n = settings.notifications
        if n.masterEnabled, let slug = settings.selectedMosqueSlug,
           let mosque = mosques.first(where: { $0.slug == slug }) ?? mosques.first(where: { $0.id == settings.selectedMosqueId }) {
            try? await notificationScheduler.rescheduleUpcomingPrayerNotifications(
                mosque: mosque,
                days: 7,
                settings: n,
                locale: settings.resolvedLocale
            )
        } else {
            await notificationScheduler.cancelAllPrayerNotifications()
        }
    }
}
