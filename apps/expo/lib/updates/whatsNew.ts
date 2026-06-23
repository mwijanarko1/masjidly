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

const releaseVersion = "1.2.2";
const releaseBuild = "7";

function expoVersion(): string {
  return (
    Constants.expoConfig?.version ??
    Constants.manifest2?.extra?.expoClient?.version ??
    releaseVersion
  );
}

function expoBuild(): string {
  const androidVersionCode = Constants.expoConfig?.android?.versionCode;
  return androidVersionCode ? String(androidVersionCode) : Constants.nativeBuildVersion ?? releaseBuild;
}

export function currentMasjidlyVersion(): string {
  return expoVersion();
}

export function currentMasjidlyFullVersion(): string {
  return `${expoVersion()} (${expoBuild()})`;
}

const bugFixItems: Record<AppLanguage, WhatsNewItem> = {
  en: {
    title: "Bug Fixes",
    description: "This update includes bug fixes and stability improvements.",
    icon: "theme",
  },
  ar: {
    title: "إصلاحات الأخطاء",
    description: "يتضمن هذا التحديث إصلاحات للأخطاء وتحسينات في الاستقرار.",
    icon: "theme",
  },
  ur: {
    title: "بگ فکسز",
    description: "اس اپ ڈیٹ میں بگ فکسز اور استحکام کی بہتری شامل ہے۔",
    icon: "theme",
  },
  id: {
    title: "Perbaikan Bug",
    description: "Pembaruan ini berisi perbaikan bug dan peningkatan stabilitas.",
    icon: "theme",
  },
};

const copies: Record<AppLanguage, WhatsNewCopy> = {
  en: {
    title: "Masjidly Update!",
    versionLabel: "Version %s",
    swipeHint: "Scroll for more",
    continueLabel: "Continue",
    items: [bugFixItems.en],
  },
  ar: {
    title: "تحديث مسجدلي!",
    versionLabel: "الإصدار %s",
    swipeHint: "مرر للمزيد",
    continueLabel: "متابعة",
    items: [bugFixItems.ar],
  },
  ur: {
    title: "مسجدلی اپ ڈیٹ!",
    versionLabel: "ورژن %s",
    swipeHint: "مزید کے لیے اسکرول کریں",
    continueLabel: "جاری رکھیں",
    items: [bugFixItems.ur],
  },
  id: {
    title: "Pembaruan Masjidly!",
    versionLabel: "Versi %s",
    swipeHint: "Gulir untuk lainnya",
    continueLabel: "Lanjut",
    items: [bugFixItems.id],
  },
};

export function whatsNewCopy(language: AppLanguage): WhatsNewCopy {
  return copies[language] ?? copies.en;
}
