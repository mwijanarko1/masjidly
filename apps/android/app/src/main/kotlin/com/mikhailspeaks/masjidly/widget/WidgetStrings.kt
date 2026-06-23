package com.mikhailspeaks.masjidly.widget

import com.mikhailspeaks.masjidly.domain.AppLanguage

object WidgetStrings {
    fun prayer(language: AppLanguage): String = when (language) {
        AppLanguage.ARABIC -> "الصلاة"
        AppLanguage.URDU -> "نماز"
        AppLanguage.INDONESIAN -> "Salat"
        AppLanguage.ENGLISH -> "Prayer"
    }

    fun adhan(language: AppLanguage): String = when (language) {
        AppLanguage.ARABIC -> "الأذان"
        AppLanguage.URDU -> "اذان"
        AppLanguage.INDONESIAN -> "Azan"
        AppLanguage.ENGLISH -> "Adhan"
    }

    fun iqamah(language: AppLanguage): String = when (language) {
        AppLanguage.ARABIC -> "الإقامة"
        AppLanguage.URDU -> "اقامت"
        AppLanguage.INDONESIAN -> "Iqamah"
        AppLanguage.ENGLISH -> "Iqamah"
    }

    fun iqamahFormat(language: AppLanguage, time: String): String = when (language) {
        AppLanguage.ARABIC -> "الإقامة $time"
        AppLanguage.URDU -> "اقامت $time"
        AppLanguage.INDONESIAN -> "Iqamah $time"
        AppLanguage.ENGLISH -> "Iqamah $time"
    }

    fun unavailable(language: AppLanguage): String = when (language) {
        AppLanguage.ARABIC -> "أوقات الصلاة غير متوفرة"
        AppLanguage.URDU -> "نماز کے اوقات دستیاب نہیں ہیں"
        AppLanguage.INDONESIAN -> "Jadwal sholat tidak tersedia"
        AppLanguage.ENGLISH -> "Prayer times unavailable"
    }

    fun openApp(language: AppLanguage): String = when (language) {
        AppLanguage.ARABIC -> "افتح التطبيق للتحديث"
        AppLanguage.URDU -> "اپ ڈیٹ کرنے کے لیے ایپ کھولیں"
        AppLanguage.INDONESIAN -> "Buka aplikasi untuk memperbarui"
        AppLanguage.ENGLISH -> "Open app to update"
    }

    fun next(language: AppLanguage): String = when (language) {
        AppLanguage.ARABIC -> "التالي"
        AppLanguage.URDU -> "اگلی"
        AppLanguage.INDONESIAN -> "Berikutnya"
        AppLanguage.ENGLISH -> "Next"
    }

    fun today(language: AppLanguage): String = when (language) {
        AppLanguage.ARABIC -> "اليوم"
        AppLanguage.URDU -> "آج"
        AppLanguage.INDONESIAN -> "Hari ini"
        AppLanguage.ENGLISH -> "Today"
    }
}
