package com.mikhailspeaks.masjidly.features.prayerfocus

/**
 * Infers visible apps from UsageStats activity events. Pure so it can be unit tested.
 *
 * The last event alone is not enough: split screen and freeform windows can keep several
 * activities resumed at once, and polling can land between one app pausing and the next resuming.
 * So this keeps the set of resumed activities plus the most recently resumed package.
 */
class ForegroundAppTracker {
    enum class Kind { RESUMED, PAUSED, STOPPED, KEYGUARD_SHOWN }

    data class Event(
        val kind: Kind,
        val packageName: String,
        val className: String?,
        val timeMillis: Long,
    )

    /** `package/class` → (package, resumed at). */
    private val resumed = LinkedHashMap<String, Pair<String, Long>>()

    /** Most recently resumed package that is still resumed. */
    var topPackage: String? = null
        private set

    val resumedPackages: Set<String>
        get() = resumed.values.mapTo(mutableSetOf()) { it.first }

    fun reset() {
        resumed.clear()
        topPackage = null
    }

    /** Applies events in time order. [launcherPackages] resuming means every other app left the screen. */
    fun apply(events: List<Event>, launcherPackages: Set<String> = emptySet()) {
        for (event in events.sortedBy { it.timeMillis }) {
            val key = "${event.packageName}/${event.className.orEmpty()}"
            when (event.kind) {
                Kind.RESUMED -> {
                    if (event.packageName in launcherPackages) resumed.clear()
                    resumed.remove(key)
                    resumed[key] = event.packageName to event.timeMillis
                    topPackage = event.packageName
                }
                Kind.PAUSED, Kind.STOPPED -> {
                    resumed.remove(key)
                    if (topPackage == event.packageName && resumed.values.none { it.first == event.packageName }) {
                        topPackage = resumed.values.maxByOrNull { it.second }?.first
                    }
                }
                // Locking pauses everything; drop state that could otherwise go stale.
                Kind.KEYGUARD_SHOWN -> reset()
            }
        }
    }

    /**
     * Whether the overlay should cover the screen. Never covers when an excluded surface
     * (Masjidly, launcher, Settings, dialer, permission UI) is on top, so escape routes stay open.
     */
    fun shouldCover(selected: Set<String>, excluded: Set<String>): Boolean {
        val top = topPackage ?: return false
        if (top in excluded) return false
        if (top in selected) return true
        // Split screen: a selected app is visible next to an unselected one.
        return resumedPackages.any { it in selected && it !in excluded }
    }
}
