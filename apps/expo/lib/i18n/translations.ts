export type TranslationKey =
  | "prayer.fajr"
  | "prayer.sunrise"
  | "prayer.dhuhr"
  | "prayer.jummah"
  | "prayer.asr"
  | "prayer.maghrib"
  | "prayer.isha"
  | "timetable.header.fajr"
  | "timetable.header.prayer"
  | "timetable.header.adhan"
  | "timetable.header.iqamah"
  | "timetable.header.shu"
  | "timetable.header.dhu"
  | "timetable.header.asr"
  | "timetable.header.mag"
  | "timetable.header.ish"
  | "timetable.close_a11y"
  | "timetable.previous_month_a11y"
  | "timetable.next_month_a11y"
  | "timetable.day_a11y_format"
  | "timetable.load_error"
  | "action.retry"
  | "home.empty.no_mosque_data"
  | "home.iqamah_format"
  | "settings.navigation.title"
  | "settings.section.mosque.title"
  | "settings.mosque.picker"
  | "settings.section.mosque.subtitle"
  | "settings.section.display.title"
  | "settings.time.24h.title"
  | "settings.notifications.title"
  | "settings.notifications.master.title"
  | "settings.notification.fajr"
  | "settings.notification.dhuhr_jummah"
  | "settings.notification.asr"
  | "settings.notification.maghrib"
  | "settings.notification.isha"
  | "notification.channel.adhan"
  | "notification.channel.iqamah"
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
  | "notification.reminder.adhan"
  | "notification.reminder.iqamah"
  | "settings.reminder.none"
  | "settings.reminder.5min"
  | "settings.reminder.10min"
  | "settings.reminder.15min"
  | "settings.reminder.30min"
  | "settings.reminder.before_adhan"
  | "settings.reminder.before_iqamah"
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
    "timetable.header.prayer": "Prayer",
    "timetable.header.adhan": "Adhan",
    "timetable.header.iqamah": "Iqamah",
    "timetable.header.fajr": "Fajr",
    "timetable.header.shu": "Sunrise",
    "timetable.header.dhu": "Dhuhr",
    "timetable.header.asr": "Asr",
    "timetable.header.mag": "Maghrib",
    "timetable.header.ish": "Isha",
    "timetable.close_a11y": "Close timetable",
    "timetable.previous_month_a11y": "Previous month",
    "timetable.next_month_a11y": "Next month",
    "timetable.day_a11y_format": "Day %s",
    "timetable.load_error": "Failed to load timetable",
    "action.retry": "Retry",
    "home.empty.no_mosque_data": "No mosque data available",
    "home.iqamah_format": "Iqamah: %s",
    "settings.navigation.title": "Settings",
    "settings.section.mosque.title": "Mosque",
    "settings.mosque.picker": "Mosque",
    "settings.section.mosque.subtitle": "Select your local mosque",
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
    "notification.channel.adhan": "Adhan",
    "notification.channel.iqamah": "Iqamah",
    "notification.reminder.adhan": "Adhan Reminder",
    "notification.reminder.iqamah": "Iqamah Reminder",
    "settings.reminder.none": "None",
    "settings.reminder.5min": "5 min",
    "settings.reminder.10min": "10 min",
    "settings.reminder.15min": "15 min",
    "settings.reminder.30min": "30 min",
    "settings.reminder.before_adhan": "Before Adhan",
    "settings.reminder.before_iqamah": "Before Iqamah",
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
    "timetable.header.prayer": "الصلاة",
    "timetable.header.adhan": "الأذان",
    "timetable.header.iqamah": "الإقامة",
    "timetable.header.fajr": "الفجر",
    "timetable.header.shu": "الشروق",
    "timetable.header.dhu": "الظهر",
    "timetable.header.asr": "العصر",
    "timetable.header.mag": "المغرب",
    "timetable.header.ish": "العشاء",
    "timetable.close_a11y": "إغلاق جدول المواقيت",
    "timetable.previous_month_a11y": "الشهر السابق",
    "timetable.next_month_a11y": "الشهر التالي",
    "timetable.day_a11y_format": "اليوم %s",
    "timetable.load_error": "فشل تحميل جدول المواقيت",
    "action.retry": "إعادة المحاولة",
    "home.empty.no_mosque_data": "لا توجد بيانات للمسجد",
    "home.iqamah_format": "الإقامة: %s",
    "settings.navigation.title": "الإعدادات",
    "settings.section.mosque.title": "المسجد",
    "settings.mosque.picker": "المسجد",
    "settings.section.mosque.subtitle": "اختر مسجدك المحلي",
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
    "notification.channel.adhan": "الأذان",
    "notification.channel.iqamah": "الإقامة",
    "notification.reminder.adhan": "تذكير الأذان",
    "notification.reminder.iqamah": "تذكير الإقامة",
    "settings.reminder.none": "بدون",
    "settings.reminder.5min": "5 دقائق",
    "settings.reminder.10min": "10 دقائق",
    "settings.reminder.15min": "15 دقيقة",
    "settings.reminder.30min": "30 دقيقة",
    "settings.reminder.before_adhan": "قبل الأذان",
    "settings.reminder.before_iqamah": "قبل الإقامة",
    "accessibility.settings": "شاشة الإعدادات",
    "accessibility.timetable": "جدول المواقيت",
  },
  ur: {
    "prayer.fajr": "فجر",
    "prayer.sunrise": "طلوع آفتاب",
    "prayer.dhuhr": "ظہر",
    "prayer.jummah": "جمعہ",
    "prayer.asr": "عصر",
    "prayer.maghrib": "مغرب",
    "prayer.isha": "عشاء",
    "timetable.header.prayer": "نماز",
    "timetable.header.adhan": "اذان",
    "timetable.header.iqamah": "اقامت",
    "timetable.header.fajr": "فجر",
    "timetable.header.shu": "طلوع آفتاب",
    "timetable.header.dhu": "ظہر",
    "timetable.header.asr": "عصر",
    "timetable.header.mag": "مغرب",
    "timetable.header.ish": "عشاء",
    "timetable.close_a11y": "نظام الاوقات بند کریں",
    "timetable.previous_month_a11y": "پچھلا مہینہ",
    "timetable.next_month_a11y": "اگلا مہینہ",
    "timetable.day_a11y_format": "دن %s",
    "timetable.load_error": "نظام الاوقات لوڈ کرنے میں ناکامی",
    "action.retry": "دوبارہ کوشش کریں",
    "home.empty.no_mosque_data": "مسجد کا ڈیٹا دستیاب نہیں",
    "home.iqamah_format": "اقامت: %s",
    "settings.navigation.title": "ترتیبات",
    "settings.section.mosque.title": "مسجد",
    "settings.mosque.picker": "مسجد",
    "settings.section.mosque.subtitle": "اپنی مقامی مسجد منتخب کریں",
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
    "notification.channel.adhan": "اذان",
    "notification.channel.iqamah": "اقامت",
    "notification.reminder.adhan": "اذان کی یاد دہانی",
    "notification.reminder.iqamah": "اقامت کی یاد دہانی",
    "settings.reminder.none": "کوئی نہیں",
    "settings.reminder.5min": "5 منٹ",
    "settings.reminder.10min": "10 منٹ",
    "settings.reminder.15min": "15 منٹ",
    "settings.reminder.30min": "30 منٹ",
    "settings.reminder.before_adhan": "اذان سے پہلے",
    "settings.reminder.before_iqamah": "اقامت سے پہلے",
    "accessibility.settings": "ترتیبات کی اسکرین",
    "accessibility.timetable": "نظام الاوقات",
  },
};

/**
 * Look up a translation string by key and language code.
 * Falls back to English if the key is missing in the target language.
 * Falls back to the key itself if English also doesn't have it.
 */
export function t(
  key: TranslationKey,
  langCode: "en" | "ar" | "ur"
): string {
  const langDict = translations[langCode];
  if (langDict?.[key]) return langDict[key];
  // Fall back to English
  const englishDict = translations["en"];
  return englishDict?.[key] ?? key;
}
