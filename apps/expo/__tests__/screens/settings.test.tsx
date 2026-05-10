import React from "react";
import { render, screen, fireEvent, waitFor } from "@testing-library/react-native";
import SettingsScreen from "@/app/settings.tsx";

const mockBack = jest.fn();

jest.mock("expo-router", () => ({
  useRouter: () => ({ back: mockBack }),
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
const mockSetAppLanguage = jest.fn();
const mockSetUses24HourTime = jest.fn();
const mockSetNotificationMaster = jest.fn();
const mockSetNotificationPrayer = jest.fn();

jest.mock("@/store/settings", () => ({
  useSettingsStore: jest.fn((selector?: any) => {
    const state = {
      selectedMosqueId: "1",
      selectedMosqueSlug: "mosque-a",
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
      setSelectedMosque: mockSetSelectedMosque,
      setAppLanguage: mockSetAppLanguage,
      setUses24HourTime: mockSetUses24HourTime,
      setNotificationMaster: mockSetNotificationMaster,
      setNotificationPrayer: mockSetNotificationPrayer,
    };
    if (typeof selector === "function") return selector(state);
    return state;
  }),
}));

jest.mock("expo-localization", () => ({
  getLocales: () => [{ languageTag: "en-GB", languageCode: "en" }],
}));

jest.mock("expo-linear-gradient", () => {
  const React = require("react");
  const { View } = require("react-native");
  return { LinearGradient: (props: any) => React.createElement(View, null, props.children) };
});

jest.mock("lucide-react-native", () => ({
  X: () => null,
  Check: () => null,
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
  it("renders visible mosque list and selects a mosque", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByText("Mosque A")).toBeTruthy());
    expect(screen.getByText("Mosque B")).toBeTruthy();

    fireEvent.press(screen.getByText("Mosque B"));
    expect(mockSetSelectedMosque).toHaveBeenCalledWith("2", "mosque-b");
  });

  it("toggles 24-hour time format", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByText("Mosque A")).toBeTruthy());

    const toggle = screen.getAllByRole("switch")[0];
    fireEvent(toggle, "valueChange", true);
    expect(mockSetUses24HourTime).toHaveBeenCalledWith(true);
  });

  it("selects a language", async () => {
    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByText("Mosque A")).toBeTruthy());

    fireEvent.press(screen.getByText("Arabic"));
    expect(mockSetAppLanguage).toHaveBeenCalledWith("arabic");
  });

  it("shows RTL note for Arabic/Urdu", async () => {
    const { useSettingsStore } = require("@/store/settings");
    useSettingsStore.mockImplementation((selector?: any) => {
      const state = {
        selectedMosqueId: "1",
        selectedMosqueSlug: "mosque-a",
        uses24HourTime: false,
        appLanguage: "arabic",
        notifications: {
          masterEnabled: false,
          fajr: true,
          dhuhrJummah: true,
          asr: true,
          maghrib: true,
          isha: true,
        },
        setSelectedMosque: mockSetSelectedMosque,
        setAppLanguage: mockSetAppLanguage,
        setUses24HourTime: mockSetUses24HourTime,
        setNotificationMaster: mockSetNotificationMaster,
        setNotificationPrayer: mockSetNotificationPrayer,
      };
      if (typeof selector === "function") return selector(state);
      return state;
    });

    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByText("Mosque A")).toBeTruthy());
    expect(screen.getByText("App restart may be needed for full RTL layout.")).toBeTruthy();
  });

  it("toggles notification master and individual prayers", async () => {
    const { useSettingsStore } = require("@/store/settings");
    useSettingsStore.mockImplementation((selector?: any) => {
      const state = {
        selectedMosqueId: "1",
        selectedMosqueSlug: "mosque-a",
        uses24HourTime: false,
        appLanguage: "system",
        notifications: {
          masterEnabled: true,
          fajr: true,
          dhuhrJummah: true,
          asr: true,
          maghrib: true,
          isha: true,
        },
        setSelectedMosque: mockSetSelectedMosque,
        setAppLanguage: mockSetAppLanguage,
        setUses24HourTime: mockSetUses24HourTime,
        setNotificationMaster: mockSetNotificationMaster,
        setNotificationPrayer: mockSetNotificationPrayer,
      };
      if (typeof selector === "function") return selector(state);
      return state;
    });

    render(<SettingsScreen />);
    await waitFor(() => expect(screen.getByText("Mosque A")).toBeTruthy());

    const toggles = screen.getAllByRole("switch");
    expect(toggles.length).toBeGreaterThanOrEqual(7);

    fireEvent(toggles[2], "valueChange", false);
    expect(mockSetNotificationPrayer).toHaveBeenCalledWith("fajr", false);
  });
});
