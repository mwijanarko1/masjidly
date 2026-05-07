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
}
