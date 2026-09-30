import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation
import SwiftUI
import UIKit

/// App Group keys shared with Prayer Focus extensions. Keep in sync with monitor + shield targets.
enum PrayerFocusShared {
    static let selectionKey = "prayerFocus.selection.v1"
    static let windowsKey = "prayerFocus.windows.v1"
    static let generationKey = "prayerFocus.generation.v1"
    static let liveGenerationsKey = "prayerFocus.liveGenerations.v1"
    static let retiredGenerationsKey = "prayerFocus.retiredGenerations.v1"
    static let themeColorsKey = "prayerFocus.themeColors.v1"
    static let storeName = ManagedSettingsStore.Name("prayerFocus")
}

/// Shields user-selected apps during prayer windows for the active mosque.
/// App selections stay on device (App Group only); nothing is sent to Convex or analytics.
@Observable
@MainActor
final class PrayerFocusController {
    static let shared = PrayerFocusController()

    enum Status: Equatable {
        case off
        case needsAuthorization
        case needsSelection
        case noUpcomingTimes
        case failed
        case scheduled(until: Date)
        case active(until: Date)
    }

    private static let settingsKey = "prayerFocus.settings.v1"
    private static let suppressedUntilKey = "prayerFocus.suppressedUntil.v1"

    private static let appGroupDefaults = UserDefaults(suiteName: WidgetPrayerSharedConfig.appGroupIdentifier) ?? .standard
    private let defaults = PrayerFocusController.appGroupDefaults
    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore(named: PrayerFocusShared.storeName)

    var settings: PrayerFocusSettings {
        didSet {
            guard settings != oldValue else { return }
            save(settings, forKey: Self.settingsKey)
            reschedule()
        }
    }

    var selection: FamilyActivitySelection {
        didSet {
            save(selection, forKey: PrayerFocusShared.selectionKey)
            reschedule()
        }
    }

    var isPickerPresented = false
    private(set) var isAuthorized = false
    private(set) var scheduleFailed = false
    private(set) var windows: [PrayerFocusWindow] = []
    private var suppressedUntil: Date?
    /// Device zone the current monitors were registered in; a change forces re-registration.
    @ObservationIgnored private var registeredTimeZone: TimeZone?
    @ObservationIgnored private weak var appSettings: SettingsStore?
    @ObservationIgnored private var refreshSnapshot: (() async -> Void)?
    /// Latest monitor registration; lets a failed older registration skip clearing a newer schedule.
    @ObservationIgnored private var registrationRequest = 0
    private static let registrationQueue = DispatchQueue(label: "prayerFocus.registration", qos: .utility)

    /// Apps, categories (e.g. Social), and web domains from the system picker.
    var selectedAppCount: Int { Self.selectionCount(selection) }

    static func selectionCount(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    /// iOS does not expose how many apps a category contains, so show each token kind separately.
    static func selectionSummary(_ selection: FamilyActivitySelection, locale: Locale, localized: (String) -> String) -> String {
        [
            ("apps", selection.applicationTokens.count),
            ("categories", selection.categoryTokens.count),
            ("websites", selection.webDomainTokens.count),
        ]
        .filter { $0.1 > 0 }
        .map { String(format: localized("settings.prayer_focus.count.\($0.0)"), locale: locale, arguments: [$0.1]) }
        .joined(separator: " · ")
    }

    /// Takes `now` so views can re-evaluate at window boundaries (time passing is not observable).
    func status(at now: Date) -> Status {
        guard settings.isEnabled else { return .off }
        guard isAuthorized else { return .needsAuthorization }
        guard selectedAppCount > 0 else { return .needsSelection }
        if scheduleFailed { return .failed }
        if let active = windows.first(where: { $0.contains(now) }) { return .active(until: active.end) }
        guard let last = windows.last(where: { $0.end > now }) else { return .noUpcomingTimes }
        return .scheduled(until: last.end)
    }

    private init() {
        settings = Self.load(PrayerFocusSettings.self, forKey: Self.settingsKey, from: Self.appGroupDefaults) ?? PrayerFocusSettings()
        selection = Self.load(FamilyActivitySelection.self, forKey: PrayerFocusShared.selectionKey, from: Self.appGroupDefaults) ?? FamilyActivitySelection()
        suppressedUntil = Self.appGroupDefaults.object(forKey: Self.suppressedUntilKey) as? Date
        for name in [UIApplication.didBecomeActiveNotification, .NSSystemTimeZoneDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // The system zone is cached per process; drop it so re-registration sees the new zone.
                if name == .NSSystemTimeZoneDidChange { NSTimeZone.resetSystemTimeZone() }
                MainActor.assumeIsolated { self?.reschedule() }
            }
        }
    }

