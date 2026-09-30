import Foundation

/// Pure shield decision for Prayer Focus monitor callbacks.
/// Keep in sync with app `Features/PrayerFocus/PrayerFocusMonitorReconcile.swift`.
enum PrayerFocusMonitorReconcile {
    static let callbackTolerance: TimeInterval = 60

    enum CallbackKind: Equatable {
        case start
        case end
    }

    struct Window: Equatable {
        let start: Date
        let end: Date
    }

    struct Outcome: Equatable {
        /// When false, leave the ManagedSettings store unchanged.
        var applyShieldUpdate: Bool
        var isActive: Bool
        var retiredGenerations: Set<Int>
    }

    /// Activity names are `prayerFocus.<generation>.<startEpoch>`.
    static func generation(fromActivityName name: String) -> Int? {
        let parts = name.split(separator: ".")
        guard parts.count >= 3, parts[0] == "prayerFocus", let generation = Int(parts[1]) else { return nil }
        return generation
    }

    static func activityName(generation: Int, start: Date) -> String {
        "prayerFocus.\(generation).\(Int(start.timeIntervalSince1970))"
    }

    static func outcome(
        kind: CallbackKind,
        generation: Int,
        now: Date,
        windows: [Window],
        liveGenerations: Set<Int>,
        retiredGenerations: Set<Int>,
        tolerance: TimeInterval = callbackTolerance
    ) -> Outcome {
        var retired = retiredGenerations

        // Replaced monitors are no longer live; retire their ends without touching the shield.
        if !liveGenerations.contains(generation) {
            if kind == .end { retired.insert(generation) }
            return Outcome(applyShieldUpdate: false, isActive: false, retiredGenerations: retired)
        }

        if kind == .end {
            retired.insert(generation)
        } else if retired.contains(generation) {
            // Early end already cleared blocking; a delayed start must not restore it.
            return Outcome(applyShieldUpdate: false, isActive: false, retiredGenerations: retired)
        }

        let treatLastMinuteAsEnded = kind == .end
        let isActive = windows.contains {
            $0.start.addingTimeInterval(-tolerance) <= now
                && now < $0.end.addingTimeInterval(treatLastMinuteAsEnded ? -tolerance : 0)
        }
        return Outcome(applyShieldUpdate: true, isActive: isActive, retiredGenerations: retired)
    }
}
