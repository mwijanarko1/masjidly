import { z } from "zod";
import {
  MosqueSchema,
  MonthPrayerDataSchema,
  RamadanPrayerDataSchema,
  UkDstCalendarSchema,
} from "@/types/prayer";
import type {
  Mosque,
  MonthPrayerData,
  RamadanPrayerData,
  UkDstCalendar,
} from "@/types/prayer";
import type { MonthName } from "@/lib/prayer/monthName";

const PREFIX = "masjidly:prayer-cache";

const cacheKey = {
  mosques: `${PREFIX}:mosques`,
  ukDst: `${PREFIX}:uk-dst`,
  monthly: (slug: string, month: MonthName, year: number) =>
    `${PREFIX}:monthly:${safe(slug)}:${month}:${year}`,
  ramadan: (slug: string, date?: string) =>
    `${PREFIX}:ramadan:${safe(slug)}:${safe(date ?? "latest")}`,
};

const CamelMosqueSchema = z.object({
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
  isHiddenResolved: z.boolean().optional(),
});

const CamelPrayerTimeSchema = z.object({
  date: z.number(),
  fajr: z.string(),
  shurooq: z.string(),
  dhuhr: z.string(),
  asr: z.string(),
  asrMithl2: z.string().optional(),
  maghrib: z.string(),
  isha: z.string(),
});

const CamelIqamahTimeRangeSchema = z.object({
  dateRange: z.string(),
  fajr: z.string(),
  dhuhr: z.string(),
  asr: z.string(),
  maghrib: z.string().nullable().optional(),
  isha: z.string(),
  jummah: z.string().nullable().optional(),
});

const CamelMonthPrayerDataSchema = z.object({
  month: z.string(),
  prayerTimes: z.array(CamelPrayerTimeSchema),
  iqamahTimes: z.array(CamelIqamahTimeRangeSchema),
  jummahIqamah: z.string(),
});

const CamelRamadanPrayerDaySchema = z.object({
  ramadanDay: z.number(),
  gregorian: z.string(),
  fajr: z.string(),
  shurooq: z.string(),
  dhuhr: z.string(),
  asr: z.string(),
  maghrib: z.string(),
  isha: z.string(),
});

const CamelRamadanPrayerDataSchema = z.object({
  month: z.string(),
  gregorianStart: z.string(),
  gregorianEnd: z.string(),
  prayerTimes: z.array(CamelRamadanPrayerDaySchema),
  iqamahTimes: z.array(CamelIqamahTimeRangeSchema),
  jummahIqamah: z.string(),
});

const CamelUkDstYearSchema = z.object({
  year: z.number(),
  startDate: z.string(),
  endDate: z.string(),
});

const CamelUkDstCalendarSchema = z.object({
  ukDstDates: z.array(CamelUkDstYearSchema),
});

function safe(value: string): string {
  return encodeURIComponent(value.replace(/[/.\\]/g, "_"));
}

const memoryStore = new Map<string, string>();

type StorageLike = {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem?(key: string): Promise<void>;
};

function getStorage(): StorageLike {
  try {
    // Lazily require so Jest tests without an AsyncStorage mock do not crash at module import time.
    // eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
    const module = require("@react-native-async-storage/async-storage") as { default?: StorageLike } & StorageLike;
    return module.default ?? module;
  } catch {
    return {
      getItem: async (key) => memoryStore.get(key) ?? null,
      setItem: async (key, value) => {
        memoryStore.set(key, value);
      },
      removeItem: async (key) => {
        memoryStore.delete(key);
      },
    };
  }
}

async function loadValue<T>(key: string, parse: (value: unknown) => T | null): Promise<T | null> {
  try {
    const raw = await getStorage().getItem(key);
    if (!raw) return null;
    return parse(JSON.parse(raw));
  } catch {
    return null;
  }
}

async function saveValue<T>(key: string, value: T): Promise<void> {
  try {
    await getStorage().setItem(key, JSON.stringify(value));
  } catch {
    // Cache writes are best-effort only.
  }
}

async function removeValue(key: string): Promise<void> {
  try {
    const storage = getStorage();
    if (storage.removeItem) {
      await storage.removeItem(key);
    } else {
      memoryStore.delete(key);
    }
  } catch {
    // Cache removals are best-effort only.
  }
}

function parseMosques(value: unknown): Mosque[] | null {
  const raw = z.array(MosqueSchema).safeParse(value);
  if (raw.success) return raw.data;
  const camel = z.array(CamelMosqueSchema).safeParse(value);
  if (!camel.success) return null;
  return camel.data.map((m) => ({
    ...m,
    citySlug: m.citySlug ?? "sheffield",
    cityName: m.cityName ?? "Sheffield",
    countryCode: m.countryCode ?? "GB",
    countryName: m.countryName ?? "United Kingdom",
    timezone: m.timezone ?? "Europe/London",
    isHiddenResolved: m.isHiddenResolved ?? m.isHidden ?? false,
  }));
}

function parseMonth(value: unknown): MonthPrayerData | null {
  const raw = MonthPrayerDataSchema.safeParse(value);
  if (raw.success) return raw.data;
  const camel = CamelMonthPrayerDataSchema.safeParse(value);
  return camel.success ? camel.data : null;
}

function parseRamadan(value: unknown): RamadanPrayerData | null {
  const raw = RamadanPrayerDataSchema.safeParse(value);
  if (raw.success) return raw.data;
  const camel = CamelRamadanPrayerDataSchema.safeParse(value);
  return camel.success ? camel.data : null;
}

function parseUkDst(value: unknown): UkDstCalendar | null {
  const raw = UkDstCalendarSchema.safeParse(value);
  if (raw.success) return raw.data;
  const camel = CamelUkDstCalendarSchema.safeParse(value);
  return camel.success ? camel.data : null;
}

export const prayerTimesCache = {
  loadMosques: () => loadValue(cacheKey.mosques, parseMosques),
  saveMosques: (mosques: Mosque[]) => saveValue(cacheKey.mosques, mosques),

  loadUkDst: () => loadValue(cacheKey.ukDst, parseUkDst),
  saveUkDst: (dst: UkDstCalendar) => saveValue(cacheKey.ukDst, dst),

  loadMonthly: (slug: string, month: MonthName, year: number) =>
    loadValue(cacheKey.monthly(slug, month, year), parseMonth),
  saveMonthly: (slug: string, month: MonthName, year: number, data: MonthPrayerData) =>
    saveValue(cacheKey.monthly(slug, month, year), data),
  removeMonthly: (slug: string, month: MonthName, year: number) =>
    removeValue(cacheKey.monthly(slug, month, year)),

  loadRamadan: (slug: string, date?: string) =>
    loadValue(cacheKey.ramadan(slug, date), parseRamadan),
  saveRamadan: (slug: string, date: string | undefined, data: RamadanPrayerData) =>
    saveValue(cacheKey.ramadan(slug, date), data),
};
