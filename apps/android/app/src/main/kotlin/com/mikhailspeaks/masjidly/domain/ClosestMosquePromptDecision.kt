package com.mikhailspeaks.masjidly.domain

/**
 * Pure rules for the launch-time “closer mosque nearby” prompt.
 * Mirrors iOS `ClosestMosquePromptDecision`.
 */
object ClosestMosquePromptDecision {
    fun shouldPresent(
        closestMosqueId: String?,
        selectedMosqueId: String?,
        dismissedClosestMosqueId: String?,
        visibleMosqueCount: Int,
    ): Boolean {
        if (visibleMosqueCount < 2) return false
        if (closestMosqueId == null || selectedMosqueId == null) return false
        if (closestMosqueId == selectedMosqueId) return false
        if (closestMosqueId == dismissedClosestMosqueId) return false
        return true
    }

    fun closestMosque(
        mosques: List<Mosque>,
        userLat: Double,
        userLng: Double,
    ): Mosque? = MosqueSelection.closestMosque(mosques, userLat, userLng)
}
