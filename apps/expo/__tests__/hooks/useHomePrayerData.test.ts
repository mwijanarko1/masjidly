import { renderHook, waitFor, act } from "@testing-library/react-native";
import { useHomePrayerData } from "@/lib/hooks/useHomePrayerData";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import { useSettingsStore } from "@/store/settings";
import { resolveSelectedMosque } from "@/lib/prayer/mosqueDefaults";
import {
  resolvePrayerTimes,
  resolveIqamahTimesWithDstMapping,
  getDisplayedPrayerTimes,
  getNextPrayerAndCountdown,
} from "@/lib/prayer/prayerTimesEngine";

jest.mock("@/lib/prayer/prayerRepository", () => ({
  prayerRepository: {
    listMosques: jest.fn(),
    getMonthlyPrayerTimes: jest.fn(),
    getRamadanTimetable: jest.fn(),
    getUkDstDates: jest.fn(),
  },
}));

jest.mock("@/store/settings", () => ({
  useSettingsStore: jest.fn(),
}));

jest.mock("@/lib/prayer/mosqueDefaults", () => ({
  resolveSelectedMosque: jest.fn(),
  visibleMosques: jest.fn((m: any[]) => m),
}));

jest.mock("@/lib/prayer/prayerTimesEngine", () => ({
  getDisplayedPrayerTimes: jest.fn((t: any) => t),
  getNextPrayerAndCountdown: jest.fn(() => ({
    nextName: "Fajr", nextTime: "05:00", totalSeconds: 3600,
    isIqamah: false, isJummah: false, hours: 1, minutes: 0, seconds: 0,
  })),
  resolvePrayerTimes: jest.fn(() => ({
    date: "2024-01-01", fajr: "05:00", sunrise: "06:30",
    dhuhr: "12:00", asr: "15:00", maghrib: "17:00", isha: "19:00",
  })),
  resolveIqamahTimesWithDstMapping: jest.fn(() => ({
    fajr: "05:15", dhuhr: "12:15", asr: "15:15",
    maghrib: "17:05", isha: "19:30", jummah: "12:30",
  })),
  getDateInSheffield: jest.fn(() => ({ year: 2024, month: 1, day: 1 })),
}));

const mockedUseSettingsStore = useSettingsStore as unknown as jest.Mock;
const mockedListMosques = prayerRepository.listMosques as jest.Mock;
const mockedResolveSelectedMosque = resolveSelectedMosque as jest.Mock;
const mockedGetMonthly = prayerRepository.getMonthlyPrayerTimes as jest.Mock;
const mockedGetRamadan = prayerRepository.getRamadanTimetable as jest.Mock;
const mockedGetUkDst = prayerRepository.getUkDstDates as jest.Mock;

const stableSetSelectedMosque = jest.fn();

beforeEach(() => {
  jest.clearAllMocks();
  mockedUseSettingsStore.mockImplementation((selector: any) =>
    selector({
      selectedMosqueId: undefined,
      selectedMosqueSlug: undefined,
      setSelectedMosque: stableSetSelectedMosque,
    })
  );
});

describe("useHomePrayerData", () => {
  it("starts in loading state and transitions to loaded", async () => {
    const mosque = { id: "1", name: "Test Mosque", slug: "test" };
    mockedListMosques.mockResolvedValue([mosque]);
    mockedResolveSelectedMosque.mockReturnValue(mosque);
    mockedGetMonthly.mockResolvedValue({
      month: "january", prayerTimes: [], iqamahTimes: [], jummahIqamah: "",
    });
    mockedGetRamadan.mockResolvedValue(null);
    mockedGetUkDst.mockResolvedValue({ ukDstDates: [] });

    const { result } = renderHook(() => useHomePrayerData());

    expect(result.current.loadState).toBe("loading");

    await waitFor(() => expect(result.current.loadState).toBe("loaded"));

    expect(result.current.selectedMosque).toEqual(mosque);
    expect(result.current.displayedPrayerTimes).not.toBeNull();
    expect(result.current.nextCountdown).not.toBeNull();
  });

  it("goes to empty state when no mosque is resolved", async () => {
    mockedListMosques.mockResolvedValue([]);
    mockedResolveSelectedMosque.mockReturnValue(null);

    const { result } = renderHook(() => useHomePrayerData());

    await waitFor(() => expect(result.current.loadState).toBe("empty"));
    expect(result.current.selectedMosque).toBeNull();
  });

  it("persists resolved mosque to settings when changed", async () => {
    mockedUseSettingsStore.mockImplementation((selector: any) =>
      selector({
        selectedMosqueId: "old-id",
        selectedMosqueSlug: "old-slug",
        setSelectedMosque: stableSetSelectedMosque,
      })
    );

    const mosque = { id: "1", name: "Test", slug: "test" };
    mockedListMosques.mockResolvedValue([mosque]);
    mockedResolveSelectedMosque.mockReturnValue(mosque);
    mockedGetMonthly.mockResolvedValue({
      month: "january", prayerTimes: [], iqamahTimes: [], jummahIqamah: "",
    });
    mockedGetRamadan.mockResolvedValue(null);
    mockedGetUkDst.mockResolvedValue({ ukDstDates: [] });

    renderHook(() => useHomePrayerData());

    await waitFor(() => expect(stableSetSelectedMosque).toHaveBeenCalledWith("1", "test"));
  });

  it("handles repository errors gracefully", async () => {
    mockedListMosques.mockRejectedValue(new Error("Network error"));

    const { result } = renderHook(() => useHomePrayerData());

    await waitFor(() => expect(result.current.loadState).toBe("error"));
  });

  it("refresh re-fetches data", async () => {
    const mosque = { id: "1", name: "Test", slug: "test" };
    mockedListMosques.mockResolvedValue([mosque]);
    mockedResolveSelectedMosque.mockReturnValue(mosque);
    mockedGetMonthly.mockResolvedValue({
      month: "january", prayerTimes: [], iqamahTimes: [], jummahIqamah: "",
    });
    mockedGetRamadan.mockResolvedValue(null);
    mockedGetUkDst.mockResolvedValue({ ukDstDates: [] });

    const { result } = renderHook(() => useHomePrayerData());

    await waitFor(() => expect(result.current.loadState).toBe("loaded"));

    await act(async () => {
      await result.current.refresh();
    });

    expect(mockedListMosques).toHaveBeenCalledTimes(2);
  });
});
