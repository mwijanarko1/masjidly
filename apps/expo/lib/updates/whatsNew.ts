import Constants from "expo-constants";
import type { AppLanguage } from "@/store/settings";

export interface WhatsNewItem {
  title: string;
  description: string;
  icon: "globe" | "rtl" | "theme" | "countdown";
}

export interface WhatsNewCopy {
  title: string;
  versionLabel: string;
  swipeHint: string;
  continueLabel: string;
  items: WhatsNewItem[];
}

function expoVersion(): string {
  return (
    Constants.expoConfig?.version ??
    Constants.manifest2?.extra?.expoClient?.version ??
    Constants.nativeApplicationVersion ??
    "1.0.0"
  );
}

function expoBuild(): string {
  const nativeBuild = Constants.nativeBuildVersion;
  const androidVersionCode = Constants.expoConfig?.android?.versionCode;
  return nativeBuild ?? (androidVersionCode ? String(androidVersionCode) : "1");
}

export function currentMasjidlyVersion(): string {
  return expoVersion();
}

export function currentMasjidlyFullVersion(): string {
  return `${expoVersion()} (${expoBuild()})`;
}

const countryPickerItems: Record<AppLanguage, WhatsNewItem> = {
  en: {
    title: "Choose Country, City & Mosque",
    description:
      "We’re expanding internationally. Choose your country, city, and mosque.",
    icon: "globe",
  },
  ar: {
    title: "اختر البلد والمدينة والمسجد",
    description:
      "نتوسع عالميًا. اختر بلدك ثم مدينتك ومسجدك.",
    icon: "globe",
  },
  ur: {
    title: "ملک، شہر اور مسجد چنیں",
    description:
      "ہم دنیا بھر میں پھیل رہے ہیں۔ اپنا ملک، شہر اور مسجد چنیں.",
    icon: "globe",
  },
  id: {
    title: "Pilih Negara, Kota & Masjid",
    description:
      "Kami berkembang secara internasional. Pilih negara, kota, dan masjid Anda.",
    icon: "globe",
  },
};

const languageOnboardingItems: Record<AppLanguage, WhatsNewItem> = {
  en: {
    title: "Choose Your Language",
    description:
      "Pick your language when you set up the app.",
    icon: "rtl",
  },
  ar: {
    title: "اختر لغتك",
    description:
      "اختر لغتك عند إعداد التطبيق.",
    icon: "rtl",
  },
  ur: {
    title: "اپنی زبان چنیں",
    description:
      "ایپ سیٹ کرتے وقت اپنی زبان چنیں۔",
    icon: "rtl",
  },
  id: {
    title: "Pilih Bahasa Anda",
    description:
      "Pilih bahasa saat menyiapkan aplikasi.",
    icon: "rtl",
  },
};

const asrPreferenceItems: Record<AppLanguage, WhatsNewItem> = {
  en: {
    title: "Asr Adhan Choice",
    description:
      "If your mosque has two Asr adhans, choose First Asr or Second Asr in Settings.",
    icon: "theme",
  },
  ar: {
    title: "اختيار أذان العصر",
    description:
      "إذا كان لمسجدك أذانان للعصر، اختر العصر الأول أو الثاني من الإعدادات.",
    icon: "theme",
  },
  ur: {
    title: "عصر اذان کا انتخاب",
    description:
      "اگر مسجد میں عصر کی دو اذانیں ہیں، ترتیبات میں پہلی یا دوسری عصر چنیں۔",
    icon: "theme",
  },
  id: {
    title: "Pilihan Adhan Asar",
    description:
      "Jika masjid punya dua adhan Asar, pilih Asar Pertama atau Kedua di Pengaturan.",
    icon: "theme",
  },
};

const multiJummahItems: Record<AppLanguage, WhatsNewItem> = {
  en: {
    title: "More Jummah Times",
    description:
      "Jummah 1 and Jummah 2 now show clearly when available.",
    icon: "countdown",
  },
  ar: {
    title: "أوقات جمعة أكثر",
    description:
      "تظهر جمعة 1 وجمعة 2 بوضوح عند توفرهما.",
    icon: "countdown",
  },
  ur: {
    title: "مزید جمعہ اوقات",
    description:
      "جمعہ 1 اور جمعہ 2 دستیاب ہوں تو صاف دکھتے ہیں۔",
    icon: "countdown",
  },
  id: {
    title: "Lebih Banyak Waktu Jumat",
    description:
      "Jumat 1 dan Jumat 2 kini tampil jelas jika tersedia.",
    icon: "countdown",
  },
};

const closestMosqueItems: Record<AppLanguage, WhatsNewItem> = {
  en: {
    title: "Nearest Mosque",
    description:
      "Find the closest mosque to you in Settings.",
    icon: "globe",
  },
  ar: {
    title: "أقرب مسجد",
    description:
      "اعثر على أقرب مسجد إليك من الإعدادات.",
    icon: "globe",
  },
  ur: {
    title: "قریب ترین مسجد",
    description:
      "ترتیبات میں اپنے قریب ترین مسجد دیکھیں۔",
    icon: "globe",
  },
  id: {
    title: "Masjid Terdekat",
    description:
      "Temukan masjid terdekat di Pengaturan.",
    icon: "globe",
  },
};

const copies: Record<AppLanguage, WhatsNewCopy> = {
  en: {
    title: "Masjidly Update!",
    versionLabel: "Version %s",
    swipeHint: "Scroll for more",
    continueLabel: "Continue",
    items: [
      countryPickerItems.en,
      languageOnboardingItems.en,
      asrPreferenceItems.en,
      multiJummahItems.en,
      closestMosqueItems.en,
    ],
  },
  ar: {
    title: "تحديث مسجدلي!",
    versionLabel: "الإصدار %s",
    swipeHint: "مرر للمزيد",
    continueLabel: "متابعة",
    items: [
      countryPickerItems.ar,
      languageOnboardingItems.ar,
      asrPreferenceItems.ar,
      multiJummahItems.ar,
      closestMosqueItems.ar,
    ],
  },
  ur: {
    title: "مسجدلی اپ ڈیٹ!",
    versionLabel: "ورژن %s",
    swipeHint: "مزید کے لیے اسکرول کریں",
    continueLabel: "جاری رکھیں",
    items: [
      countryPickerItems.ur,
      languageOnboardingItems.ur,
      asrPreferenceItems.ur,
      multiJummahItems.ur,
      closestMosqueItems.ur,
    ],
  },
  id: {
    title: "Pembaruan Masjidly!",
    versionLabel: "Versi %s",
    swipeHint: "Gulir untuk lainnya",
    continueLabel: "Lanjut",
    items: [
      countryPickerItems.id,
      languageOnboardingItems.id,
      asrPreferenceItems.id,
      multiJummahItems.id,
      closestMosqueItems.id,
    ],
  },
};

export function whatsNewCopy(language: AppLanguage): WhatsNewCopy {
  return copies[language] ?? copies.en;
}
