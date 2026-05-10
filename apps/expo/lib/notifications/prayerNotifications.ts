import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import {
  getDateInSheffield,
  isoDateString,
  resolvePrayerTimes,
  getDisplayedPrayerTimes,
  resolveIqamahTimesWithDstMapping,
  getIqamahTime,
  resolveIshaIqamahForDisplay,
  SHEFFIELD_TIME_ZONE,
} from "@/lib/prayer/prayerTimesEngine";
import { monthNameFromNumber } from "@/lib/prayer/monthName";
import { t, type TranslationKey } from "@/lib/i18n/translations";
import type { Mosque, DailyPrayerTimes, DailyIqamahTimes } from "@/types/prayer";
import type { NotificationSettings } from "@/store/settings";

const IDENTIFIER_PREFIX = "masjidly.prayer.";
const ANDROID_CHANNEL_ID = "prayer-times";

function translate(key: TranslationKey, locale: string): string {
  return t(key, locale as "en" | "ar" | "ur");
}

function dateInSheffield(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number
): Date {
  const utcCandidate = Date.UTC(year, month - 1, day, hour, minute, 0);
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: SHEFFIELD_TIME_ZONE,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    second: "numeric",
    hour12: false,
  }).formatToParts(new Date(utcCandidate));

  const getPart = (type: string) =>
    parseInt(parts.find((p) => p.type === type)?.value ?? "0", 10);

  const sy = getPart("year");
  const sm = getPart("month");
  const sd = getPart("day");
  const sh = getPart("hour");
  const smin = getPart("minute");
  const ss = getPart("second");

  const targetUtc = Date.UTC(sy, sm - 1, sd, sh, smin, ss);
  const offset = utcCandidate - targetUtc;
  return new Date(utcCandidate + offset);
}

function triggerDate(civilDay: Date, hhmm: string): Date | null {
  const p = hhmm.split(":").map((s) => parseInt(s.trim(), 10));
  if (p.length !== 2 || Number.isNaN(p[0]) || Number.isNaN(p[1])) return null;
  if (p[0] < 0 || p[0] >= 24 || p[1] < 0 || p[1] >= 60) return null;

  const { year, month, day } = getDateInSheffield(civilDay);
  return dateInSheffield(year, month, day, p[0], p[1]);
}

async function scheduleIfNeeded(
  id: string,
  title: string,
  body: string,
  civilDay: Date,
  hhmm: string
): Promise<void> {
  const fire = triggerDate(civilDay, hhmm);
  if (!fire || fire.getTime() <= Date.now()) return;

  try {
    await Notifications.scheduleNotificationAsync({
      identifier: id,
      content: {
        title,
        body,
        sound: true,
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DATE,
        date: fire,
        ...(Platform.OS === "android"
          ? { channelId: ANDROID_CHANNEL_ID }
          : {}),
      },
    });
  } catch {
    // Ignore scheduling errors, matching Swift behavior
  }
}

export async function requestNotificationAuthorizationIfNeeded(): Promise<boolean> {
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  if (existingStatus === "granted") return true;
  const { status } = await Notifications.requestPermissionsAsync();
  return status === "granted";
}

export async function cancelAllPrayerNotifications(): Promise<void> {
  const pending = await Notifications.getAllScheduledNotificationsAsync();
  const ids = pending
    .map((n) => n.identifier)
    .filter((id) => id.startsWith(IDENTIFIER_PREFIX));
  for (const id of ids) {
    await Notifications.cancelScheduledNotificationAsync(id);
  }
}

