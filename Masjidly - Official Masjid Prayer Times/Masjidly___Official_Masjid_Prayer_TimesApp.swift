import SwiftUI
import UserNotifications

extension Notification.Name {
    static let masjidlyOpenTimetable = Notification.Name("masjidly.open.timetable")
    static let masjidlyOpenSettingsMosque = Notification.Name("masjidly.open.settings.mosque")
    static let masjidlyFocusHomeTimes = Notification.Name("masjidly.focus.home.times")
}

/// Shows banners and plays sound when a notification arrives while the app is open (same idea as Al Muraja’ah / QuranScroll).
final class MasjidlyNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MasjidlyNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        if action == UNNotificationDismissActionIdentifier {
            completionHandler()
            return
        }

        if action == UNNotificationDefaultActionIdentifier {
            let userInfo = response.notification.request.content.userInfo
            if let kindRaw = userInfo[PrayerNotificationContent.UserInfoKey.kind] as? String,
               kindRaw == PrayerNotificationContent.PayloadKind.adhan.rawValue {
                Task { @MainActor in
                    AdhanSoundPreviewPlayer.shared.toggle(url: PrayerNotificationContent.bundledAdhanPlaybackURL())
                }
            }
            completionHandler()
            return
        }

        Task { @MainActor in
            switch action {
            case PrayerNotificationContent.ActionID.viewTimes:
                NotificationCenter.default.post(name: .masjidlyFocusHomeTimes, object: nil)
            case PrayerNotificationContent.ActionID.openTimetable:
                NotificationCenter.default.post(name: .masjidlyOpenTimetable, object: nil)
            case PrayerNotificationContent.ActionID.viewMosque:
                NotificationCenter.default.post(name: .masjidlyOpenSettingsMosque, object: nil)
            case PrayerNotificationContent.ActionID.snoozeReminder:
                Self.scheduleSnooze(from: response.notification.request)
            case PrayerNotificationContent.ActionID.dismiss:
                break
            default:
                break
            }
        }
        completionHandler()
    }

    /// Re-fires the same alert after 10 minutes (simple snooze for reminders / adhan tests).
    private static func scheduleSnooze(from request: UNNotificationRequest) {
        let o = request.content
        let base = UNMutableNotificationContent()
        base.title = o.title
        base.subtitle = o.subtitle
        base.body = o.body
        base.sound = o.sound
        base.categoryIdentifier = o.categoryIdentifier
        base.userInfo = o.userInfo
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        let id = "masjidly.snooze.\(UUID().uuidString)"
        let snoozeRequest = UNNotificationRequest(identifier: id, content: base, trigger: trigger)
        UNUserNotificationCenter.current().add(snoozeRequest)
    }
}

@main
struct Masjidly___Official_Masjid_Prayer_TimesApp: App {
    @State private var env = AppEnvironment()

    init() {
        UNUserNotificationCenter.current().delegate = MasjidlyNotificationDelegate.shared
        PrayerNotificationContent.registerCategories()

        let fontName = "Gill Sans"
        let largeFont = UIFont(name: fontName, size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        let smallFont = UIFont(name: fontName, size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)

        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeFont]
        UINavigationBar.appearance().titleTextAttributes = [.font: smallFont]
    }

    var body: some Scene {
        WindowGroup {
            MasjidlyRootView(homeViewModel: env.homeViewModel)
                .environment(env.settings)
                .environment(env.settingsViewModel)
                .environment(env.onboardingFlowController)
                .environment(env.appReviewPromptCoordinator)
                .environment(\.appFontName, env.settings.appFontName)
        }
    }
}
