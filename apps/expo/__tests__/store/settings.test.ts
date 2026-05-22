/**
 * @jest-environment node
 */

import { act } from "react";
import { useSettingsStore } from "@/store/settings";

if (typeof globalThis.window === "undefined") {
  (globalThis as any).window = {} as Window;
}
if (typeof globalThis.window.localStorage === "undefined") {
  const store: Record<string, string> = {};
  (globalThis.window as any).localStorage = {
    getItem: (key: string) => store[key] ?? null,
    setItem: (key: string, value: string) => { store[key] = value; },
    removeItem: (key: string) => { delete store[key]; },
    clear: () => { Object.keys(store).forEach((k) => delete store[k]); },
    length: 0,
    key: () => null,
  };
}

jest.mock("@react-native-async-storage/async-storage", () => ({
  setItem: jest.fn(),
  getItem: jest.fn(() => Promise.resolve(null)),
  removeItem: jest.fn(),
}));

const defaultState = {
  selectedMosqueId: undefined,
  selectedMosqueSlug: undefined,
  selectedCityGroupingKey: undefined,
  uses24HourTime: false,
  hideQiblaCompass: false,
  hasCompletedOnboarding: false,
  appLanguage: "en" as const,
  themeMode: "dynamic" as const,
  fixedTheme: "fajr" as const,
  notifications: {
    masterEnabled: false,
    adhanEnabled: true,
    iqamahEnabled: true,
    preAdhanReminderMinutes: null as number | null,
    preIqamahReminderMinutes: null as number | null,
    fajr: true,
    dhuhrJummah: true,
    asr: true,
    maghrib: true,
    isha: true,
  },
};

