import React from "react";
import { render, screen, fireEvent, waitFor } from "@testing-library/react-native";
import HomeScreen from "@/app/index.tsx";

const mockPush = jest.fn();

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: mockPush }),
}));

jest.mock("react-native-safe-area-context", () => ({
  SafeAreaView: ({ children }: any) => children,
  SafeAreaProvider: ({ children }: any) => children,
}));

jest.mock("@/lib/hooks/useHomePrayerData", () => ({
  useHomePrayerData: jest.fn(),
}));

jest.mock("@/store/settings", () => ({
  useSettingsStore: jest.fn((selector: any) =>
    selector({ uses24HourTime: false, appLanguage: "system" })
  ),
}));

jest.mock("expo-localization", () => ({
  getLocales: () => [{ languageTag: "en-GB", languageCode: "en" }],
}));

jest.mock("expo-linear-gradient", () => {
  const React = require("react");
  const { View } = require("react-native");
  return {
    __esModule: true,
    LinearGradient: (props: any) => React.createElement(View, null, props.children),
  };
});

jest.mock("expo-blur", () => {
  const React = require("react");
  const { View } = require("react-native");
  return {
    __esModule: true,
    BlurView: (props: any) => React.createElement(View, null, props.children),
  };
});

jest.mock("lucide-react-native", () => ({
  Calendar: () => null,
  Settings: () => null,
  Moon: () => null,
  Sun: () => null,
  CloudSun: () => null,
  MoonStar: () => null,
  Sunrise: () => null,
  Sunset: () => null,
}));

jest.mock("@/components/ui/PrayerCarousel", () => ({
  PrayerCarousel: ({ onSelectPrayer }: any) => {
    const React = require("react");
    const { Pressable, Text } = require("react-native");
    return React.createElement(Pressable, {
      onPress: () => onSelectPrayer("Dhuhr"),
      accessibilityLabel: "Dhuhr",
    }, React.createElement(Text, null, "Dhuhr"));
  },
}));

import { useHomePrayerData } from "@/lib/hooks/useHomePrayerData";

const mockedUseHomePrayerData = useHomePrayerData as jest.Mock;

beforeEach(() => {
  jest.clearAllMocks();
});

describe("HomeScreen", () => {
  it("shows loading state", () => {
    mockedUseHomePrayerData.mockReturnValue({
      loadState: "loading",
      displayedPrayerTimes: null,
      iqamahTimes: null,
      nextCountdown: null,
      refresh: jest.fn(),
    });

    render(<HomeScreen />);
    expect(screen.getByTestId("home-loading")).toBeTruthy();
  });

  it("renders prayer time after loading", () => {
    mockedUseHomePrayerData.mockReturnValue({
      loadState: "loaded",
      displayedPrayerTimes: {
        date: "2024-01-01", fajr: "05:00", sunrise: "06:30",
        dhuhr: "12:00", asr: "15:00", maghrib: "17:00", isha: "19:00",
      },
      iqamahTimes: {
        fajr: "05:15", dhuhr: "12:15", asr: "15:15",
        maghrib: "17:05", isha: "19:30", jummah: "12:30",
      },
      nextCountdown: { nextName: "Fajr" },
      refresh: jest.fn(),
    });

    render(<HomeScreen />);
    expect(screen.getByText("5:00am")).toBeTruthy();
    expect(screen.getByText("Fajr")).toBeTruthy();
  });

  it("shows empty state with retry", () => {
    const refresh = jest.fn();
    mockedUseHomePrayerData.mockReturnValue({
      loadState: "empty",
      displayedPrayerTimes: null,
      iqamahTimes: null,
      nextCountdown: null,
      refresh,
    });

    render(<HomeScreen />);
    expect(screen.getByText("No mosque data available")).toBeTruthy();
    fireEvent.press(screen.getByText("Retry"));
    expect(refresh).toHaveBeenCalled();
  });

  it("formats time in 12h by default", () => {
    mockedUseHomePrayerData.mockReturnValue({
      loadState: "loaded",
      displayedPrayerTimes: {
        date: "2024-01-01", fajr: "13:00", sunrise: "06:30",
        dhuhr: "12:00", asr: "15:00", maghrib: "17:00", isha: "19:00",
      },
      iqamahTimes: {
        fajr: "13:15", dhuhr: "12:15", asr: "15:15",
        maghrib: "17:05", isha: "19:30", jummah: "12:30",
      },
      nextCountdown: { nextName: "Fajr" },
      refresh: jest.fn(),
    });

    render(<HomeScreen />);
    expect(screen.getByText("1:00pm")).toBeTruthy();
  });

  it("formats time in 24h when enabled", () => {
    const { useSettingsStore } = require("@/store/settings");
    useSettingsStore.mockImplementation((selector: any) =>
      selector({ uses24HourTime: true, appLanguage: "system" })
    );

    mockedUseHomePrayerData.mockReturnValue({
      loadState: "loaded",
      displayedPrayerTimes: {
        date: "2024-01-01", fajr: "13:00", sunrise: "06:30",
        dhuhr: "12:00", asr: "15:00", maghrib: "17:00", isha: "19:00",
      },
      iqamahTimes: {
        fajr: "13:15", dhuhr: "12:15", asr: "15:15",
        maghrib: "17:05", isha: "19:30", jummah: "12:30",
      },
      nextCountdown: { nextName: "Fajr" },
      refresh: jest.fn(),
    });

    render(<HomeScreen />);
    expect(screen.getByText("13:00")).toBeTruthy();
  });

  it("changes selected prayer via carousel", () => {
    mockedUseHomePrayerData.mockReturnValue({
      loadState: "loaded",
      displayedPrayerTimes: {
        date: "2024-01-01", fajr: "05:00", sunrise: "06:30",
        dhuhr: "12:00", asr: "15:00", maghrib: "17:00", isha: "19:00",
      },
      iqamahTimes: {
        fajr: "05:15", dhuhr: "12:15", asr: "15:15",
        maghrib: "17:05", isha: "19:30", jummah: "12:30",
      },
      nextCountdown: { nextName: "Fajr" },
      refresh: jest.fn(),
    });

    render(<HomeScreen />);
    fireEvent.press(screen.getByLabelText("Dhuhr"));
    expect(screen.getByText("12:00")).toBeTruthy();
  });

  it("navigates to timetable and settings", () => {
    mockedUseHomePrayerData.mockReturnValue({
      loadState: "loaded",
      displayedPrayerTimes: {
        date: "2024-01-01", fajr: "05:00", sunrise: "06:30",
        dhuhr: "12:00", asr: "15:00", maghrib: "17:00", isha: "19:00",
      },
      iqamahTimes: {
        fajr: "05:15", dhuhr: "12:15", asr: "15:15",
        maghrib: "17:05", isha: "19:30", jummah: "12:30",
      },
      nextCountdown: { nextName: "Fajr" },
      refresh: jest.fn(),
    });

    render(<HomeScreen />);
    fireEvent.press(screen.getByLabelText("Timetable screen"));
    expect(mockPush).toHaveBeenCalledWith("/timetable");
    fireEvent.press(screen.getByLabelText("Settings screen"));
    expect(mockPush).toHaveBeenCalledWith("/settings");
  });
});
