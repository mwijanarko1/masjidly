import { z } from "zod";
import { convexClient } from "@/lib/convex/client";
import { anyApi } from "convex/server";
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

export interface PrayerRepository {
  listMosques(): Promise<Mosque[]>;
  getMonthlyPrayerTimes(
    mosqueSlug: string,
    month: MonthName,
    year: number
  ): Promise<MonthPrayerData | null>;
  getRamadanTimetable(
    mosqueSlug: string,
    date?: string
  ): Promise<RamadanPrayerData | null>;
  getUkDstDates(): Promise<UkDstCalendar | null>;
}

class ConvexPrayerRepository implements PrayerRepository {
  async listMosques(): Promise<Mosque[]> {
    const result = await convexClient.query(anyApi.mosques.list, {});
    return z.array(MosqueSchema).parse(result);
  }

  async getMonthlyPrayerTimes(
    mosqueSlug: string,
    month: MonthName,
    year: number
  ): Promise<MonthPrayerData | null> {
    const result = await convexClient.query(anyApi.prayerTimes.getMonthly, {
      mosqueSlug,
      month,
      year,
    });
    if (result == null) return null;
    return MonthPrayerDataSchema.parse(result);
  }

  async getRamadanTimetable(
    mosqueSlug: string,
    date?: string
  ): Promise<RamadanPrayerData | null> {
    const result = await convexClient.query(anyApi.prayerTimes.getRamadan, {
      mosqueSlug,
      ...(date && { date }),
    });
    if (result == null) return null;
    return RamadanPrayerDataSchema.parse(result);
  }

  async getUkDstDates(): Promise<UkDstCalendar | null> {
    const result = await convexClient.query(
      anyApi.prayerTimes.getUkDstDates,
      {}
    );
    if (result == null) return null;
    return UkDstCalendarSchema.parse(result);
  }
}

export const prayerRepository: PrayerRepository = new ConvexPrayerRepository();
