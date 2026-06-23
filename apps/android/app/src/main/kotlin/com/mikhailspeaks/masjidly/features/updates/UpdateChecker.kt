package com.mikhailspeaks.masjidly.features.updates

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.mikhailspeaks.masjidly.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

// MARK: - Release Manifest Models (mirrors iOS AppUpdateChecker.swift)

@Serializable
data class MasjidlyRelease(
    val android: AndroidRelease,
    val ios: IOSRelease,
    @SerialName("pub_date") val pubDate: String,
    val notes: LocalizedNotes,
) {
    companion object {
        val testRelease: MasjidlyRelease
            get() = MasjidlyRelease(
                android = AndroidRelease(
                    version = "9.9.9",
                    versionCode = 999,
                    url = "https://www.sheffieldmasjids.com/masjidly/Masjidly-1.1.2.apk",
                    sha256 = "",
                    minVersionCode = 1,
                ),
                ios = IOSRelease(
                    version = "9.9.9",
                    build = 999,
                    appStoreUrl = "https://apps.apple.com/gb/app/masjidly-masjid-prayer-times/id6767841833",
                ),
                pubDate = Instant.now().toString(),
                notes = LocalizedNotes(
                    en = "This is a test notification confirming the update prompt works. No update is actually available.",
                    ar = "هذا إشعار اختبار لتأكيد عمل تنبيه التحديث. لا يوجد تحديث فعلي متاح.",
                    ur = "یہ ایک ٹیسٹ نوٹیفکیشن ہے جو اس بات کی تصدیق کرتا ہے کہ اپ ڈیٹ پرامپٹ کام کر رہا ہے۔ کوئی حقیقی اپ ڈیٹ دستیاب نہیں ہے۔",
                    id = "Ini adalah notifikasi tes yang mengonfirmasi bahwa prompt pembaruan berfungsi. Tidak ada pembaruan yang tersedia.",
                ),
            )
    }
}

@Serializable
data class AndroidRelease(
    val version: String,
    val versionCode: Int,
    val url: String,
    val sha256: String,
    val minVersionCode: Int,
)

@Serializable
data class IOSRelease(
    val version: String,
    val build: Int,
    val appStoreUrl: String,
)

@Serializable
data class LocalizedNotes(
    val en: String,
    val ar: String,
    val ur: String,
    val id: String,
)

sealed class AppUpdateStatus {
    data object UpToDate : AppUpdateStatus()
    data class UpdateAvailable(val release: MasjidlyRelease) : AppUpdateStatus()
    data class CheckFailed(val message: String) : AppUpdateStatus()
}

/**
 * Checks `latest.json` from the website — Android compares [versionCode] like Expo;
 * localized update UI mirrors iOS `HomeView` / `MasjidlyRootView`.
 */
object UpdateChecker {
    const val latestJsonUrl = "https://www.sheffieldmasjids.com/masjidly/latest.json"
    private const val timeoutMs = 10_000

    private val json = Json { ignoreUnknownKeys = true }

    val currentVersionCode: Int
        get() = BuildConfig.VERSION_CODE

    suspend fun fetchLatestRelease(): MasjidlyRelease? = withContext(Dispatchers.IO) {
        runCatching {
            val connection = (URL(latestJsonUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                setRequestProperty("Accept", "application/json")
                requestMethod = "GET"
            }
            try {
                if (connection.responseCode != HttpURLConnection.HTTP_OK) return@runCatching null
                val body = connection.inputStream.bufferedReader().readText()
                json.decodeFromString<MasjidlyRelease>(body)
            } finally {
                connection.disconnect()
            }
        }.getOrNull()
    }

    suspend fun checkForUpdate(): AppUpdateStatus {
        val release = fetchLatestRelease()
            ?: return AppUpdateStatus.CheckFailed("Could not reach version server.")

        return if (release.android.versionCode > currentVersionCode) {
            AppUpdateStatus.UpdateAvailable(release)
        } else {
            AppUpdateStatus.UpToDate
        }
    }

    fun openUpdateUrl(context: Context, release: MasjidlyRelease) {
        val url = release.android.url
        if (url.isBlank()) return
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        context.startActivity(Intent.createChooser(intent, null))
    }
}
