import React from "react";
import { render, screen, fireEvent, waitFor } from "@testing-library/react-native";
import { SettingsScreen } from "@/app/settings.tsx";

const mockBack = jest.fn();

jest.mock("expo-router", () => ({
  useRouter: () => ({ back: mockBack }),
  useLocalSearchParams: () => ({}),
}));

jest.mock("react-native-safe-area-context", () => ({
  SafeAreaView: ({ children }: any) => children,
}));

jest.mock("@/lib/prayer/prayerRepository", () => ({
  prayerRepository: {
    listMosques: jest.fn(),
  },
}));

const mockSetSelectedMosque = jest.fn();
const mockSetUses24HourTime = jest.fn();
const mockSetNotificationMaster = jest.fn();
const mockSetHideQiblaCompass = jest.fn();

jest.mock("@/store/settings", () => {
  const makeState = () => ({
    selectedMosqueId: "1",
    selectedMosqueSlug: "mosque-a",
    uses24HourTime: false,
    hideQiblaCompass: false,
    hasCompletedOnboarding: true,
    appLanguage: "en",
    themeMode: "dynamic",
    fixedTheme: "fajr",
    notifications: {
      masterEnabled: false,
      adhanEnabled: true,
      iqamahEnabled: true,
      preAdhanReminderMinutes: null,
      preIqamahReminderMinutes: null,
      fajr: true,
      dhuhrJummah: true,
      asr: true,
      maghrib: true,
      isha: true,
    },
    setSelectedMosque: mockSetSelectedMosque,
    setUses24HourTime: mockSetUses24HourTime,
    setHideQiblaCompass: mockSetHideQiblaCompass,
    setHasCompletedOnboarding: jest.fn(),
    setAppLanguage: jest.fn(),
    setThemeMode: jest.fn(),
    setFixedTheme: jest.fn(),
    setSelectedCityGroupingKey: jest.fn(),
    setNotificationMaster: mockSetNotificationMaster,
    setAdhanEnabled: jest.fn(),
    setIqamahEnabled: jest.fn(),
    setPreAdhanReminderMinutes: jest.fn(),
    setPreIqamahReminderMinutes: jest.fn(),
    setNotificationPrayer: jest.fn(),
    resetSettings: jest.fn(),
  });
  const useSettingsStore = jest.fn((selector?: any) => {
    const state = makeState();
    if (typeof selector === "function") return selector(state);
    return state;
  });
  useSettingsStore.getState = () => makeState();
  return { useSettingsStore };
});

jest.mock("expo-linear-gradient", () => {
  const React = require("react");
  const { View } = require("react-native");
  return { LinearGradient: (props: any) => React.createElement(View, null, props.children) };
});

jest.mock("lucide-react-native", () => ({
  X: () => null,
  Check: () => null,
  ChevronDown: () => null,
}));

jest.mock("@/components/ui/AtmosphericSkyBackground", () => ({
  AtmosphericSkyBackground: () => null,
}));

jest.mock("@/lib/notifications/expoNotificationApi", () => ({
  scheduleNotificationAsync: jest.fn(),
  SchedulableTriggerInputTypes: { TIME_INTERVAL: "timeInterval", DATE: "date" },
  getPermissionsAsync: jest.fn().mockResolvedValue({ status: "granted" }),
  requestPermissionsAsync: jest.fn().mockResolvedValue({ status: "granted" }),
  cancelScheduledNotificationAsync: jest.fn(),
  getAllScheduledNotificationsAsync: jest.fn().mockResolvedValue([]),
}));

jest.mock("@/lib/notifications/prayerNotifications", () => ({
  cancelAllPrayerNotifications: jest.fn(),
  rescheduleUpcomingPrayerNotifications: jest.fn(),
  requestNotificationAuthorizationIfNeeded: jest.fn().mockResolvedValue(true),
}));

import { prayerRepository } from "@/lib/prayer/prayerRepository";

const mockedListMosques = prayerRepository.listMosques as jest.Mock;

beforeEach(() => {
  jest.clearAllMocks();
  mockedListMosques.mockResolvedValue([
    { id: "1", name: "Mosque A", slug: "mosque-a", isHiddenResolved: false },
    { id: "2", name: "Mosque B", slug: "mosque-b", isHiddenResolved: false },
  ]);
});

describe("SettingsScreen", () => {
  it("renders mosque menu and selects a mosque from the sheet", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByTestId("settings-mosque-picker")).toBeTruthy());

    fireEvent.press(screen.getByTestId("settings-mosque-picker"));
    await waitFor(() => expect(screen.getByText("Mosque B")).toBeTruthy());
    fireEvent.press(screen.getByText("Mosque B"));
    expect(mockSetSelectedMosque).toHaveBeenCalledWith("2", "mosque-b", "name:sheffield");
  });

  it("toggles 24-hour time format", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByTestId("settings-mosque-picker")).toBeTruthy());

    const toggle = screen.getAllByRole("switch")[0];
    fireEvent(toggle, "valueChange", true);
    expect(mockSetUses24HourTime).toHaveBeenCalledWith(true);
  });

  it("toggles Qibla compass", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByTestId("settings-mosque-picker")).toBeTruthy());

    const toggles = screen.getAllByRole("switch");
    // Index 1 = Qibla toggle (after 24h at index 0)
    expect(toggles.length).toBeGreaterThanOrEqual(2);
    fireEvent(toggles[1], "valueChange", false);
    expect(mockSetHideQiblaCompass).toHaveBeenCalledWith(true);
  });

  it("toggles notification master", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByTestId("settings-mosque-picker")).toBeTruthy());

    const toggles = screen.getAllByRole("switch");
    // Index 2 = notification master toggle (after 24h and qibla)
    expect(toggles.length).toBeGreaterThanOrEqual(3);
    fireEvent(toggles[2], "valueChange", true);
    expect(mockSetNotificationMaster).toHaveBeenCalledWith(true);
  });
});