    /// Connects the active mosque and Asr preference. Scheduling waits for this so it never
    /// trusts a snapshot it cannot validate.
    func attach(settings: SettingsStore, refreshSnapshot: @escaping () async -> Void) {
        appSettings = settings
        self.refreshSnapshot = refreshSnapshot
        observeActiveTimetable()
        reschedule()
    }

    /// A mosque or Asr change drops the old windows at once; the refreshed snapshot rebuilds them.
    private func observeActiveTimetable() {
        guard let appSettings else { return }
        withObservationTracking {
            _ = appSettings.selectedMosqueId
            _ = appSettings.asrIqamahPreference
        } onChange: { [weak self] in
            // onChange fires before the new value is stored; the task runs after it lands.
            Task { @MainActor in
                guard let self else { return }
                self.observeActiveTimetable()
                self.reschedule()
                await self.refreshSnapshot?()
            }
        }
    }

    /// Requests individual Screen Time authorization without turning Prayer Focus on.
    /// Throws the system error when the person cancels or authorization fails.
    func requestAuthorization() async throws {
        if !Self.hasAuthorization {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        }
        isAuthorized = Self.hasAuthorization
    }

    /// Settings toggle: requests authorization, turns Prayer Focus on, and opens the picker if no apps are selected.
    /// Status shows `.needsAuthorization` when access was not granted.
    func enable() async {
        try? await requestAuthorization()
        if !settings.isEnabled {
            settings.isEnabled = true
        } else {
            // Already enabled: refresh auth/windows without rewriting settings (avoids didSet churn).
            reschedule()
        }
        if isAuthorized, selectedAppCount == 0 {
            isPickerPresented = true
        }
    }

    func disable() {
        settings.isEnabled = false
    }

    /// Ends only the current window; future prayers still block.
    func stopCurrentWindow() {
        guard let active = windows.first(where: { $0.contains(Date()) }) else { return }
        suppressedUntil = active.end
        defaults.set(active.end, forKey: Self.suppressedUntilKey)
        reschedule()
    }

    /// Replaces all monitors from the latest active-mosque snapshot and reconciles the shield.
    /// Called on attach, activation, time-zone change, settings or timetable change, and each widget snapshot refresh.
    func reschedule() {
        // Shield Action may write this while the app is suspended; always re-read before planning.
        suppressedUntil = defaults.object(forKey: Self.suppressedUntilKey) as? Date

        let now = Date()
        let authorized = Self.hasAuthorization
        if isAuthorized != authorized { isAuthorized = authorized }
        scheduleFailed = false

        var planned: [PrayerFocusWindow] = []
        var invalidMosqueTimeZone = false
        if settings.isEnabled, isAuthorized, selectedAppCount > 0, let snapshot = currentSnapshot() {
            // An unknown mosque zone cannot be turned into instants; fail visibly instead of guessing.
            invalidMosqueTimeZone = snapshot.mosque.prayerTimeZone == nil
            planned = PrayerFocusScheduleBuilder.windows(snapshot: snapshot, settings: settings, now: now, suppressedUntil: suppressedUntil)
        }

        publishThemeColors()

        // DeviceActivity stop/start is expensive, so skip when the windows and the device zone the
        // monitors were registered in are both unchanged. Windows are absolute instants, so a zone
        // change alone would otherwise leave stale registrations.
        let deviceTimeZone = TimeZone.current
        if planned == windows, deviceTimeZone == registeredTimeZone {
            scheduleFailed = invalidMosqueTimeZone
            reconcileShield(now: now)
            return
        }

        // Publish first: stopping ongoing monitors sends end callbacks that the extension
        // checks against these windows/generations, so stale callbacks cannot clear or restore shields.
        let scheduled = publish(planned)
        registeredTimeZone = deviceTimeZone
        scheduleFailed = invalidMosqueTimeZone
        reconcileShield(now: now)

        let monitors = scheduled.map { item in
            (
                name: DeviceActivityName(PrayerFocusMonitorReconcile.activityName(generation: item.generation, start: item.window.start)),
                schedule: Self.schedule(for: item.window, in: deviceTimeZone)
            )
        }
        registrationRequest += 1
        let request = registrationRequest
        let center = center
        // Stop/start are synchronous XPC calls (up to 20 per run, on every cold launch); off the main
        // thread they no longer freeze the first screen. The serial queue applies requests in publish order.
        Self.registrationQueue.async {
            center.stopMonitoring()
            do {
                for monitor in monitors {
                    try center.startMonitoring(monitor.name, during: monitor.schedule)
                }
            } catch {
                center.stopMonitoring()
                Task { @MainActor [weak self] in
                    // A newer request has already replaced this schedule.
                    guard let self, self.registrationRequest == request else { return }
                    _ = self.publish([])
                    self.scheduleFailed = true
                    self.reconcileShield(now: Date())
                }
            }
        }
    }

