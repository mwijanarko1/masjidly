export type TranslationKey =
  | "prayer.fajr"
  | "prayer.sunrise"
  | "prayer.dhuhr"
  | "prayer.jummah"
  | "prayer.asr"
  | "prayer.maghrib"
  | "prayer.isha"
  | "timetable.header.fajr"
  | "timetable.header.shu"
  | "timetable.header.dhu"
  | "timetable.header.asr"
  | "timetable.header.mag"
  | "timetable.header.ish"
  | "timetable.close_a11y"
  | "home.iqamah_format"
  | "settings.navigation.title"
  | "settings.section.mosque.title"
  | "settings.section.mosque.subtitle"
  | "settings.language.title"
  | "settings.language.picker"
  | "settings.section.display.title"
  | "settings.time.24h.title"
  | "settings.notifications.title"
  | "settings.notifications.master.title"
  | "settings.notification.fajr"
  | "settings.notification.dhuhr_jummah"
  | "settings.notification.asr"
  | "settings.notification.maghrib"
  | "settings.notification.isha"
  | "notification.fajr_adhan"
  | "notification.fajr_iqamah"
  | "notification.dhuhr_adhan"
  | "notification.dhuhr_iqamah"
  | "notification.jummah_adhan"
  | "notification.jummah"
  | "notification.asr_adhan"
  | "notification.asr_iqamah"
  | "notification.maghrib_adhan"
  | "notification.maghrib_iqamah"
  | "notification.isha_adhan"
  | "notification.isha_iqamah"
  | "accessibility.settings"
  | "accessibility.timetable";

type Translations = Record<string, Record<TranslationKey, string>>;