describe("SettingsStore", () => {
  beforeEach(() => {
    act(() => useSettingsStore.setState(defaultState));
    jest.clearAllMocks();
  });

  it("has correct defaults", () => {
    const state = useSettingsStore.getState();
    expect(state.uses24HourTime).toBe(false);
    expect(state.hasCompletedOnboarding).toBe(false);
    expect(state.appLanguage).toBe("en");
    expect(state.themeMode).toBe("dynamic");
    expect(state.fixedTheme).toBe("fajr");
    expect(state.notifications.masterEnabled).toBe(false);
    expect(state.notifications.adhanEnabled).toBe(true);
    expect(state.notifications.iqamahEnabled).toBe(true);
    expect(state.notifications.preAdhanReminderMinutes).toBeNull();
    expect(state.notifications.preIqamahReminderMinutes).toBeNull();
    expect(state.notifications.fajr).toBe(true);
    expect(state.notifications.dhuhrJummah).toBe(true);
    expect(state.notifications.asr).toBe(true);
    expect(state.notifications.maghrib).toBe(true);
    expect(state.notifications.isha).toBe(true);
  });

  it("setSelectedMosque updates id and slug", () => {
    act(() => useSettingsStore.getState().setSelectedMosque("1", "mosque-a"));
    const state = useSettingsStore.getState();
    expect(state.selectedMosqueId).toBe("1");
    expect(state.selectedMosqueSlug).toBe("mosque-a");
  });

  it("setSelectedMosque with city key updates grouping", () => {
    act(() =>
      useSettingsStore.getState().setSelectedMosque("1", "mosque-a", "slug:leeds")
    );
    const state = useSettingsStore.getState();
    expect(state.selectedCityGroupingKey).toBe("slug:leeds");
  });

  it("setSelectedCityGroupingKey updates city filter", () => {
    act(() => useSettingsStore.getState().setSelectedCityGroupingKey("slug:bradford"));
    expect(useSettingsStore.getState().selectedCityGroupingKey).toBe("slug:bradford");
  });

  it("setUses24HourTime updates flag", () => {
    act(() => useSettingsStore.getState().setUses24HourTime(true));
    expect(useSettingsStore.getState().uses24HourTime).toBe(true);
  });

  it("setHasCompletedOnboarding updates flag", () => {
    act(() => useSettingsStore.getState().setHasCompletedOnboarding(true));
    expect(useSettingsStore.getState().hasCompletedOnboarding).toBe(true);
  });

  it("setAppLanguage updates language", () => {
    act(() => useSettingsStore.getState().setAppLanguage("id"));
    expect(useSettingsStore.getState().appLanguage).toBe("id");
  });

  it("sets theme preferences", () => {
    act(() => {
      useSettingsStore.getState().setThemeMode("fixed");
      useSettingsStore.getState().setFixedTheme("maghrib");
    });
    expect(useSettingsStore.getState().themeMode).toBe("fixed");
    expect(useSettingsStore.getState().fixedTheme).toBe("maghrib");
  });

  it("normalizes unsupported fixed themes back to Fajr", () => {
    act(() => useSettingsStore.getState().setFixedTheme("tahajjud"));
    expect(useSettingsStore.getState().fixedTheme).toBe("fajr");
  });

  it("setNotificationMaster toggles master switch", () => {
    act(() => useSettingsStore.getState().setNotificationMaster(true));
    expect(useSettingsStore.getState().notifications.masterEnabled).toBe(true);

    act(() => useSettingsStore.getState().setNotificationMaster(false));
    expect(useSettingsStore.getState().notifications.masterEnabled).toBe(false);
  });

  it("setAdhanEnabled toggles adhan channel", () => {
    act(() => useSettingsStore.getState().setAdhanEnabled(false));
    expect(useSettingsStore.getState().notifications.adhanEnabled).toBe(false);

    act(() => useSettingsStore.getState().setAdhanEnabled(true));
    expect(useSettingsStore.getState().notifications.adhanEnabled).toBe(true);
  });

  it("setIqamahEnabled toggles iqamah channel", () => {
    act(() => useSettingsStore.getState().setIqamahEnabled(false));
    expect(useSettingsStore.getState().notifications.iqamahEnabled).toBe(false);

    act(() => useSettingsStore.getState().setIqamahEnabled(true));
    expect(useSettingsStore.getState().notifications.iqamahEnabled).toBe(true);
  });

  it("setPreAdhanReminderMinutes sets reminder value", () => {
    act(() => useSettingsStore.getState().setPreAdhanReminderMinutes(10));
    expect(useSettingsStore.getState().notifications.preAdhanReminderMinutes).toBe(10);

    act(() => useSettingsStore.getState().setPreAdhanReminderMinutes(null));
    expect(useSettingsStore.getState().notifications.preAdhanReminderMinutes).toBeNull();
  });

  it("setPreIqamahReminderMinutes sets reminder value", () => {
    act(() => useSettingsStore.getState().setPreIqamahReminderMinutes(15));
    expect(useSettingsStore.getState().notifications.preIqamahReminderMinutes).toBe(15);

    act(() => useSettingsStore.getState().setPreIqamahReminderMinutes(null));
    expect(useSettingsStore.getState().notifications.preIqamahReminderMinutes).toBeNull();
  });

  it("setNotificationPrayer toggles individual prayers", () => {
    act(() => useSettingsStore.getState().setNotificationPrayer("fajr", false));
    expect(useSettingsStore.getState().notifications.fajr).toBe(false);

    act(() => useSettingsStore.getState().setNotificationPrayer("dhuhrJummah", false));
    expect(useSettingsStore.getState().notifications.dhuhrJummah).toBe(false);

    act(() => useSettingsStore.getState().setNotificationPrayer("isha", false));
    expect(useSettingsStore.getState().notifications.isha).toBe(false);
  });

  it("setNotificationPrayer does not affect masterEnabled", () => {
    act(() => {
      useSettingsStore.getState().setNotificationMaster(true);
      useSettingsStore.getState().setNotificationPrayer("fajr", false);
    });
    const state = useSettingsStore.getState();
    expect(state.notifications.masterEnabled).toBe(true);
    expect(state.notifications.fajr).toBe(false);
  });

  it("resetSettings restores defaults", () => {
    act(() => {
      useSettingsStore.getState().setSelectedMosque("1", "a");
      useSettingsStore.getState().setUses24HourTime(true);
      useSettingsStore.getState().setNotificationMaster(true);
      useSettingsStore.getState().setNotificationPrayer("fajr", false);
      useSettingsStore.getState().setAdhanEnabled(false);
      useSettingsStore.getState().setPreAdhanReminderMinutes(10);
      useSettingsStore.getState().setHasCompletedOnboarding(true);
      useSettingsStore.getState().setAppLanguage("ar");
      useSettingsStore.getState().setThemeMode("fixed");
      useSettingsStore.getState().setFixedTheme("asr");
      useSettingsStore.getState().resetSettings();
    });

    const state = useSettingsStore.getState();
    expect(state.selectedMosqueId).toBeUndefined();
    expect(state.selectedCityGroupingKey).toBeUndefined();
    expect(state.uses24HourTime).toBe(false);
    expect(state.notifications.masterEnabled).toBe(false);
    expect(state.notifications.fajr).toBe(true);
    expect(state.notifications.adhanEnabled).toBe(true);
    expect(state.notifications.preAdhanReminderMinutes).toBeNull();
    expect(state.hasCompletedOnboarding).toBe(false);
    expect(state.appLanguage).toBe("en");
    expect(state.themeMode).toBe("dynamic");
    expect(state.fixedTheme).toBe("fajr");
  });
});