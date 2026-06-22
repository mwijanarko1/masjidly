import type { Mosque } from "@/types/prayer";

const mosque: Mosque = {
  id: "1",
  name: "Test Mosque",
  address: "123 Test St",
  lat: 53.38,
  lng: -1.47,
  slug: "test-mosque",
  website: null,
  isHidden: false,
  isHiddenResolved: false,
};

const baseParams = {
  mosque,
  monthData: null,
  ramadanData: null,
  ukDst: [],
  uses24HourTime: false,
  appLanguage: "en-GB" as const,
  asrIqamahPreference: "first" as const,
};

async function loadWidgetModule(options: { os?: string; nativeModule?: boolean } = {}) {
  jest.resetModules();
  const saveSnapshot = jest.fn().mockResolvedValue(true);

  jest.doMock("react-native", () => ({
    Platform: { OS: options.os ?? "android", select: (obj: any) => obj[options.os ?? "android"] ?? obj.default },
    NativeModules: options.nativeModule === false ? {} : {
      MasjidlyPrayerWidget: { saveSnapshot },
    },
  }));

  jest.doMock("@/lib/prayer/prayerTimesEngine", () => {
    const actual = jest.requireActual("@/lib/prayer/prayerTimesEngine");
    return {
      ...actual,
      resolvePrayerTimes: jest.fn(() => ({
        date: "2026-06-19",
        fajr: "03:00",
        sunrise: "04:30",
        dhuhr: "13:00",
        asr: "17:30",
        maghrib: "21:30",
        isha: "23:00",
      })),
      resolveIqamahTimesWithDstMapping: jest.fn(() => ({
        fajr: "03:30",
        dhuhr: "13:20",
        asr: "17:45",
        maghrib: "21:35",
        isha: "23:15",
        jummah: "13:25",
      })),
    };
  });

  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const mod = require("@/lib/widgets/prayerWidget") as typeof import("@/lib/widgets/prayerWidget");
  return { updateAndroidPrayerWidgetSnapshot: mod.updateAndroidPrayerWidgetSnapshot, saveSnapshot };
}

afterEach(() => {
  jest.dontMock("react-native");
  jest.dontMock("@/lib/prayer/prayerTimesEngine");
});

it("no-ops when platform is not Android", async () => {
  const { updateAndroidPrayerWidgetSnapshot, saveSnapshot } = await loadWidgetModule({ os: "ios" });
  await updateAndroidPrayerWidgetSnapshot(baseParams);
  expect(saveSnapshot).not.toHaveBeenCalled();
});

it("no-ops when the native Android widget module is absent", async () => {
  const { updateAndroidPrayerWidgetSnapshot, saveSnapshot } = await loadWidgetModule({ nativeModule: false });
  await updateAndroidPrayerWidgetSnapshot(baseParams);
  expect(saveSnapshot).not.toHaveBeenCalled();
});

it("no-ops when mosque is null", async () => {
  const { updateAndroidPrayerWidgetSnapshot, saveSnapshot } = await loadWidgetModule();
  await updateAndroidPrayerWidgetSnapshot({ ...baseParams, mosque: null });
  expect(saveSnapshot).not.toHaveBeenCalled();
});

it("builds and pushes a size-agnostic 7-day snapshot", async () => {
  const { updateAndroidPrayerWidgetSnapshot, saveSnapshot } = await loadWidgetModule();
  await updateAndroidPrayerWidgetSnapshot(baseParams);

  expect(saveSnapshot).toHaveBeenCalledTimes(1);
  const parsed = JSON.parse(saveSnapshot.mock.calls[0][0]);
  expect(parsed.schemaVersion).toBe(1);
  expect(parsed.mosque.id).toBe("1");
  expect(parsed.days.length).toBe(7);
  expect(parsed).not.toHaveProperty("widgetSize");
});