export async function rescheduleUpcomingPrayerNotifications(input: {
  mosque: Mosque;
  days?: number;
  settings: NotificationSettings;
  locale: string;
}): Promise<void> {
  const { mosque, days = 7, settings, locale } = input;

  await cancelAllPrayerNotifications();
  if (!settings.masterEnabled) return;

  const granted = await requestNotificationAuthorizationIfNeeded();
  if (!granted) return;

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync(ANDROID_CHANNEL_ID, {
      name: "Prayer Times",
      importance: Notifications.AndroidImportance.DEFAULT,
    });
  }

  const ukDst = (await prayerRepository.getUkDstDates())?.ukDstDates ?? [];
  const slug = mosque.slug;

  const { year: y0, month: m0, day: d0 } = getDateInSheffield(new Date());
  const baseDay = dateInSheffield(y0, m0, d0, 0, 0);

  for (let offset = 0; offset < Math.max(1, days); offset++) {
    const dayDate = new Date(baseDay.getTime() + offset * 24 * 60 * 60 * 1000);
    const comps = getDateInSheffield(dayDate);
    const iso = isoDateString(comps.year, comps.month, comps.day);
    const monthName = monthNameFromNumber(comps.month);
    if (!monthName) continue;

    const monthly = await prayerRepository.getMonthlyPrayerTimes(
      slug,
      monthName,
      comps.year
    );
    const ramadan = await prayerRepository.getRamadanTimetable(slug, iso);

    let displayed: DailyPrayerTimes;
    let iq: DailyIqamahTimes;
    try {
      const raw = resolvePrayerTimes(slug, dayDate, monthly, ramadan, ukDst);
      displayed = getDisplayedPrayerTimes(raw, dayDate, slug);
      iq = resolveIqamahTimesWithDstMapping(
        slug,
        dayDate,
        monthly,
        ramadan,
        ukDst
      );
    } catch {
      continue;
    }

    const wdParts = new Intl.DateTimeFormat("en-GB", {
      timeZone: SHEFFIELD_TIME_ZONE,
      weekday: "short",
    }).formatToParts(dayDate);
    const wdStr =
      wdParts.find((p) => p.type === "weekday")?.value?.toLowerCase() ?? "";
    const isFriday = wdStr === "fri";

    if (settings.fajr) {
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.fajr.adhan`,
        mosque.name,
        translate("notification.fajr_adhan", locale),
        dayDate,
        displayed.fajr
      );
      const iqT = getIqamahTime("fajr", displayed.fajr, iq);
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.fajr.iqamah`,
        mosque.name,
        translate("notification.fajr_iqamah", locale),
        dayDate,
        iqT
      );
    }

    if (settings.dhuhrJummah) {
      const adhanKey = isFriday
        ? "notification.jummah_adhan"
        : "notification.dhuhr_adhan";
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.dhuhr.adhan`,
        mosque.name,
        translate(adhanKey, locale),
        dayDate,
        displayed.dhuhr
      );
      const iqLabel = isFriday
        ? iq.jummah
        : getIqamahTime("dhuhr", displayed.dhuhr, iq);
      const iqBodyKey = isFriday
        ? "notification.jummah"
        : "notification.dhuhr_iqamah";
      const iqIdPrayer = isFriday ? "jummah" : "dhuhr";
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.${iqIdPrayer}.iqamah`,
        mosque.name,
        translate(iqBodyKey, locale),
        dayDate,
        iqLabel
      );
    }

    if (settings.asr) {
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.asr.adhan`,
        mosque.name,
        translate("notification.asr_adhan", locale),
        dayDate,
        displayed.asr
      );
      const iqT = getIqamahTime("asr", displayed.asr, iq);
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.asr.iqamah`,
        mosque.name,
        translate("notification.asr_iqamah", locale),
        dayDate,
        iqT
      );
    }

    if (settings.maghrib) {
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.maghrib.adhan`,
        mosque.name,
        translate("notification.maghrib_adhan", locale),
        dayDate,
        displayed.maghrib
      );
      const iqT = getIqamahTime("maghrib", displayed.maghrib, iq);
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.maghrib.iqamah`,
        mosque.name,
        translate("notification.maghrib_iqamah", locale),
        dayDate,
        iqT
      );
    }

    if (settings.isha) {
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.isha.adhan`,
        mosque.name,
        translate("notification.isha_adhan", locale),
        dayDate,
        displayed.isha
      );
      const iqT = resolveIshaIqamahForDisplay(
        slug,
        dayDate,
        displayed.isha,
        iq,
        displayed.maghrib
      );
      await scheduleIfNeeded(
        `${IDENTIFIER_PREFIX}${slug}.${iso}.isha.iqamah`,
        mosque.name,
        translate("notification.isha_iqamah", locale),
        dayDate,
        iqT
      );
    }
  }
}
