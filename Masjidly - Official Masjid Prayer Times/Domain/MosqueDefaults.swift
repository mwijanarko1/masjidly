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

    /// Distinct cities for settings / onboarding pickers (sorted by display label).
    static func cityOptions(from mosques: [Mosque]) -> [(key: String, label: String)] {
        let visible = visibleMosques(mosques)
        let grouped = Dictionary(grouping: visible, by: { $0.cityGroupingKey })
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
