import {
  resolvedLanguageCode,
  resolvedLocale,
  isResolvedRightToLeft,
} from "@/lib/i18n/language";

describe("resolvedLanguageCode", () => {
  it("is always English (iOS parity)", () => {
    expect(resolvedLanguageCode()).toBe("en");
  });
});

describe("resolvedLocale", () => {
  it("matches iOS SettingsStore.resolvedLocale", () => {
    expect(resolvedLocale()).toBe("en");
  });
});

describe("isResolvedRightToLeft", () => {
  it("is always false", () => {
    expect(isResolvedRightToLeft()).toBe(false);
  });
});
