import { z } from "zod";

export const MosqueSchema = z
  .object({
    id: z.string(),
    name: z.string(),
    address: z.string(),
    lat: z.number(),
    lng: z.number(),
    slug: z.string(),
    citySlug: z.string().nullable().optional(),
    cityName: z.string().nullable().optional(),
    countryCode: z.string().nullable().optional(),
    countryName: z.string().nullable().optional(),
    timezone: z.string().nullable().optional(),
    website: z.string().nullable().optional(),
    isHidden: z.boolean().nullable().optional(),
    is_hidden: z.boolean().nullable().optional(),
  })
  .transform((data) => {
    const isHidden = data.isHidden ?? data.is_hidden ?? false;
    return {
      id: data.id,
      name: data.name,
      address: data.address,
      lat: data.lat,
      lng: data.lng,
      slug: data.slug,
      citySlug: data.citySlug ?? "sheffield",
      cityName: data.cityName ?? "Sheffield",
      countryCode: data.countryCode ?? "GB",
      countryName: data.countryName ?? "United Kingdom",
      timezone: data.timezone ?? "Europe/London",
      website: data.website,
      isHidden,
      isHiddenResolved: isHidden,
    };
  });

export type Mosque = z.infer<typeof MosqueSchema>;

export const PrayerTimeSchema = z.object({
  date: z.number(),
  fajr: z.string(),
  shurooq: z.string(),
  dhuhr: z.string(),
  asr: z.string(),
  maghrib: z.string(),
  isha: z.string(),
});

export type PrayerTime = z.infer<typeof PrayerTimeSchema>;

export const IqamahTimeRangeSchema = z
  .object({
    date_range: z.string(),
    fajr: z.string(),
    dhuhr: z.string(),
    asr: z.string(),
    maghrib: z.string().nullable().optional(),
    isha: z.string(),
    jummah: z.string().nullable().optional(),
  })
  .transform((data) => ({
    dateRange: data.date_range,
    fajr: data.fajr,
    dhuhr: data.dhuhr,
    asr: data.asr,
    maghrib: data.maghrib ?? null,
    isha: data.isha,
    jummah: data.jummah ?? null,
  }));

export type IqamahTimeRange = z.infer<typeof IqamahTimeRangeSchema>;

export const MonthPrayerDataSchema = z
  .object({
    month: z.string(),
    prayer_times: z.array(PrayerTimeSchema),
    iqamah_times: z.array(IqamahTimeRangeSchema),
    jummah_iqamah: z.string(),
  })
  .transform((data) => ({
    month: data.month,
    prayerTimes: data.prayer_times,
    iqamahTimes: data.iqamah_times,
    jummahIqamah: data.jummah_iqamah,
  }));

export type MonthPrayerData = z.infer<typeof MonthPrayerDataSchema>;

export const RamadanPrayerDaySchema = z
  .object({
    ramadan_day: z.number(),
    gregorian: z.string(),
    fajr: z.string(),
    shurooq: z.string(),
    dhuhr: z.string(),
    asr: z.string(),
    maghrib: z.string(),
    isha: z.string(),
  })
  .transform((data) => ({
    ramadanDay: data.ramadan_day,
    gregorian: data.gregorian,
    fajr: data.fajr,
    shurooq: data.shurooq,
    dhuhr: data.dhuhr,
    asr: data.asr,
    maghrib: data.maghrib,
    isha: data.isha,
  }));

export type RamadanPrayerDay = z.infer<typeof RamadanPrayerDaySchema>;

export const RamadanPrayerDataSchema = z
  .object({
    month: z.string(),
    gregorian_start: z.string(),
    gregorian_end: z.string(),
    prayer_times: z.array(RamadanPrayerDaySchema),
    iqamah_times: z.array(IqamahTimeRangeSchema),
    jummah_iqamah: z.string(),
  })
  .transform((data) => ({
    month: data.month,
    gregorianStart: data.gregorian_start,
    gregorianEnd: data.gregorian_end,
    prayerTimes: data.prayer_times,
    iqamahTimes: data.iqamah_times,
    jummahIqamah: data.jummah_iqamah,
  }));

export type RamadanPrayerData = z.infer<typeof RamadanPrayerDataSchema>;

export interface DailyPrayerTimes {
  date: string;
  fajr: string;
  sunrise: string;
  dhuhr: string;
  asr: string;
  maghrib: string;
  isha: string;
}

export interface DailyIqamahTimes {
  fajr: string;
  dhuhr: string;
  asr: string;
  maghrib: string;
  isha: string;
  jummah: string;
}

export const UkDstYearSchema = z
  .object({
    year: z.number(),
    start_date: z.string(),
    end_date: z.string(),
  })
  .transform((data) => ({
    year: data.year,
    startDate: data.start_date,
    endDate: data.end_date,
  }));

export type UkDstYear = z.infer<typeof UkDstYearSchema>;

export const UkDstCalendarSchema = z
  .object({
    uk_dst_dates: z.array(UkDstYearSchema),
  })
  .transform((data) => ({
    ukDstDates: data.uk_dst_dates,
  }));

export type UkDstCalendar = z.infer<typeof UkDstCalendarSchema>;

export interface NextPrayerCountdownResult {
  nextName: string;
  nextTime: string;
  totalSeconds: number;
  isIqamah: boolean;
  isJummah: boolean;
  hours: number;
  minutes: number;
  seconds: number;
}

export type HeroCountdownLabelKind = "adhanIn" | "iqamahIn" | "nextPrayer";

export interface HeroCountdownPresentation {
  labelKind: HeroCountdownLabelKind;
  targetDate: Date;
  progressStartDate: Date;
}

export class PrayerEngineError extends Error {
  constructor(
    public readonly kind:
      | "noIqamahRange"
      | "missingMonthly"
      | "missingDayRow"
      | "missingRamadanRow",
    public readonly day?: number
  ) {
    super(
      kind === "noIqamahRange" && day !== undefined
        ? `No iqamah range found for day ${day}`
        : kind
    );
    this.name = "PrayerEngineError";
  }

  static noIqamahRange(day: number): PrayerEngineError {
    return new PrayerEngineError("noIqamahRange", day);
  }

  static missingMonthly(): PrayerEngineError {
    return new PrayerEngineError("missingMonthly");
  }

  static missingDayRow(): PrayerEngineError {
    return new PrayerEngineError("missingDayRow");
  }

  static missingRamadanRow(): PrayerEngineError {
    return new PrayerEngineError("missingRamadanRow");
  }
}
