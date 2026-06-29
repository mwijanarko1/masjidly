package com.mikhailspeaks.masjidly.widget

import android.content.Context
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class WidgetSnapshotStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(WidgetSharedConfig.PREFS_NAME, Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun readSnapshot(): WidgetPrayerSnapshot? {
        val selectedId = prefs.getString(WidgetSharedConfig.APP_SELECTED_MOSQUE_ID_KEY, null).orEmpty()
        val raw = listOf(
            selectedId.takeIf { it.isNotBlank() }?.let { snapshotKeyForMosque(it) },
            WidgetSharedConfig.SNAPSHOT_KEY,
        ).filterNotNull().firstNotNullOfOrNull { prefs.getString(it, null) } ?: return null
        return runCatching { json.decodeFromString<WidgetPrayerSnapshot>(raw) }
            .getOrNull()
            ?.takeIf { it.schemaVersion == WidgetPrayerSnapshot.CURRENT_SCHEMA_VERSION }
    }

    fun writeSnapshot(snapshot: WidgetPrayerSnapshot, updateDefault: Boolean = true) {
        val encoded = json.encodeToString(snapshot)
        prefs.edit().apply {
            if (updateDefault) {
                putString(WidgetSharedConfig.SNAPSHOT_KEY, encoded)
            }
            putString(snapshotKeyForMosque(snapshot.mosque.id), encoded)
            if (updateDefault) {
                putString(WidgetSharedConfig.APP_SELECTED_MOSQUE_ID_KEY, snapshot.mosque.id)
            }
            apply()
        }
    }

    fun writeMosqueDirectory(mosques: List<WidgetMosqueSnapshot>) {
        prefs.edit()
            .putString(WidgetSharedConfig.MOSQUE_DIRECTORY_KEY, json.encodeToString(mosques))
            .apply()
    }

    private fun snapshotKeyForMosque(mosqueId: String): String =
        WidgetSharedConfig.SNAPSHOT_BY_MOSQUE_PREFIX + mosqueId
}
