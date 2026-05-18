import { NativeModules, Platform } from "react-native";
import type {
  DailyIqamahTimes,
  DailyPrayerTimes,
  MonthPrayerData,
  Mosque,
  RamadanPrayerData,
  UkDstYear,
} from "@/types/prayer";
import {
  getDateInSheffield,
  getDisplayedPrayerTimes,
  isoDateString,
  resolveIqamahTimesWithDstMapping,
  resolvePrayerTimes,
  sheffieldNoonUTC,
} from "@/lib/prayer/prayerTimesEngine";
import type { AppLanguage } from "@/store/settings";


interface AndroidPrayerWidgetModule {
  saveSnapshot: (json: string) => Promise<boolean>;
  refreshWidgets: () => Promise<boolean>;
}

const nativePrayerWidget = NativeModules.MasjidlyPrayerWidget as
  | AndroidPrayerWidgetModule
  | undefined;

interface WidgetDaySnapshot {
  date: string;
  prayers: DailyPrayerTimes;
  iqamah: DailyIqamahTimes;
}

interface WidgetSnapshot {
  schemaVersion: 1;
  generatedAt: string;
  mosque: Pick<Mosque, "id" | "name" | "slug">;
  days: WidgetDaySnapshot[];
  uses24HourTime: boolean;
  appLanguageRawValue: AppLanguage;
}

function dateByAddingDaysInSheffield(base: Date, offsetDays: number): Date {
  const { year, month, day } = getDateInSheffield(base);
  return sheffieldNoonUTC(year, month, day + offsetDays);
}

export async function updateAndroidPrayerWidgetSnapshot(params: {
  mosque: Mosque | null;
  monthData: MonthPrayerData | null;
  ramadanData: RamadanPrayerData | null;
  ukDst: UkDstYear[];
  uses24HourTime: boolean;
  appLanguage: AppLanguage;
  now?: Date;
}): Promise<void> {
  if (Platform.OS !== "android" || !nativePrayerWidget || !params.mosque) {
    return;
  }

  const now = params.now ?? new Date();
  const days: WidgetDaySnapshot[] = [];

  for (let offset = 0; offset < 7; offset += 1) {
    const date = dateByAddingDaysInSheffield(now, offset);
    try {
      const prayerTimes = resolvePrayerTimes(
        params.mosque.slug,
        date,
        params.monthData ?? undefined,
        params.ramadanData ?? undefined,
        params.ukDst
      );
      const iqamah = resolveIqamahTimesWithDstMapping(
        params.mosque.slug,
        date,
        params.monthData ?? undefined,
        params.ramadanData ?? undefined,
        params.ukDst
      );
      const { year, month, day } = getDateInSheffield(date);
      days.push({
        date: isoDateString(year, month, day),
        prayers: getDisplayedPrayerTimes(prayerTimes, date, params.mosque.slug),
        iqamah,
      });
    } catch (error) {
      if (__DEV__) {
        console.warn("[PrayerWidget] Skipping widget day", offset, error);
      }
    }
  }

  if (days.length === 0) {
    return;
  }

  const snapshot: WidgetSnapshot = {
    schemaVersion: 1,
    generatedAt: now.toISOString(),
    mosque: {
      id: params.mosque.id,
      name: params.mosque.name,
      slug: params.mosque.slug,
    },
    days,
    uses24HourTime: params.uses24HourTime,
    appLanguageRawValue: params.appLanguage,
  };

  await nativePrayerWidget.saveSnapshot(JSON.stringify(snapshot));
}