export const translations: Translations = {
  en: {
    "prayer.fajr": "Fajr",
    "prayer.sunrise": "Sunrise",
    "prayer.dhuhr": "Dhuhr",
    "prayer.jummah": "Jummah",
    "prayer.asr": "Asr",
    "prayer.maghrib": "Maghrib",
    "prayer.isha": "Isha",
    "timetable.header.fajr": "Fajr",
    "timetable.header.shu": "Shurooq",
    "timetable.header.dhu": "Dhuhr",
    "timetable.header.asr": "Asr",
    "timetable.header.mag": "Maghrib",
    "timetable.header.ish": "Isha",
    "timetable.close_a11y": "Close timetable",
    "home.iqamah_format": "Iqamah: %s",
    "settings.navigation.title": "Settings",
    "settings.section.mosque.title": "Mosque",
    "settings.section.mosque.subtitle": "Select your local mosque",
    "settings.language.title": "Language",
    "settings.language.picker": "Choose language",
    "settings.section.display.title": "Display",
    "settings.time.24h.title": "24-Hour Time",
    "settings.notifications.title": "Notifications",
    "settings.notifications.master.title": "Enable Notifications",
    "settings.notification.fajr": "Fajr",
    "settings.notification.dhuhr_jummah": "Dhuhr / Jummah",
    "settings.notification.asr": "Asr",
    "settings.notification.maghrib": "Maghrib",
    "settings.notification.isha": "Isha",
    "notification.fajr_adhan": "Fajr Adhan",
    "notification.fajr_iqamah": "Fajr Iqamah",
    "notification.dhuhr_adhan": "Dhuhr Adhan",
    "notification.dhuhr_iqamah": "Dhuhr Iqamah",
    "notification.jummah_adhan": "Jummah Adhan",
    "notification.jummah": "Jummah",
    "notification.asr_adhan": "Asr Adhan",
    "notification.asr_iqamah": "Asr Iqamah",
    "notification.maghrib_adhan": "Maghrib Adhan",
    "notification.maghrib_iqamah": "Maghrib Iqamah",
    "notification.isha_adhan": "Isha Adhan",
    "notification.isha_iqamah": "Isha Iqamah",
    "accessibility.settings": "Settings screen",
    "accessibility.timetable": "Timetable screen",
  },
  ar: {
    "prayer.fajr": "الفجر",
    "prayer.sunrise": "الشروق",
    "prayer.dhuhr": "الظهر",
    "prayer.jummah": "الجمعة",
    "prayer.asr": "العصر",
    "prayer.maghrib": "المغرب",
    "prayer.isha": "العشاء",
    "timetable.header.fajr": "الفجر",
    "timetable.header.shu": "الشروق",
    "timetable.header.dhu": "الظهر",
    "timetable.header.asr": "العصر",
    "timetable.header.mag": "المغرب",
    "timetable.header.ish": "العشاء",
    "timetable.close_a11y": "إغلاق الجدول",
    "home.iqamah_format": "الإقامة: %s",
    "settings.navigation.title": "الإعدادات",
    "settings.section.mosque.title": "المسجد",
    "settings.section.mosque.subtitle": "اختر مسجدك المحلي",
    "settings.language.title": "اللغة",
    "settings.language.picker": "اختر اللغة",
    "settings.section.display.title": "العرض",
    "settings.time.24h.title": "تنسيق 24 ساعة",
    "settings.notifications.title": "الإشعارات",
    "settings.notifications.master.title": "تفعيل الإشعارات",
    "settings.notification.fajr": "الفجر",
    "settings.notification.dhuhr_jummah": "الظهر / الجمعة",
    "settings.notification.asr": "العصر",
    "settings.notification.maghrib": "المغرب",
    "settings.notification.isha": "العشاء",
    "notification.fajr_adhan": "أذان الفجر",
    "notification.fajr_iqamah": "إقامة الفجر",
    "notification.dhuhr_adhan": "أذان الظهر",
    "notification.dhuhr_iqamah": "إقامة الظهر",
    "notification.jummah_adhan": "أذان الجمعة",
    "notification.jummah": "الجمعة",
    "notification.asr_adhan": "أذان العصر",
    "notification.asr_iqamah": "إقامة العصر",
    "notification.maghrib_adhan": "أذان المغرب",
    "notification.maghrib_iqamah": "إقامة المغرب",
    "notification.isha_adhan": "أذان العشاء",
    "notification.isha_iqamah": "إقامة العشاء",
    "accessibility.settings": "شاشة الإعدادات",
    "accessibility.timetable": "شاشة الجدول",
  },
  ur: {
    "prayer.fajr": "فجر",
    "prayer.sunrise": "طلوع آفتاب",
    "prayer.dhuhr": "ظہر",
    "prayer.jummah": "جمعہ",
    "prayer.asr": "عصر",
    "prayer.maghrib": "مغرب",
    "prayer.isha": "عشاء",
    "timetable.header.fajr": "فجر",
    "timetable.header.shu": "طلوع آفتاب",
    "timetable.header.dhu": "ظہر",
    "timetable.header.asr": "عصر",
    "timetable.header.mag": "مغرب",
    "timetable.header.ish": "عشاء",
    "timetable.close_a11y": "ٹیبل بند کریں",
    "home.iqamah_format": "اقامت: %s",
    "settings.navigation.title": "ترتیبات",
    "settings.section.mosque.title": "مسجد",
    "settings.section.mosque.subtitle": "اپنی مقامی مسجد منتخب کریں",
    "settings.language.title": "زبان",
    "settings.language.picker": "زبان منتخب کریں",
    "settings.section.display.title": "ڈسپلے",
    "settings.time.24h.title": "24 گھنٹے کا وقت",
    "settings.notifications.title": "اطلاعات",
    "settings.notifications.master.title": "اطلاعات فعال کریں",
    "settings.notification.fajr": "فجر",
    "settings.notification.dhuhr_jummah": "ظہر / جمعہ",
    "settings.notification.asr": "عصر",
    "settings.notification.maghrib": "مغرب",
    "settings.notification.isha": "عشاء",
    "notification.fajr_adhan": "فجر کی اذان",
    "notification.fajr_iqamah": "فجر کی اقامت",
    "notification.dhuhr_adhan": "ظہر کی اذان",
    "notification.dhuhr_iqamah": "ظہر کی اقامت",
    "notification.jummah_adhan": "جمعہ کی اذان",
    "notification.jummah": "جمعہ",
    "notification.asr_adhan": "عصر کی اذان",
    "notification.asr_iqamah": "عصر کی اقامت",
    "notification.maghrib_adhan": "مغرب کی اذان",
    "notification.maghrib_iqamah": "مغرب کی اقامت",
    "notification.isha_adhan": "عشاء کی اذان",
    "notification.isha_iqamah": "عشاء کی اقامت",
    "accessibility.settings": "ترتیبات کی سکرین",
    "accessibility.timetable": "ٹیبل کی سکرین",
  },
};

/** Look up a translation string. Falls back to English if key or language is missing. */
export function t(key: TranslationKey, langCode: "en" | "ar" | "ur"): string {
  return translations[langCode]?.[key] ?? translations["en"][key];
}
