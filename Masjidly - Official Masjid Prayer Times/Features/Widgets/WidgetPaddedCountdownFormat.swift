import Foundation

/// Live padded `-HH:MM:SS` for widget `TimeDataSource.durationOffset` (iOS 18+).
///
/// `durationOffset(to: future)` yields a negative `Duration` while counting down. After the target it becomes
/// positive and would count up; this style clamps that to `-00:00:00` and stops discrete scheduling at zero.
///
/// Same source file is compiled into the app target (unit tests) and the widget target (production UI).
@available(iOS 18.0, *)
struct WidgetPaddedCountdownFormat: DiscreteFormatStyle, Sendable {
    typealias FormatInput = Duration
    typealias FormatOutput = String

    var locale: Locale

    init(locale: Locale = Locale(identifier: "en_GB")) {
        self.locale = locale
    }

    private var inner: Duration.TimeFormatStyle {
        Duration.TimeFormatStyle(
            pattern: .hourMinuteSecond(padHourToLength: 2),
            locale: locale
        )
    }

    /// Terminal display once remaining rounds to zero or the target is in the past.
    static let zeroDisplay = "-00:00:00"

    func format(_ value: Duration) -> String {
        if value >= .zero {
            return Self.zeroDisplay
        }
        let raw = inner.format(value)
        // Near-zero negatives (e.g. -0.5s) format as `00:00:00` without a minus; keep product minus.
        return raw.hasPrefix("-") ? raw : Self.zeroDisplay
    }

    func discreteInput(before input: Duration) -> Duration? {
        let current = format(input)

        if current == Self.zeroDisplay {
            // Walk backward past the clamped-zero plateau to the last non-zero countdown second.
            var cursor: Duration = input > .zero ? .zero : input
            for _ in 0..<8 {
                guard let prev = inner.discreteInput(before: cursor) else { return nil }
                if format(prev) != Self.zeroDisplay {
                    return prev
                }
                if prev >= cursor { return nil }
                cursor = prev
            }
            return nil
        }

        return inner.discreteInput(before: input)
    }

    func discreteInput(after input: Duration) -> Duration? {
        if format(input) == Self.zeroDisplay {
            // Halt: no further schedule past the clamped zero display.
            return nil
        }

        guard let next = inner.discreteInput(after: input) else { return nil }
        if format(next) == Self.zeroDisplay {
            // Land exactly on zero as the final discrete bound; `after(.zero)` then returns nil.
            return .zero
        }
        return next
    }

    func locale(_ locale: Locale) -> WidgetPaddedCountdownFormat {
        WidgetPaddedCountdownFormat(locale: locale)
    }
}
