package com.mikhailspeaks.masjidly.features.updates

import com.mikhailspeaks.masjidly.BuildConfig
import com.mikhailspeaks.masjidly.domain.AppLanguage
import java.util.Locale

/** Mirrors iOS `WhatsNewItem`. */
data class WhatsNewItem(
    val title: String,
    val description: String,
    val icon: WhatsNewIcon,
)

enum class WhatsNewIcon {
    BUG_FIX,
    MAP,
    PALETTE,
    WIDGET,
}

/** Mirrors iOS `WhatsNew.swift`. */
object WhatsNew {
    val currentVersion: String
        get() = BuildConfig.VERSION_NAME.substringBefore("-")

    val currentBuild: String
        get() = BuildConfig.VERSION_CODE.toString()

    val fullVersionString: String
        get() = "$currentVersion ($currentBuild)"

    fun localizedUpdates(language: AppLanguage): List<WhatsNewItem> =
        localizedUpdates(language.resolvedLocale())

    fun localizedUpdates(locale: Locale): List<WhatsNewItem> {
        val code = locale.language.lowercase()
        return when (code) {
            "ar" -> listOf(
                WhatsNewItem(
                    title = "تنبيه المسجد الأقرب",
                    description = "سيخبرك مسجدلي عندما يكون مسجد آخر أقرب إليك، ويمكنك التبديل إليه بنقرة واحدة.",
                    icon = WhatsNewIcon.MAP,
                ),
                WhatsNewItem(
                    title = "اتجاهات إلى أقرب مسجد",
                    description = "افتح إرشادات خطوة بخطوة إلى أقرب مسجد في تطبيق الخرائط المفضل لديك.",
                    icon = WhatsNewIcon.MAP,
                ),
            )
            "ur" -> listOf(
                WhatsNewItem(
                    title = "قریب ترین مسجد کی اطلاع",
                    description = "جب کوئی دوسرا مسجد آپ کے زیادہ قریب ہو تو مسجدلی آپ کو بتائے گا، اور آپ ایک ٹیپ سے اسے منتخب کر سکتے ہیں۔",
                    icon = WhatsNewIcon.MAP,
                ),
                WhatsNewItem(
                    title = "قریب ترین مسجد کا راستہ",
                    description = "اپنی پسندیدہ نقشہ ایپ میں قریب ترین مسجد تک مرحلہ وار راستہ کھولیں۔",
                    icon = WhatsNewIcon.MAP,
                ),
            )
            "id" -> listOf(
                WhatsNewItem(
                    title = "Pemberitahuan masjid terdekat",
                    description = "Masjidly memberi tahu saat masjid lain lebih dekat dan memungkinkan Anda beralih dengan satu ketukan.",
                    icon = WhatsNewIcon.MAP,
                ),
                WhatsNewItem(
                    title = "Petunjuk ke masjid terdekat",
                    description = "Buka petunjuk arah langkah demi langkah ke masjid terdekat di aplikasi peta pilihan Anda.",
                    icon = WhatsNewIcon.MAP,
                ),
            )
            else -> listOf(
                WhatsNewItem(
                    title = "Nearest mosque prompt",
                    description = "Masjidly now lets you know when another mosque is closer and switch with one tap.",
                    icon = WhatsNewIcon.MAP,
                ),
                WhatsNewItem(
                    title = "Directions to your nearest mosque",
                    description = "Open turn-by-turn directions to the closest mosque in your preferred maps app.",
                    icon = WhatsNewIcon.MAP,
                ),
            )
        }
    }
}

/** Mirrors iOS `WhatsNewModalCopy`. */
data class WhatsNewModalCopy(
    val title: String,
    val versionPrefix: String,
    val swipeHint: String,
    val continueLabel: String,
) {
    fun versionLabel(version: String): String = "$versionPrefix $version"

    companion object {
        fun forLanguage(language: AppLanguage): WhatsNewModalCopy =
            forLocale(language.resolvedLocale())

        fun forLocale(locale: Locale): WhatsNewModalCopy {
            val code = locale.language.lowercase()
            return when (code) {
                "ar" -> WhatsNewModalCopy(
                    title = "تحديث مسجدلي!",
                    versionPrefix = "الإصدار",
                    swipeHint = "مرر للمزيد",
                    continueLabel = "متابعة",
                )
                "ur" -> WhatsNewModalCopy(
                    title = "مسجدلی اپ ڈیٹ!",
                    versionPrefix = "ورژن",
                    swipeHint = "مزید کے لیے اسکرول کریں",
                    continueLabel = "جاری رکھیں",
                )
                "id" -> WhatsNewModalCopy(
                    title = "Pembaruan Masjidly!",
                    versionPrefix = "Versi",
                    swipeHint = "Gulir untuk lainnya",
                    continueLabel = "Lanjut",
                )
                else -> WhatsNewModalCopy(
                    title = "Masjidly Update!",
                    versionPrefix = "Version",
                    swipeHint = "Scroll for more",
                    continueLabel = "Continue",
                )
            }
        }
    }
}