    /// Only a snapshot for the current active mosque and Asr preference may drive blocking.
    private func currentSnapshot() -> WidgetPrayerSnapshot? {
        guard let appSettings, let snapshot = try? WidgetPrayerSnapshotStore().readSnapshot() else { return nil }
        if let mosqueId = appSettings.selectedMosqueId, mosqueId != snapshot.mosque.id { return nil }
        guard (snapshot.asrIqamahPreference ?? .first) == appSettings.asrIqamahPreference else { return nil }
        return snapshot
    }

    /// Assigns a fresh generation per monitor so a replaced window's callbacks cannot reactivate it.
    @discardableResult
    private func publish(_ planned: [PrayerFocusWindow]) -> [(generation: Int, window: PrayerFocusWindow)] {
        windows = planned
        save(planned, forKey: PrayerFocusShared.windowsKey)

        var next = defaults.integer(forKey: PrayerFocusShared.generationKey)
        var scheduled: [(generation: Int, window: PrayerFocusWindow)] = []
        scheduled.reserveCapacity(planned.count)
        for window in planned {
            next += 1
            scheduled.append((next, window))
        }
        let live = scheduled.map(\.generation)
        defaults.set(next, forKey: PrayerFocusShared.generationKey)
        save(live, forKey: PrayerFocusShared.liveGenerationsKey)

        // Drop retired IDs that can no longer receive callbacks.
        let retired = Set(Self.load([Int].self, forKey: PrayerFocusShared.retiredGenerationsKey, from: defaults) ?? [])
            .filter { $0 > next - 100 }
        save(Array(retired), forKey: PrayerFocusShared.retiredGenerationsKey)
        return scheduled
    }

    /// Covers `.approved` and iOS 26.4's `.approvedWithDataAccess`.
    private static var hasAuthorization: Bool {
        let status = AuthorizationCenter.shared.authorizationStatus
        return status != .notDetermined && status != .denied
    }

    private func reconcileShield(now: Date) {
        if windows.contains(where: { $0.contains(now) }) {
            Self.applyShield(selection, to: store)
        } else {
            store.clearAllSettings()
        }
    }

    /// Categories like Social live in `categoryTokens`, not `applicationTokens`.
    static func applyShield(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let webDomains = selection.webDomainTokens
        guard !apps.isEmpty || !categories.isEmpty || !webDomains.isEmpty else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    }

    /// Writes each prayer's resolved sky color for the Shield Configuration extension.
    private func publishThemeColors() {
        var colors: [String: PrayerFocusShieldTheme] = [:]
        for prayer in PrayerFocusPrayer.allCases {
            guard let theme = HomeDesign.TimeTheme(rawValue: prayer.rawValue) else { continue }
            if let appSettings {
                let resolved = appSettings.resolvedAppearance(for: theme)
                let background = Self.shieldBackgroundHex(from: resolved.sky.baseColors)
                let foreground = resolved.usesLightForeground ? "FFFFFF" : "111111"
                colors[prayer.rawValue] = PrayerFocusShieldTheme(backgroundHex: background, foregroundHex: foreground)
            } else {
                let background = Self.shieldBackgroundHex(from: theme.sky.baseColors)
                let foreground = theme.usesLightForeground ? "FFFFFF" : "111111"
                colors[prayer.rawValue] = PrayerFocusShieldTheme(backgroundHex: background, foregroundHex: foreground)
            }
        }
        save(colors, forKey: PrayerFocusShared.themeColorsKey)
    }

    /// Shield blur needs a chromatic tint; pale sky tops (Dhuhr/Maghrib) read as white.
    private static func shieldBackgroundHex(from colors: [Color]) -> String {
        guard !colors.isEmpty else { return "103783" }
        let richest = colors.max(by: { saturation(of: $0) < saturation(of: $1) }) ?? colors[0]
        return richest.hexRGBString()
    }

    private static func saturation(of color: Color) -> CGFloat {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return saturation
    }

    private static func schedule(for window: PrayerFocusWindow, in timeZone: TimeZone) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: PrayerFocusScheduleBuilder.deviceActivityComponents(for: window.start, in: timeZone),
            intervalEnd: PrayerFocusScheduleBuilder.deviceActivityComponents(for: window.end, in: timeZone),
            repeats: false
        )
    }

    private func save(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
