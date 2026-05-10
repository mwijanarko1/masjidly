import {
  MosqueSchema,
  MonthPrayerDataSchema,
  RamadanPrayerDataSchema,
  UkDstCalendarSchema,
} from "@/types/prayer";

describe("Decoding", () => {
  it("mosque decodes", () => {
    const json = {
      id: "1",
      name: "Test Masjid",
      address: "1 St",
      lat: 53.3,
      lng: -1.5,
      slug: "test-masjid",
      website: null,
      is_hidden: false,
    };
    const m = MosqueSchema.parse(json);
    expect(m.slug).toBe("test-masjid");
    expect(m.isHiddenResolved).toBe(false);
  });

  it("monthly decodes", () => {
    const json = {
      month: "MAY",
      prayer_times: [
        {
          date: 1,
          fajr: "03:30",
          shurooq: "05:10",
          dhuhr: "13:10",
          asr: "18:30",
          maghrib: "21:00",
          isha: "22:15",
        },
      ],
      iqamah_times: [
        {
          date_range: "1-31",
          fajr: "04:00",
          dhuhr: "13:30",
          asr: "19:00",
          maghrib: "sunset",
          isha: "22:45",
        },
      ],
      jummah_iqamah: "13:35",
    };
    const d = MonthPrayerDataSchema.parse(json);
    expect(d.prayerTimes.length).toBe(1);
    expect(d.jummahIqamah).toBe("13:35");
  });

  it("ramadan decodes", () => {
    const json = {
      month: "Ramadan",
      gregorian_start: "2025-03-01",
      gregorian_end: "2025-03-29",
      prayer_times: [
        {
          ramadan_day: 1,
          gregorian: "2025-03-01",
          fajr: "05:00",
          shurooq: "06:00",
          dhuhr: "12:00",
          asr: "15:00",
          maghrib: "18:00",
          isha: "20:00",
        },
      ],
      iqamah_times: [
        {
          date_range: "1-30",
          fajr: "05:15",
          dhuhr: "12:30",
          asr: "15:30",
          isha: "20:30",
        },
      ],
      jummah_iqamah: "12:45",
    };
    const d = RamadanPrayerDataSchema.parse(json);
    expect(d.prayerTimes[0]?.ramadanDay).toBe(1);
  });

  it("uk dst calendar decodes", () => {
    const json = {
      uk_dst_dates: [
        { year: 2024, start_date: "2024-03-31", end_date: "2024-10-27" },
      ],
    };
    const d = UkDstCalendarSchema.parse(json);
    expect(d.ukDstDates[0]?.startDate).toBe("2024-03-31");
    expect(d.ukDstDates[0]?.endDate).toBe("2024-10-27");
  });
});
