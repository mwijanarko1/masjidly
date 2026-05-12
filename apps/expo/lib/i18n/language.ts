/**
 * Matches iOS: in-app copy uses English only (`SettingsStore.resolvedLocale` → `en`).
 * There is no language picker on iOS Settings.
 */
export function resolvedLanguageCode(): "en" {
  return "en";
}

export function resolvedLocale(): string {
  return "en";
}

export function isResolvedRightToLeft(): boolean {
  return false;
}
