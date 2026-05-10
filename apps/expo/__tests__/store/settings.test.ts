import { act } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { useSettingsStore } from "@/store/settings";

jest.mock("@react-native-async-storage/async-storage", () => ({
  setItem: jest.fn(),
  getItem: jest.fn(),
  removeItem: jest.fn(),
}));

describe("SettingsStore", () => {
  beforeEach(() => {
    act(() =>
      useSettingsStore.setState({
        selectedMosqueId: undefined,
        selectedMosqueSlug: undefined,
        uses24HourTime: false,
        appLanguage: "system",
        notifications: {
          masterEnabled: false,
          fajr: true,
          dhuhrJummah: true,
          asr: true,
          maghrib: true,
          isha: true,
        },
      })
    );
    jest.clearAllMocks();
  });

  it("has correct defaults", () => {
    const state = useSettingsStore.getState();
    expect(state.uses24HourTime).toBe(false);
    expect(state.appLanguage).toBe("system");
    expect(state.notifications.masterEnabled).toBe(false);
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

  it("setUses24HourTime updates flag", () => {
    act(() => useSettingsStore.getState().setUses24HourTime(true));
    expect(useSettingsStore.getState().uses24HourTime).toBe(true);
  });

  it("setAppLanguage updates language", () => {
    act(() => useSettingsStore.getState().setAppLanguage("arabic"));
    expect(useSettingsStore.getState().appLanguage).toBe("arabic");
  });

  it("setNotificationMaster toggles master switch", () => {
    act(() => useSettingsStore.getState().setNotificationMaster(true));
    expect(useSettingsStore.getState().notifications.masterEnabled).toBe(true);
  });

  it("setNotificationPrayer toggles individual prayer", () => {
    act(() => useSettingsStore.getState().setNotificationPrayer("asr", false));
    expect(useSettingsStore.getState().notifications.asr).toBe(false);
    expect(useSettingsStore.getState().notifications.fajr).toBe(true);
  });

  it("resetSettings restores defaults", () => {
    act(() => {
      useSettingsStore.getState().setSelectedMosque("1", "a");
      useSettingsStore.getState().setUses24HourTime(true);
      useSettingsStore.getState().setNotificationPrayer("isha", false);
      useSettingsStore.getState().resetSettings();
    });

    const state = useSettingsStore.getState();
    expect(state.selectedMosqueId).toBeUndefined();
    expect(state.uses24HourTime).toBe(false);
    expect(state.notifications.isha).toBe(true);
    expect(state.appLanguage).toBe("system");
  });

  it("persist writes to AsyncStorage", async () => {
    act(() => useSettingsStore.getState().setAppLanguage("urdu"));

    // Allow persist middleware async flush
    await new Promise((r) => setTimeout(r, 50));

    expect(AsyncStorage.setItem).toHaveBeenCalled();
    const calls = (AsyncStorage.setItem as jest.Mock).mock.calls;
    expect(calls[0][0]).toBe("masjidly-settings");
    const stored = JSON.parse(calls[0][1]);
    expect(stored.state.appLanguage).toBe("urdu");
  });
});
