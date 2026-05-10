import {
  rescheduleUpcomingPrayerNotifications,
  cancelAllPrayerNotifications,
  requestNotificationAuthorizationIfNeeded,
} from "@/lib/notifications/prayerNotifications";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import type { Mosque, MonthPrayerData } from "@/types/prayer";
import type { NotificationSettings } from "@/store/settings";

jest.mock("expo-notifications", () => ({
  getPermissionsAsync: jest.fn(),
  requestPermissionsAsync: jest.fn(),
  scheduleNotificationAsync: jest.fn(),
  getAllScheduledNotificationsAsync: jest.fn(),
  cancelScheduledNotificationAsync: jest.fn(),
  setNotificationChannelAsync: jest.fn(),
  AndroidImportance: { DEFAULT: 5 },
  SchedulableTriggerInputTypes: { DATE: "date" },
}));

jest.mock("@/lib/prayer/prayerRepository", () => ({
  prayerRepository: {
    getUkDstDates: jest.fn(),
    getMonthlyPrayerTimes: jest.fn(),
    getRamadanTimetable: jest.fn(),
  },
}));

const mockedNotifications = jest.mocked(Notifications);
const mockedRepository = jest.mocked(prayerRepository);

function makeMosque(): Mosque {
  return {
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
}

function makeMonthlyData(): MonthPrayerData {
  return {
    month: "june",
    prayerTimes: [
      {
        date: 13,
        fajr: "03:00",
        shurooq: "04:00",
        dhuhr: "13:00",
        asr: "17:00",
        maghrib: "21:00",
        isha: "22:30",
      },
    ],
    iqamahTimes: [
      {
        dateRange: "1-30",
        fajr: "03:30",
        dhuhr: "13:20",
        asr: "17:10",
        maghrib: "21:05",
        isha: "22:40",
        jummah: "13:25",
      },
    ],
    jummahIqamah: "13:25",
  };
}

function makeSettings(
  overrides?: Partial<NotificationSettings>
): NotificationSettings {
  return {
    masterEnabled: true,
    fajr: true,
    dhuhrJummah: true,
    asr: true,
    maghrib: true,
    isha: true,
    ...overrides,
  };
}

describe("prayerNotifications", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedNotifications.getPermissionsAsync.mockResolvedValue({
      status: "granted",
    } as any);
    mockedNotifications.requestPermissionsAsync.mockResolvedValue({
      status: "granted",
    } as any);
    mockedNotifications.getAllScheduledNotificationsAsync.mockResolvedValue([]);
    mockedRepository.getUkDstDates.mockResolvedValue({ ukDstDates: [] });
    mockedRepository.getMonthlyPrayerTimes.mockResolvedValue(makeMonthlyData());
    mockedRepository.getRamadanTimetable.mockResolvedValue(null);
  });

  afterEach(() => {
    jest.useRealTimers();
    (Platform as any).OS = "ios";
  });

  describe("requestNotificationAuthorizationIfNeeded", () => {
    it("returns true when already granted", async () => {
      mockedNotifications.getPermissionsAsync.mockResolvedValue({
        status: "granted",
      } as any);
      const result = await requestNotificationAuthorizationIfNeeded();
      expect(result).toBe(true);
      expect(mockedNotifications.requestPermissionsAsync).not.toHaveBeenCalled();
    });

    it("requests permission when not granted", async () => {
      mockedNotifications.getPermissionsAsync.mockResolvedValue({
        status: "denied",
      } as any);
      mockedNotifications.requestPermissionsAsync.mockResolvedValue({
        status: "granted",
      } as any);
      const result = await requestNotificationAuthorizationIfNeeded();
      expect(result).toBe(true);
      expect(mockedNotifications.requestPermissionsAsync).toHaveBeenCalled();
    });
  });

  describe("cancelAllPrayerNotifications", () => {
    it("cancels only Masjidly prayer identifiers", async () => {
      mockedNotifications.getAllScheduledNotificationsAsync.mockResolvedValue([
        { identifier: "masjidly.prayer.test.2025-06-13.fajr.adhan" },
        { identifier: "other.app.notification" },
        { identifier: "masjidly.prayer.test.2025-06-13.fajr.iqamah" },
      ] as any);
      await cancelAllPrayerNotifications();
      expect(
        mockedNotifications.cancelScheduledNotificationAsync
      ).toHaveBeenCalledTimes(2);
      expect(
        mockedNotifications.cancelScheduledNotificationAsync
      ).toHaveBeenCalledWith("masjidly.prayer.test.2025-06-13.fajr.adhan");
      expect(
        mockedNotifications.cancelScheduledNotificationAsync
      ).toHaveBeenCalledWith("masjidly.prayer.test.2025-06-13.fajr.iqamah");
    });
  });

  describe("rescheduleUpcomingPrayerNotifications", () => {
    it("master off cancels and schedules nothing", async () => {
      mockedNotifications.getAllScheduledNotificationsAsync.mockResolvedValue([
        { identifier: "masjidly.prayer.test.2025-06-13.fajr.adhan" },
      ] as any);

      const mosque = makeMosque();
      const settings = makeSettings({ masterEnabled: false });

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
      });

      expect(
        mockedNotifications.cancelScheduledNotificationAsync
      ).toHaveBeenCalled();
      expect(mockedNotifications.scheduleNotificationAsync).not.toHaveBeenCalled();
    });

    it("master on requests permission", async () => {
      mockedNotifications.getPermissionsAsync.mockResolvedValue({
        status: "denied",
      } as any);
      mockedNotifications.requestPermissionsAsync.mockResolvedValue({
        status: "granted",
      } as any);

      jest.useFakeTimers({ now: new Date("2025-06-13T00:00:00Z").getTime() });

      const mosque = makeMosque();
      const settings = makeSettings();

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
      });

      expect(mockedNotifications.requestPermissionsAsync).toHaveBeenCalled();
    });

    it("each enabled prayer schedules adhan and iqamah", async () => {
      jest.useFakeTimers({ now: new Date("2025-06-13T00:00:00Z").getTime() });

      const mosque = makeMosque();
      const settings = makeSettings();

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
        days: 1,
      });

      const calls = mockedNotifications.scheduleNotificationAsync.mock.calls;
      // Isha iqamah is "After Maghrib" in summer (unparseable), so only 9 scheduled
      expect(calls.length).toBe(9);

      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.fajr.adhan"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.fajr.iqamah"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.dhuhr.adhan"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.jummah.iqamah"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.asr.adhan"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.asr.iqamah"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.maghrib.adhan"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.maghrib.iqamah"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.isha.adhan"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.isha.iqamah"
        )
      ).toBe(false);
    });

    it("disabled prayer does not schedule", async () => {
      jest.useFakeTimers({ now: new Date("2025-06-13T00:00:00Z").getTime() });

      const mosque = makeMosque();
      const settings = makeSettings({ asr: false });

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
        days: 1,
      });

      const calls = mockedNotifications.scheduleNotificationAsync.mock.calls;
      // Asr disabled (2 fewer) + Isha iqamah skipped in summer (1 fewer) = 7
      expect(calls.length).toBe(7);

      expect(
        calls.some((call: any) => call[0].identifier.includes(".asr."))
      ).toBe(false);
    });

    it("Friday schedules Jummah copy", async () => {
      jest.useFakeTimers({ now: new Date("2025-06-13T00:00:00Z").getTime() });

      const mosque = makeMosque();
      const settings = makeSettings();

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
        days: 1,
      });

      const calls = mockedNotifications.scheduleNotificationAsync.mock.calls;

      const dhuhrAdhan = calls.find(
        (call: any) =>
          call[0].identifier ===
          "masjidly.prayer.test-mosque.2025-06-13.dhuhr.adhan"
      );
      expect(dhuhrAdhan?.[0].content.body).toBe("Jummah Adhan");

      const jummahIqamah = calls.find(
        (call: any) =>
          call[0].identifier ===
          "masjidly.prayer.test-mosque.2025-06-13.jummah.iqamah"
      );
      expect(jummahIqamah).toBeDefined();
      expect(jummahIqamah?.[0].content.body).toBe("Jummah");
    });

    it("past times are skipped", async () => {
      jest.useFakeTimers({ now: new Date("2025-06-13T14:00:00Z").getTime() });

      const mosque = makeMosque();
      const settings = makeSettings();

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
        days: 1,
      });

      const calls = mockedNotifications.scheduleNotificationAsync.mock.calls;

      expect(
        calls.some((call: any) => call[0].identifier.includes(".fajr."))
      ).toBe(false);
      expect(
        calls.some((call: any) => call[0].identifier.includes(".dhuhr."))
      ).toBe(false);
      expect(
        calls.some((call: any) => call[0].identifier.includes(".asr."))
      ).toBe(true);
      expect(
        calls.some((call: any) => call[0].identifier.includes(".maghrib."))
      ).toBe(true);
      expect(
        calls.some((call: any) => call[0].identifier.includes(".isha."))
      ).toBe(true);
    });

    it("identifiers are stable and prefixed with masjidly.prayer.", async () => {
      jest.useFakeTimers({ now: new Date("2025-06-13T00:00:00Z").getTime() });

      const mosque = makeMosque();
      const settings = makeSettings();

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
        days: 1,
      });

      const calls = mockedNotifications.scheduleNotificationAsync.mock.calls;
      for (const call of calls) {
        expect(call[0].identifier).toMatch(/^masjidly\.prayer\./);
      }

      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.fajr.adhan"
        )
      ).toBe(true);
      expect(
        calls.some(
          (call: any) =>
            call[0].identifier ===
            "masjidly.prayer.test-mosque.2025-06-13.fajr.iqamah"
        )
      ).toBe(true);
    });

    it("notification channel is configured on Android", async () => {
      (Platform as any).OS = "android";

      jest.useFakeTimers({ now: new Date("2025-06-13T00:00:00Z").getTime() });

      const mosque = makeMosque();
      const settings = makeSettings();

      await rescheduleUpcomingPrayerNotifications({
        mosque,
        settings,
        locale: "en",
        days: 1,
      });

      expect(mockedNotifications.setNotificationChannelAsync).toHaveBeenCalledWith(
        "prayer-times",
        {
          name: "Prayer Times",
          importance: mockedNotifications.AndroidImportance.DEFAULT,
        }
      );

      const calls = mockedNotifications.scheduleNotificationAsync.mock.calls;
      const androidCall = calls[0] as any;
      expect(androidCall[0].trigger.channelId).toBe("prayer-times");
    });
  });
});
