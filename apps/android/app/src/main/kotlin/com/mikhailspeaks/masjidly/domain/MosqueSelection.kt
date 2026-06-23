package com.mikhailspeaks.masjidly.domain

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

object MosqueSelection {
    fun visibleMosques(all: List<Mosque>): List<Mosque> =
        all.filter { !it.isHiddenResolved }
            .sortedBy { it.name.lowercase() }

    fun resolveSelectedMosque(
        mosques: List<Mosque>,
        selectedId: String?,
        selectedSlug: String?,
    ): Mosque? {
        val visible = visibleMosques(mosques)
        if (visible.isEmpty()) return null
        selectedId?.let { id ->
            visible.firstOrNull { it.id == id }?.let { return it }
        }
        selectedSlug?.let { slug ->
            visible.firstOrNull { it.slug == slug }?.let { return it }
        }
        return visible.firstOrNull { it.slug == MosqueDefaults.DEFAULT_MOSQUE_SLUG } ?: visible.first()
    }

    fun countryGroupingKey(mosque: Mosque): String {
        val code = mosque.countryCode?.trim().orEmpty()
        return if (code.isEmpty()) "unknown" else code.uppercase()
    }

    /** Distinct countries for pickers (sorted by label). */
    fun countryOptions(mosques: List<Mosque>): List<Pair<String, String>> {
        val visible = visibleMosques(mosques)
        val grouped = visible.groupBy { countryGroupingKey(it) }
        return grouped.keys.sortedBy { key ->
            val label = grouped[key]?.first()?.countryName
                ?: grouped[key]?.first()?.countryCode
                ?: key
            label.lowercase()
        }.map { key ->
            val label = grouped[key]?.first()?.countryName
                ?: grouped[key]?.first()?.countryCode
                ?: key
            key to label
        }
    }

    /** Filter mosques to those belonging to the given country key. */
    fun mosquesInCountry(countryGroupingKey: String, mosques: List<Mosque>): List<Mosque> =
        visibleMosques(mosques).filter { countryGroupingKey(it) == countryGroupingKey }

    /** Distinct cities for pickers (sorted by label), optionally filtered to a country. */
    fun cityOptions(mosques: List<Mosque>, countryKey: String? = null): List<Pair<String, String>> {
        val filtered = if (!countryKey.isNullOrEmpty()) {
            mosquesInCountry(countryGroupingKey = countryKey, mosques = mosques)
        } else {
            visibleMosques(mosques)
        }
        if (filtered.isEmpty()) return emptyList()
        val grouped = filtered.groupBy { it.cityGroupingKey }
        return grouped.keys.sortedBy { key ->
            grouped[key]?.first()?.cityName?.lowercase() ?: key
        }.map { key ->
            val label = grouped[key]?.first()?.cityName
                ?: grouped[key]?.first()?.cityDisplayName
                ?: key
            key to label
        }
    }

    /** Filter mosques to those belonging to the given city grouping key. */
    fun mosquesInCity(cityGroupingKey: String, mosques: List<Mosque>): List<Mosque> =
        visibleMosques(mosques).filter { it.cityGroupingKey == cityGroupingKey }

    /** Mirrors iOS `effectiveCountryGroupingKey` in `SettingsView`. */
    fun effectiveCountryGroupingKey(
        mosques: List<Mosque>,
        storedKey: String?,
        selectedMosqueId: String?,
    ): String {
        if (!storedKey.isNullOrEmpty() && mosquesInCountry(storedKey, mosques).isNotEmpty()) {
            return storedKey
        }
        selectedMosqueId?.let { id ->
            visibleMosques(mosques).firstOrNull { it.id == id }?.let { mosque ->
                return countryGroupingKey(mosque)
            }
        }
        return countryOptions(mosques).firstOrNull()?.first.orEmpty()
    }

    /** Mirrors iOS `effectiveCityGroupingKey` in `SettingsView`. */
    fun effectiveCityGroupingKey(
        mosques: List<Mosque>,
        countryKey: String,
        storedKey: String?,
        selectedMosqueId: String?,
    ): String {
        val countryMosques = mosquesInCountry(countryKey, mosques)
        if (!storedKey.isNullOrEmpty() && mosquesInCity(storedKey, countryMosques).isNotEmpty()) {
            return storedKey
        }
        selectedMosqueId?.let { id ->
            countryMosques.firstOrNull { it.id == id }?.let { mosque ->
                return mosque.cityGroupingKey
            }
        }
        return cityOptions(mosques, countryKey).firstOrNull()?.first.orEmpty()
    }

    /** Mosques in the selected country + city — mirrors iOS `mosquesInSelectedCity`. */
    fun mosquesInSelectedCity(
        mosques: List<Mosque>,
        countryKey: String,
        cityKey: String,
    ): List<Mosque> {
        val countryMosques = mosquesInCountry(countryKey, mosques)
        if (cityKey.isEmpty()) return countryMosques
        return mosquesInCity(cityKey, countryMosques)
    }

    fun effectiveSelectedMosqueId(
        mosquesInCity: List<Mosque>,
        selectedMosqueId: String?,
    ): String {
        selectedMosqueId?.let { id ->
            if (mosquesInCity.any { it.id == id }) return id
        }
        return mosquesInCity.firstOrNull()?.id.orEmpty()
    }

    fun closestMosque(
        mosques: List<Mosque>,
        userLat: Double,
        userLng: Double,
    ): Mosque? =
        visibleMosques(mosques).minByOrNull { mosque ->
            distanceInMeters(userLat, userLng, mosque.lat, mosque.lng)
        }

    fun distanceInMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val earthRadiusMeters = 6_371_000.0
        val toRadians = { degrees: Double -> Math.toRadians(degrees) }
        val deltaLat = toRadians(lat2 - lat1)
        val deltaLng = toRadians(lng2 - lng1)
        val a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(toRadians(lat1)) * cos(toRadians(lat2)) *
            sin(deltaLng / 2) * sin(deltaLng / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }
}
