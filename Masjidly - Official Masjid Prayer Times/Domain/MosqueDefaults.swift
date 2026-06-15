import Foundation

enum MosqueDefaults {
    static let defaultSlug = "muslim-welfare-house"

    static func visibleMosques(_ all: [Mosque]) -> [Mosque] {
        all.filter { !$0.isHiddenResolved }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func resolveSelectedMosque(mosques: [Mosque], selectedId: String?, selectedSlug: String?) -> Mosque? {
        let visible = visibleMosques(mosques)
        guard !visible.isEmpty else { return nil }
        if let id = selectedId, let m = visible.first(where: { $0.id == id }) {
            return m
        }
        if let slug = selectedSlug, let m = visible.first(where: { $0.slug == slug }) {
            return m
        }
        return visible.first(where: { $0.slug == defaultSlug }) ?? visible[0]
    }

    // MARK: - Country

    /// Stable key for grouping mosques by country.
    static func countryGroupingKey(for mosque: Mosque) -> String {
        let code = mosque.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return code.isEmpty ? "unknown" : code.uppercased()
    }

    /// Distinct countries for pickers (sorted by display label).
    static func countryOptions(from mosques: [Mosque]) -> [(key: String, label: String)] {
        let visible = visibleMosques(mosques)
        let grouped = Dictionary(grouping: visible, by: { countryGroupingKey(for: $0) })
        let keys = grouped.keys.sorted { lhs, rhs in
            countryLabel(for: lhs, grouped: grouped)
                .localizedCaseInsensitiveCompare(countryLabel(for: rhs, grouped: grouped)) == .orderedAscending
        }
        return keys.map { key in (key, countryLabel(for: key, grouped: grouped)) }
    }

    /// Filter mosques to those belonging to the given country grouping key.
    static func mosques(inCountryGroupingKey key: String, mosques: [Mosque]) -> [Mosque] {
        visibleMosques(mosques).filter { countryGroupingKey(for: $0) == key }
    }

    private static func countryLabel(for key: String, grouped: [String: [Mosque]]) -> String {
        grouped[key]?.first?.countryName
            ?? grouped[key]?.first?.countryCode
            ?? key
    }

    // MARK: - City

    /// Distinct cities for settings / onboarding pickers (sorted by display label).
    /// When `countryKey` is non-nil, only mosques within that country are considered.
    static func cityOptions(from mosques: [Mosque], countryKey: String? = nil) -> [(key: String, label: String)] {
        let filtered: [Mosque]
        if let countryKey, !countryKey.isEmpty {
            filtered = Self.mosques(inCountryGroupingKey: countryKey, mosques: mosques)
        } else {
            filtered = visibleMosques(mosques)
        }
        guard !filtered.isEmpty else { return [] }
        let grouped = Dictionary(grouping: filtered, by: { $0.cityGroupingKey })
        let keys = grouped.keys.sorted { lhs, rhs in
            cityLabel(for: lhs, grouped: grouped)
                .localizedCaseInsensitiveCompare(cityLabel(for: rhs, grouped: grouped)) == .orderedAscending
        }
        return keys.map { key in (key, cityLabel(for: key, grouped: grouped)) }
    }

    static func mosques(inCityGroupingKey key: String, mosques: [Mosque]) -> [Mosque] {
        visibleMosques(mosques).filter { $0.cityGroupingKey == key }
    }

    private static func cityLabel(for key: String, grouped: [String: [Mosque]]) -> String {
        grouped[key]?.first?.cityName
            ?? grouped[key]?.first?.cityDisplayName
            ?? key
    }
}
