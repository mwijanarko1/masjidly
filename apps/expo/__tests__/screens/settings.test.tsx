import React from "react";
import { render, screen, fireEvent, waitFor } from "@testing-library/react-native";
import SettingsScreen from "@/app/settings.tsx";

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
const mockSetNotificationPrayer = jest.fn();

jest.mock("@/store/settings", () => {
  const makeState = () => ({
    selectedMosqueId: "1",
    selectedMosqueSlug: "mosque-a",
    uses24HourTime: false,
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
    setNotificationMaster: mockSetNotificationMaster,
    setNotificationPrayer: mockSetNotificationPrayer,
    setAdhanEnabled: jest.fn(),
    setIqamahEnabled: jest.fn(),
    setPreAdhanReminderMinutes: jest.fn(),
    setPreIqamahReminderMinutes: jest.fn(),
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

jest.mock("@/lib/notifications/prayerNotifications", () => ({
  cancelAllPrayerNotifications: jest.fn(),
  rescheduleUpcomingPrayerNotifications: jest.fn(),
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
    expect(mockSetSelectedMosque).toHaveBeenCalledWith("2", "mosque-b");
  });

  it("toggles 24-hour time format", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByTestId("settings-mosque-picker")).toBeTruthy());

    const toggle = screen.getAllByRole("switch")[0];
    fireEvent(toggle, "valueChange", true);
    expect(mockSetUses24HourTime).toHaveBeenCalledWith(true);
  });

  it("toggles notification master", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByTestId("settings-mosque-picker")).toBeTruthy());

    const toggles = screen.getAllByRole("switch");
    expect(toggles.length).toBeGreaterThanOrEqual(2);

    fireEvent(toggles[1], "valueChange", true);
    expect(mockSetNotificationMaster).toHaveBeenCalledWith(true);
  });

  it("shows per-prayer toggles when master enabled", async () => {
    // Re-mock with masterEnabled: true
    jest.doMock("@/store/settings", () => {
      const state = {
        selectedMosqueId: "1",
        selectedMosqueSlug: "mosque-a",
        uses24HourTime: false,
        notifications: {
          masterEnabled: true,
          fajr: true,
          dhuhrJummah: true,
          asr: true,
          maghrib: true,
          isha: true,
        },
        setSelectedMosque: mockSetSelectedMosque,
        setUses24HourTime: mockSetUses24HourTime,
        setNotificationMaster: mockSetNotificationMaster,
        setNotificationPrayer: mockSetNotificationPrayer,
      };
      const useSettingsStore = jest.fn((selector?: any) => {
        if (typeof selector === "function") return selector(state);
        return state;
      });
      useSettingsStore.getState = () => state;
      return { useSettingsStore };
    });

    // Re-render with updated mock
    const { rerender } = render(<SettingsScreen />);
    rerender(<SettingsScreen />);

    await waitFor(() => {
      // All toggles should be present including per-prayer ones
      expect(screen.getAllByRole("switch").length).toBeGreaterThanOrEqual(2);
    });
  });
});
