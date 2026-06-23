package com.mikhailspeaks.masjidly.domain

import java.util.Locale

/** Mirrors iOS `AppLanguage.swift`. */
enum class AppLanguage(val wireValue: String) {
    ENGLISH("english"),
    ARABIC("arabic"),
    URDU("urdu"),
    INDONESIAN("indonesian"),
    ;

    val resolvedLanguageCode: String
        get() = when (this) {
            ENGLISH -> "en"
            ARABIC -> "ar"
            URDU -> "ur"
            INDONESIAN -> "id"
        }

    val isRightToLeft: Boolean
        get() = this == ARABIC || this == URDU

    fun resolvedLocale(): Locale = when (this) {
        ENGLISH -> Locale.forLanguageTag("en")
        ARABIC -> Locale.forLanguageTag("ar")
        URDU -> Locale.forLanguageTag("ur")
        INDONESIAN -> Locale.forLanguageTag("id-ID")
    }

    val displayName: String
        get() = when (this) {
            ENGLISH -> "English"
            ARABIC -> "العربية"
            URDU -> "اردو"
            INDONESIAN -> "Bahasa Indonesia"
        }

    companion object {
        fun fromWire(value: String?): AppLanguage = when (value?.lowercase()) {
            "english", "en" -> ENGLISH
            "arabic", "ar" -> ARABIC
            "urdu", "ur" -> URDU
            "indonesian", "id", "id-id", "id_id" -> INDONESIAN
            else -> ENGLISH
        }
    }
}
