import CoreLocation

/// Pure rules for the launch-time “closer mosque nearby” prompt.
enum ClosestMosquePromptDecision {
    static func shouldPresent(
        closestMosqueId: String?,
        selectedMosqueId: String?,
        dismissedClosestMosqueId: String?,
        visibleMosqueCount: Int
    ) -> Bool {
        guard visibleMosqueCount >= 2 else { return false }
        guard let closestMosqueId, let selectedMosqueId else { return false }
        guard closestMosqueId != selectedMosqueId else { return false }
        guard closestMosqueId != dismissedClosestMosqueId else { return false }
        return true
    }

    static func closestMosque(in mosques: [Mosque], userLatitude: Double, userLongitude: Double) -> Mosque? {
        let visible = MosqueDefaults.visibleMosques(mosques)
        guard !visible.isEmpty else { return nil }
        let userLocation = CLLocation(latitude: userLatitude, longitude: userLongitude)
        return visible.min { lhs, rhs in
            let lhsLocation = CLLocation(latitude: lhs.lat, longitude: lhs.lng)
            let rhsLocation = CLLocation(latitude: rhs.lat, longitude: rhs.lng)
            return lhsLocation.distance(from: userLocation) < rhsLocation.distance(from: userLocation)
        }
    }
}
