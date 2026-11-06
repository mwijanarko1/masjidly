import os
import SwiftUI

/// Text that sets any AM/PM marker smaller than the surrounding digits, for example `6:25` with a small `PM`.
/// Works on whole strings, so composed lines such as `Iqamah: 4:31PM` and `5:00PM · 5:15PM` are styled too.
struct MeridiemText: View {
    let text: String
    let size: CGFloat
    var weight: Font.Weight = .regular
    /// Size of the AM/PM marker relative to `size`.
    var meridiemScale: CGFloat = 0.6

    @Environment(\.appFontName) private var fontName
    @Environment(\.locale) private var locale

    var body: some View {
        Text(Self.styled(text, size: size, weight: weight, meridiemScale: meridiemScale, fontName: fontName, locale: locale))
    }

    static func styled(
        _ text: String,
        size: CGFloat,
        weight: Font.Weight,
        meridiemScale: CGFloat,
        fontName: String,
        locale: Locale
    ) -> AttributedString {
        let isArabic = locale.identifier.hasPrefix("ar")
        let isUrdu = locale.identifier.hasPrefix("ur")
        let languageScale: CGFloat = isUrdu ? 1.25 : (isArabic ? 1.20 : 1.00)
        let base = HomeDesign.Typography.app(size: size * languageScale, weight: weight, name: fontName)
        let small = HomeDesign.Typography.app(size: size * languageScale * meridiemScale, weight: weight, name: fontName)

        var out = AttributedString()
        func append(_ piece: String, font: Font) {
            guard !piece.isEmpty else { return }
            var run = AttributedString(piece)
            run.font = font
            out.append(run)
        }

        guard let regex = meridiemRegex(locale: locale) else {
            append(text, font: base)
            return out
        }
        let ns = text as NSString
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            append(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)), font: base)
            // A hair space keeps the marker off the digits without a full word gap.
            append("\u{200A}" + ns.substring(with: match.range(at: 1)), font: small)
            cursor = match.range.location + match.range.length
        }
        append(ns.substring(from: cursor), font: base)
        return out
    }

    /// Matches an AM/PM marker that directly follows a digit, with optional space in between.
    private static func meridiemRegex(locale: Locale) -> NSRegularExpression? {
        cache.withLock { store in
            if let hit = store[locale.identifier] { return hit }
            let built = buildMeridiemRegex(locale: locale)
            store[locale.identifier] = .some(built)
            return built
        }
    }

    private static let cache = OSAllocatedUnfairLock<[String: NSRegularExpression?]>(initialState: [:])

    private static func buildMeridiemRegex(locale: Locale) -> NSRegularExpression? {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = Set([formatter.amSymbol, formatter.pmSymbol, "AM", "PM", "am", "pm"].compactMap { $0 })
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
        guard !symbols.isEmpty else { return nil }
        let pattern = "(?<=\\p{Nd})[\\s\\u00A0\\u202F\\u2009\\u200A]*(" + symbols.joined(separator: "|") + ")(?!\\p{L})"
        return try? NSRegularExpression(pattern: pattern)
    }
}
