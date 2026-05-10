import { useSettingsStore } from "@/store/settings";
import { getLocales } from "expo-localization";

export type AppLanguage = "system" | "english" | "arabic" | "urdu";

/** Resolve a system locale string to an AppLanguage. */
export function resolveLanguage(systemLocale: string): AppLanguage {
  const locale = systemLocale.toLowerCase();
  if (locale.startsWith("en")) return "english";
  if (locale.startsWith("ar")) return "arabic";
  if (locale.startsWith("ur")) return "urdu";
  return "english";
}

/** Return the 2-letter language code for the resolved language. */
export function resolvedLanguageCode(
  lang: AppLanguage,
  systemLocale: string
): "en" | "ar" | "ur" {
  if (lang === "system") {
    return resolvedLanguageCode(resolveLanguage(systemLocale), systemLocale);
  }
  switch (lang) {
    case "english":
      return "en";
    case "arabic":
      return "ar";
    case "urdu":
      return "ur";
  }
}

/** Whether the resolved language reads right-to-left. */
export function isResolvedRightToLeft(
  lang: AppLanguage,
  systemLocale: string
): boolean {
  const code = resolvedLanguageCode(lang, systemLocale);
  return code === "ar" || code === "ur";
}

/** Hook that returns the resolved language settings from the store and device locale. */
export function useResolvedLanguage(): {
  appLanguage: AppLanguage;
  languageCode: "en" | "ar" | "ur";
  isRTL: boolean;
} {
  const appLanguage = useSettingsStore((s) => s.appLanguage);
  const systemLocale = getLocales()[0].languageTag;
  const languageCode = resolvedLanguageCode(appLanguage, systemLocale);
  const isRTL = isResolvedRightToLeft(appLanguage, systemLocale);
  return { appLanguage, languageCode, isRTL };
}
