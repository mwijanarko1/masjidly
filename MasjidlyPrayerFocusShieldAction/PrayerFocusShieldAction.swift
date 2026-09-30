import Foundation
import ManagedSettings

/// Handles shield buttons. "I've prayed" ends the current Prayer Focus window only.
final class PrayerFocusShieldAction: ShieldActionDelegate {
    private struct Window: Codable {
        let start: Date
        let end: Date
        let prayer: String?
    }

    private let defaults = UserDefaults(suiteName: "group.mikhailspeaks.masjidly")
    private let store = ManagedSettingsStore(named: .init("prayerFocus"))

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    private func handle(action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Leave Prayer Focus on; dismiss the shielded app.
            completionHandler(.close)
        case .secondaryButtonPressed:
            // Clear the shield, then .defer so the system reopens the app instead of exiting.
            endCurrentWindow()
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    /// Mirrors `PrayerFocusController.stopCurrentWindow()` for the extension process.
    private func endCurrentWindow() {
        let now = Date()
        var windows = decode([Window].self, forKey: "prayerFocus.windows.v1") ?? []
        guard let active = windows.first(where: { $0.start <= now && now < $0.end }) else {
            store.clearAllSettings()
            return
        }

        defaults?.set(active.end, forKey: "prayerFocus.suppressedUntil.v1")
        windows.removeAll { $0.start == active.start && $0.end == active.end }
        if let data = try? JSONEncoder().encode(windows) {
            defaults?.set(data, forKey: "prayerFocus.windows.v1")
        }
        store.clearAllSettings()
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
