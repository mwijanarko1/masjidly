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

const iqamahParityItems: Record<AppLanguage, WhatsNewItem> = {
  en: {
    title: "Bug Fix: Timetable Iqamah",
    description:
      "Fixed a bug where the timetable showed incorrect Isha iqamah times for some mosques. Home, timetable, and widgets now use the same iqamah logic.",
    icon: "countdown",
  },
  ar: {
    title: "إصلاح: إقامة جدول المواعيد",
    description:
      "تم إصلاح خطأ حيث كان جدول المواعيد يعرض أوقات إقامة العشاء بشكل غير صحيح لبعض المساجد. الآن الشاشة الرئيسية وجدول المواعيد والودجت تستخدم نفس المنطق.",
    icon: "countdown",
  },
  ur: {
    title: "بگ فکس: ٹائم ٹیبل اقامت",
    description:
      "ایک بگ درست کیا گیا جہاں ٹائم ٹیبل بعض مساجد کے لیے عشاء کی غلط اقامت دکھا رہا تھا۔ اب ہوم، ٹائم ٹیبل اور وجٹس ایک ہی اقامت کا منطق استعمال کرتے ہیں۔",
    icon: "countdown",
  },
  id: {
    title: "Perbaikan: Iqamah Jadwal",
    description:
      "Memperbaiki bug di jadwal yang menampilkan iqamah Isya yang salah untuk beberapa masjid. Layar utama, jadwal, dan widget kini menggunakan logika iqamah yang sama.",
    icon: "countdown",
  },
};

const copies: Record<AppLanguage, WhatsNewCopy> = {
  en: {
    title: "Masjidly Update!",
    versionLabel: "Version %s",
    swipeHint: "Swipe to scroll updates",
    continueLabel: "Continue",
    items: [iqamahParityItems.en],
  },
  ar: {
    title: "تحديث مسجدلي!",
    versionLabel: "الإصدار %s",
    swipeHint: "اسحب لقراءة التحديثات",
    continueLabel: "متابعة",
    items: [iqamahParityItems.ar],
  },
  ur: {
    title: "مسجدلی اپ ڈیٹ!",
    versionLabel: "ورژن %s",
    swipeHint: "اپ ڈیٹس دیکھنے کے لیے سوائپ کریں",
    continueLabel: "جاری رکھیں",
    items: [iqamahParityItems.ur],
  },
  id: {
    title: "Pembaruan Masjidly!",
    versionLabel: "Versi %s",
    swipeHint: "Geser untuk melihat pembaruan",
    continueLabel: "Lanjut",
    items: [iqamahParityItems.id],
  },
};

export function whatsNewCopy(language: AppLanguage): WhatsNewCopy {
  return copies[language] ?? copies.en;
}
