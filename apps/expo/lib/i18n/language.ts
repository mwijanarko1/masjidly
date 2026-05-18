import { useSettingsStore, type AppLanguage } from "@/store/settings";

export type { AppLanguage } from "@/store/settings";

export const APP_LANGUAGES: { code: AppLanguage; label: string; nativeLabel: string }[] = [
  { code: "en", label: "English", nativeLabel: "English" },
  { code: "ar", label: "Arabic", nativeLabel: "العربية" },
  { code: "ur", label: "Urdu", nativeLabel: "اردو" },
  { code: "id", label: "Indonesian", nativeLabel: "Bahasa Indonesia" },
];

export function normalizeAppLanguage(value: unknown): AppLanguage {
  return value === "ar" || value === "ur" || value === "id" || value === "en" ? value : "en";
}

export function useAppLanguage(): AppLanguage {
  return useSettingsStore((state) => state.appLanguage);
}

export function getAppLanguage(): AppLanguage {
  return normalizeAppLanguage(useSettingsStore.getState().appLanguage);
}

export function resolvedLanguageCode(): AppLanguage {
  return getAppLanguage();
}

export function localeForLanguage(language: AppLanguage): string {
  switch (language) {
    case "ar":
      return "ar";
    case "ur":
      return "ur";
    case "id":
      return "id-ID";
    case "en":
    default:
      return "en";
  }
}

export function resolvedLocale(language: AppLanguage = getAppLanguage()): string {
  return localeForLanguage(language);
}

export function isRightToLeftLanguage(language: AppLanguage): boolean {
  return language === "ar" || language === "ur";
}

export function isResolvedRightToLeft(language: AppLanguage = getAppLanguage()): boolean {
  return isRightToLeftLanguage(language);
}

export function getFontScale(language: AppLanguage = getAppLanguage()): number {
  if (language === "ur") return 1.25;
  if (language === "ar") return 1.20;
  return 1.0;
}

