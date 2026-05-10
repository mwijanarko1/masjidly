import {
  resolveLanguage,
  resolvedLanguageCode,
  isResolvedRightToLeft,
  useResolvedLanguage,
  type AppLanguage,
} from "@/lib/i18n/language";

jest.mock("expo-localization", () => {
  let current = "en-US";
  return {
    getLocales: () => [{ languageTag: current, languageCode: current.split("-")[0] }],
    __setLocale: (v: string) => { current = v; },
  };
});

jest.mock("@/store/settings", () => ({
  useSettingsStore: jest.fn(),
}));

import { useSettingsStore } from "@/store/settings";
import * as Localization from "expo-localization";

const setLocale = (Localization as any).__setLocale;

describe("resolveLanguage", () => {
  it("detects english from en locales", () => {
    expect(resolveLanguage("en-US")).toBe("english");
    expect(resolveLanguage("en_GB")).toBe("english");
  });

  it("detects arabic from ar locales", () => {
    expect(resolveLanguage("ar-SA")).toBe("arabic");
    expect(resolveLanguage("ar-EG")).toBe("arabic");
  });

  it("detects urdu from ur locales", () => {
    expect(resolveLanguage("ur-PK")).toBe("urdu");
  });

  it("falls back to english for unknown locales", () => {
    expect(resolveLanguage("fr-FR")).toBe("english");
    expect(resolveLanguage("de-DE")).toBe("english");
  });
});

describe("resolvedLanguageCode", () => {
  it("returns explicit code for non-system languages", () => {
    expect(resolvedLanguageCode("english", "ar-SA")).toBe("en");
    expect(resolvedLanguageCode("arabic", "en-US")).toBe("ar");
    expect(resolvedLanguageCode("urdu", "en-US")).toBe("ur");
  });

  it("resolves system locale", () => {
    expect(resolvedLanguageCode("system", "ur-IN")).toBe("ur");
    expect(resolvedLanguageCode("system", "en-CA")).toBe("en");
    expect(resolvedLanguageCode("system", "ar-AE")).toBe("ar");
  });
});

describe("isResolvedRightToLeft", () => {
  it("returns true for arabic and urdu", () => {
    expect(isResolvedRightToLeft("arabic", "en-US")).toBe(true);
    expect(isResolvedRightToLeft("urdu", "en-US")).toBe(true);
  });

  it("returns true for system arabic locale", () => {
    expect(isResolvedRightToLeft("system", "ar-EG")).toBe(true);
  });

  it("returns false for english", () => {
    expect(isResolvedRightToLeft("english", "ar-SA")).toBe(false);
    expect(isResolvedRightToLeft("system", "en-US")).toBe(false);
  });
});

describe("useResolvedLanguage", () => {
  beforeEach(() => {
    setLocale("en-US");
  });

  it("reads from settings and expo-localization", () => {
    (useSettingsStore as unknown as jest.Mock).mockImplementation(
      (selector: (s: { appLanguage: AppLanguage }) => any) =>
        selector({ appLanguage: "arabic" })
    );

    const result = useResolvedLanguage();
    expect(result.appLanguage).toBe("arabic");
    expect(result.languageCode).toBe("ar");
    expect(result.isRTL).toBe(true);
  });

  it("falls back to system locale when set to system", () => {
    setLocale("ur-PK");
    (useSettingsStore as unknown as jest.Mock).mockImplementation(
      (selector: (s: { appLanguage: AppLanguage }) => any) =>
        selector({ appLanguage: "system" })
    );

    const result = useResolvedLanguage();
    expect(result.languageCode).toBe("ur");
    expect(result.isRTL).toBe(true);
  });
});
