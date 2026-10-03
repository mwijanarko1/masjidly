import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Applies and clears Prayer Focus shields for windows the app registers.
/// Keys mirror `PrayerFocusShared` in the app target.
///
/// Callbacks can arrive early, late, or from monitors the app just replaced (stopping an ongoing
/// monitor sends an end callback). Each monitor has a generation id; ending retires that
/// generation so a delayed start cannot reactivate it, and an old generation's end cannot
/// retire its replacement. The app publishes windows and live generations before it stops or
/// starts monitors.
final class PrayerFocusMonitor: DeviceActivityMonitor {
    private struct Window: Decodable {
        let start: Date
        let end: Date
    }

    private let defaults = UserDefaults(suiteName: "group.mikhailspeaks.masjidly")
    private let store = ManagedSettingsStore(named: .init("prayerFocus"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        handle(kind: .start, activity: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        handle(kind: .end, activity: activity)
    }

    private func handle(kind: PrayerFocusMonitorReconcile.CallbackKind, activity: DeviceActivityName) {
        guard let generation = PrayerFocusMonitorReconcile.generation(fromActivityName: activity.rawValue) else {
            // Pre-generation activity names: fall back to window reconcile only.
            applyShield(isActive: isActive(treatLastMinuteAsEnded: kind == .end))
            return
        }

        let retired = Set(decode([Int].self, forKey: "prayerFocus.retiredGenerations.v1") ?? [])
        let live = Set(decode([Int].self, forKey: "prayerFocus.liveGenerations.v1") ?? [])
        let windows = (decode([Window].self, forKey: "prayerFocus.windows.v1") ?? [])
            .map { PrayerFocusMonitorReconcile.Window(start: $0.start, end: $0.end) }

        let outcome = PrayerFocusMonitorReconcile.outcome(
            kind: kind,
            generation: generation,
            now: Date(),
            windows: windows,
            liveGenerations: live,
            retiredGenerations: retired
        )
        if outcome.retiredGenerations != retired {
            save(Array(outcome.retiredGenerations), forKey: "prayerFocus.retiredGenerations.v1")
        }
        guard outcome.applyShieldUpdate else { return }
        applyShield(isActive: outcome.isActive)
    }

    private func isActive(treatLastMinuteAsEnded: Bool) -> Bool {
        let now = Date()
        let tolerance = PrayerFocusMonitorReconcile.callbackTolerance
        let windows = decode([Window].self, forKey: "prayerFocus.windows.v1") ?? []
        return windows.contains {
            $0.start.addingTimeInterval(-tolerance) <= now
                && now < $0.end.addingTimeInterval(treatLastMinuteAsEnded ? -tolerance : 0)
        }
    }

    private func applyShield(isActive: Bool) {
        guard isActive,
              let selection = decode(FamilyActivitySelection.self, forKey: "prayerFocus.selection.v1") else {
            store.clearAllSettings()
            return
        }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let webDomains = selection.webDomainTokens
        // Keep in sync with PrayerFocusController.applyShield.
        guard !apps.isEmpty || !categories.isEmpty || !webDomains.isEmpty else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    }

    private func save(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults?.set(data, forKey: key)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
