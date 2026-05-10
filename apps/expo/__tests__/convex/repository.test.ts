import { z } from "zod";
import { prayerRepository } from "@/lib/prayer/prayerRepository";

jest.mock("@/lib/convex/client", () => {
  const mockQuery = jest.fn();
  return {
    convexClient: {
      query: (...args: any[]) => mockQuery(...args),
    },
    __mockQuery: mockQuery,
  };
});

jest.mock("convex/server", () => ({
  anyApi: {
    mosques: { list: "mosques.list" },
    prayerTimes: {
      getMonthly: "prayerTimes.getMonthly",
      getRamadan: "prayerTimes.getRamadan",
      getUkDstDates: "prayerTimes.getUkDstDates",
    },
  },
}));

const { __mockQuery } = jest.requireMock("@/lib/convex/client") as {
  __mockQuery: jest.Mock;
};

describe("PrayerRepository", () => {
  beforeEach(() => {
    __mockQuery.mockClear();
  });

  it("listMosques calls correct API and parses result", async () => {
    const raw = [
      {
        id: "1",
        name: "Mosque A",
        address: "1 Main St",
        lat: 53.38,
        lng: -1.47,
        slug: "mosque-a",
        website: null,
        is_hidden: false,
      },
    ];
    __mockQuery.mockResolvedValue(raw);

    const result = await prayerRepository.listMosques();
    expect(__mockQuery).toHaveBeenCalledWith("mosques.list", {});
    expect(result).toEqual([
      {
        id: "1",
        name: "Mosque A",
        address: "1 Main St",
        lat: 53.38,
        lng: -1.47,
        slug: "mosque-a",
        website: null,
        isHidden: false,
        isHiddenResolved: false,
      },
    ]);
  });

  it("getMonthlyPrayerTimes passes arguments and parses result", async () => {
    const raw = {
      month: "May",
      prayer_times: [
        {
          date: 1,
          fajr: "04:30",
          shurooq: "05:45",
          dhuhr: "13:00",
          asr: "17:00",
          maghrib: "20:30",
          isha: "21:45",
        },
      ],
      iqamah_times: [
        {
          date_range: "1-31",
          fajr: "05:00",
          dhuhr: "13:30",
          asr: "17:30",
          maghrib: "sunset",
          isha: "22:00",
          jummah: "13:35",
        },
      ],
      jummah_iqamah: "13:35",
    };
    __mockQuery.mockResolvedValue(raw);

    const result = await prayerRepository.getMonthlyPrayerTimes(
      "mosque-a",
      "may",
      2024
    );
    expect(__mockQuery).toHaveBeenCalledWith("prayerTimes.getMonthly", {
      mosqueSlug: "mosque-a",
      month: "may",
      year: 2024,
    });
    expect(result).toEqual({
      month: "May",
      prayerTimes: [
        {
          date: 1,
          fajr: "04:30",
          shurooq: "05:45",
          dhuhr: "13:00",
          asr: "17:00",
          maghrib: "20:30",
          isha: "21:45",
        },
      ],
      iqamahTimes: [
        {
          dateRange: "1-31",
          fajr: "05:00",
          dhuhr: "13:30",
          asr: "17:30",
          maghrib: "sunset",
          isha: "22:00",
          jummah: "13:35",
        },
      ],
      jummahIqamah: "13:35",
    });
  });

  it("getRamadanTimetable passes optional date and parses result", async () => {
    const raw = {
      month: "Ramadan",
      gregorian_start: "2024-03-11",
      gregorian_end: "2024-04-09",
      prayer_times: [
        {
          ramadan_day: 1,
          gregorian: "2024-03-11",
          fajr: "04:45",
          shurooq: "06:00",
          dhuhr: "13:00",
          asr: "17:00",
          maghrib: "18:15",
          isha: "19:45",
        },
      ],
      iqamah_times: [
        {
          date_range: "1-30",
          fajr: "05:15",
          dhuhr: "13:30",
          asr: "17:30",
          isha: "20:00",
        },
      ],
      jummah_iqamah: "12:45",
    };
    __mockQuery.mockResolvedValue(raw);

    const result = await prayerRepository.getRamadanTimetable(
      "mosque-a",
      "2024-03-11"
    );
    expect(__mockQuery).toHaveBeenCalledWith("prayerTimes.getRamadan", {
      mosqueSlug: "mosque-a",
      date: "2024-03-11",
    });
    expect(result).toMatchObject({
      month: "Ramadan",
      gregorianStart: "2024-03-11",
      gregorianEnd: "2024-04-09",
    });
  });

  it("getRamadanTimetable omits date when undefined", async () => {
    __mockQuery.mockResolvedValue({
      month: "Ramadan",
      gregorian_start: "2024-03-11",
      gregorian_end: "2024-04-09",
      prayer_times: [],
      iqamah_times: [],
      jummah_iqamah: "12:45",
    });

    await prayerRepository.getRamadanTimetable("mosque-a");
    expect(__mockQuery).toHaveBeenCalledWith("prayerTimes.getRamadan", {
      mosqueSlug: "mosque-a",
    });
  });

  it("getUkDstDates returns null when Convex returns null", async () => {
    __mockQuery.mockResolvedValue(null);
    const result = await prayerRepository.getUkDstDates();
    expect(result).toBeNull();
  });

  it("getUkDstDates parses valid DST calendar", async () => {
    const raw = {
      uk_dst_dates: [
        { year: 2024, start_date: "2024-03-31", end_date: "2024-10-27" },
      ],
    };
    __mockQuery.mockResolvedValue(raw);

    const result = await prayerRepository.getUkDstDates();
    expect(result).toEqual({
      ukDstDates: [
        { year: 2024, startDate: "2024-03-31", endDate: "2024-10-27" },
      ],
    });
  });

  it("Zod parse failures surface useful errors", async () => {
    const bad = {
      month: 123,
      prayer_times: "invalid",
      iqamah_times: [],
      jummah_iqamah: "12:45",
    };
    __mockQuery.mockResolvedValue(bad);

    await expect(
      prayerRepository.getMonthlyPrayerTimes("mosque-a", "may", 2024)
    ).rejects.toThrow(z.ZodError);
  });
});
