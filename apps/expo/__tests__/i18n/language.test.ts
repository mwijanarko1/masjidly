import { act } from "react";

jest.mock("@react-native-async-storage/async-storage", () => ({
  setItem: jest.fn(),
  getItem: jest.fn(() => Promise.resolve(null)),
  removeItem: jest.fn(),
}));
import { useSettingsStore } from "@/store/settings";
import {
  resolvedLanguageCode,
  resolvedLocale,
  isResolvedRightToLeft,
} from "@/lib/i18n/language";

describe("language resolution", () => {
  beforeEach(() => {
    act(() => useSettingsStore.setState({ appLanguage: "en" }));
  });

  it("defaults to English", () => {
    expect(resolvedLanguageCode()).toBe("en");
    expect(resolvedLocale()).toBe("en");
    expect(isResolvedRightToLeft()).toBe(false);
  });

  it.each([
    ["ar", "ar", true],
    ["ur", "ur", true],
    ["id", "id-ID", false],
  ] as const)("resolves %s locale and direction", (language, locale, rtl) => {
    act(() => useSettingsStore.setState({ appLanguage: language }));
    expect(resolvedLanguageCode()).toBe(language);
    expect(resolvedLocale()).toBe(locale);
    expect(isResolvedRightToLeft()).toBe(rtl);
  });
});
