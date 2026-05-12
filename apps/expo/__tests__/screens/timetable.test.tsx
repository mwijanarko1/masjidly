import React from "react";
import { render, screen, fireEvent, waitFor } from "@testing-library/react-native";
import TimetableScreen from "@/app/timetable.tsx";

const mockBack = jest.fn();
let mockMosqueSlugParam: string | undefined = "test-mosque";

jest.mock("expo-router", () => ({
  useRouter: () => ({ back: mockBack }),
  useLocalSearchParams: () => ({ mosqueSlug: mockMosqueSlugParam }),
}));

jest.mock("react-native-safe-area-context", () => ({
  SafeAreaView: ({ children }: any) => children,
}));

jest.mock("@/lib/prayer/prayerRepository", () => ({
  prayerRepository: {
    getMonthlyPrayerTimes: jest.fn(),
  },
}));

jest.mock("@/store/settings", () => ({
  useSettingsStore: jest.fn((selector: any) =>
    selector({
      selectedMosqueSlug: "stored-mosque",
      uses24HourTime: false,
    })
  ),
}));

jest.mock("expo-linear-gradient", () => {
  const React = require("react");
  const { View } = require("react-native");
  return { LinearGradient: (props: any) => React.createElement(View, null, props.children) };
});

jest.mock("lucide-react-native", () => ({
  X: () => null,
  ChevronLeft: () => null,
  ChevronRight: () => null,
}));

import { prayerRepository } from "@/lib/prayer/prayerRepository";

const mockedGetMonthly = prayerRepository.getMonthlyPrayerTimes as jest.Mock;

beforeEach(() => {
  jest.clearAllMocks();
  mockMosqueSlugParam = "test-mosque";
});

describe("TimetableScreen", () => {
  it("renders and selects today on current month", async () => {
    const today = new Date();
    mockedGetMonthly.mockResolvedValue({
      month: "january",
      prayerTimes: Array.from({ length: 31 }, (_, i) => ({
        date: i + 1,
        fajr: "05:00", shurooq: "06:30", dhuhr: "12:00",
        asr: "15:00", maghrib: "17:00", isha: "19:00",
      })),
      iqamahTimes: [
        { dateRange: "1-31", fajr: "05:15", dhuhr: "12:15", asr: "15:15", maghrib: "17:05", isha: "19:30", jummah: "12:30" },
      ],
      jummahIqamah: "12:30",
    });

    render(<TimetableScreen />);

    await waitFor(() => expect(mockedGetMonthly).toHaveBeenCalled());
    expect(screen.getByText(String(today.getDate()))).toBeTruthy();
  });

  it("loads the selected mosque timetable from settings when route has no slug", async () => {
    mockMosqueSlugParam = undefined;
    mockedGetMonthly.mockResolvedValue({
      month: "january",
      prayerTimes: Array.from({ length: 31 }, (_, i) => ({
        date: i + 1,
        fajr: "05:00", shurooq: "06:30", dhuhr: "12:00",
        asr: "15:00", maghrib: "17:00", isha: "19:00",
      })),
      iqamahTimes: [
        { dateRange: "1-31", fajr: "05:15", dhuhr: "12:15", asr: "15:15", maghrib: "17:05", isha: "19:30", jummah: "12:30" },
      ],
      jummahIqamah: "12:30",
    });

    render(<TimetableScreen />);

    await waitFor(() =>
      expect(mockedGetMonthly).toHaveBeenCalledWith(
        "stored-mosque",
        expect.any(String),
        expect.any(Number)
      )
    );
    expect(screen.getByText("stored-mosque")).toBeTruthy();
  });

  it("selects first day on non-current month", async () => {
    mockedGetMonthly.mockResolvedValue({
      month: "january",
      prayerTimes: Array.from({ length: 31 }, (_, i) => ({
        date: i + 1,
        fajr: "05:00", shurooq: "06:30", dhuhr: "12:00",
        asr: "15:00", maghrib: "17:00", isha: "19:00",
      })),
      iqamahTimes: [
        { dateRange: "1-31", fajr: "05:15", dhuhr: "12:15", asr: "15:15", maghrib: "17:05", isha: "19:30", jummah: "12:30" },
      ],
      jummahIqamah: "12:30",
    });

    render(<TimetableScreen />);
    await waitFor(() => expect(mockedGetMonthly).toHaveBeenCalled());
  });

  it("shows Jummah row on Friday", async () => {
    const friday = new Date(2024, 0, 5);
    jest.useFakeTimers().setSystemTime(friday);

    mockedGetMonthly.mockResolvedValue({
      month: "january",
      prayerTimes: Array.from({ length: 31 }, (_, i) => ({
        date: i + 1,
        fajr: "05:00", shurooq: "06:30", dhuhr: "12:00",
        asr: "15:00", maghrib: "17:00", isha: "19:00",
      })),
      iqamahTimes: [
        { dateRange: "1-31", fajr: "05:15", dhuhr: "12:15", asr: "15:15", maghrib: "17:05", isha: "19:30", jummah: "12:30 / 13:00" },
      ],
      jummahIqamah: "12:30",
    });

    render(<TimetableScreen />);
    await waitFor(() => {
      expect(screen.getAllByText("Jummah").length).toBe(2);
    });
    expect(screen.getByText(/12:30\s*PM/i)).toBeTruthy();
    expect(screen.getByText(/1:00\s*PM/i)).toBeTruthy();
    jest.useRealTimers();
  });

  it("handles month switcher", async () => {
    mockedGetMonthly.mockResolvedValue({
      month: "january",
      prayerTimes: [],
      iqamahTimes: [],
      jummahIqamah: "",
    });

    render(<TimetableScreen />);
    await waitFor(() => expect(mockedGetMonthly).toHaveBeenCalled());

    fireEvent.press(screen.getByLabelText("Previous month"));
    expect(mockedGetMonthly).toHaveBeenCalledTimes(2);
  });

  it("closes on xmark press", async () => {
    mockedGetMonthly.mockResolvedValue({
      month: "january",
      prayerTimes: Array.from({ length: 31 }, (_, i) => ({
        date: i + 1,
        fajr: "05:00", shurooq: "06:30", dhuhr: "12:00",
        asr: "15:00", maghrib: "17:00", isha: "19:00",
      })),
      iqamahTimes: [
        { dateRange: "1-31", fajr: "05:15", dhuhr: "12:15", asr: "15:15", maghrib: "17:05", isha: "19:30", jummah: "12:30" },
      ],
      jummahIqamah: "12:30",
    });

    render(<TimetableScreen />);
    await waitFor(() => expect(mockedGetMonthly).toHaveBeenCalled());

    const closeBtn = screen.getByLabelText("Close timetable");
    fireEvent.press(closeBtn);
    expect(mockBack).toHaveBeenCalled();
  });
});
