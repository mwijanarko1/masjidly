import { Platform } from "react-native";
import {
  scheduleNotificationAsync,
  SchedulableTriggerInputTypes,
  getPermissionsAsync,
  requestPermissionsAsync,
  getAllScheduledNotificationsAsync,
  cancelScheduledNotificationAsync,
  setNotificationChannelAsync,
  AndroidImportance,
} from "@/lib/notifications/expoNotificationApi";

// Notification category identifiers (iOS parity with PrayerNotificationContent.CategoryID)
const CATEGORY_ADHAN = "masjidly.category.adhan";
const CATEGORY_IQAMAH = "masjidly.category.iqamah";
const CATEGORY_REMINDER = "masjidly.category.reminder";
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

const PRAYER_SCHEDULE_KEYS = {
  fajr: "fajr",
  dhuhrJummah: "dhuhr",
  asr: "asr",
  maghrib: "maghrib",
  isha: "isha",
} as const;

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

// ── iOS-matching notification content builders ──

/**
 * Capitalize first letter.
 */
function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/**
 * Prayer display name matching iOS PrayerNotificationContent.prayerDisplayName().
 * Uses "Jumu\u2019ah" for Friday dhuhr.
 */
function prayerDisplayName(prayer: string, isFriday: boolean): string {
  if (prayer === "dhuhr" && isFriday) return "Jumu\u2019ah";
  return capitalize(prayer);
}

/**
 * Compute the iOS-matching notification title & body from schedule data.
 */
function iOSNotificationContent(data: Record<string, string>, body: string): { title: string; body: string } {
  const kind = data.kind;
  const prayer = data.prayer ?? "";
  const isFriday = data.prayer === "jummah" || data.prayer === "jummah";

  switch (kind) {
    case "adhan": {
      // iOS: title = "Fajr Adhan", body = "Tap to hear adhan."
      const name = prayer === "jummah" ? "Jumu\u2019ah" : capitalize(prayer);
      return { title: `${name} Adhan`, body: "Tap to hear adhan." };
    }
    case "iqamah": {
      // iOS: title = "Fajr Iqamah", body = "Iqamah for Fajr is now."
      const name = prayer === "jummah" ? "Jumu\u2019ah" : capitalize(prayer);
      return { title: `${name} Iqamah`, body: `Iqamah for ${name} is now.` };
    }
    case "reminder": {
      const reminderFor = data.reminderFor ?? "adhan";
      const pName = capitalize(prayer);
      const minutes = data.reminderMinutes ? parseInt(data.reminderMinutes, 10) : 0;
      if (reminderFor === "iqamah") {
        // iOS: title = "Fajr Iqamah soon", body = "Iqamah in 10 min."
        return { title: `${pName} Iqamah soon`, body: `Iqamah in ${minutes} min.` };
      }
      // iOS: title = "Fajr soon", body = "Adhan in 10 min."
      return { title: `${pName} soon`, body: `Adhan in ${minutes} min.` };
    }
    default:
      return { title: body, body }; // Fallback
  }
}

async function scheduleIfNeeded(
  id: string,
  title: string,
  body: string,
  civilDay: Date,
  hhmm: string,
  data: Record<string, string>,
  categoryIdentifier?: string
): Promise<void> {
  const fire = triggerDate(civilDay, hhmm);
  if (!fire || fire.getTime() <= Date.now()) return;

  // Infer category from data.kind when not explicitly provided (iOS parity)
  const cat = categoryIdentifier ?? categoryIdForKind(data.kind);

  // iOS parity: auto-compute title & body from data.kind / data.prayer / data.reminderFor
  const ios = iOSNotificationContent(data, body);

  try {
    await scheduleNotificationAsync({
      identifier: id,
      content: {
        title: ios.title,
        body: ios.body,
        sound: true,
        data,
        ...(cat ? { categoryIdentifier: cat } : {}),
      },
      trigger: {
        type: SchedulableTriggerInputTypes.DATE,
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

/** Map notification kind to category identifier, matching iOS PrayerNotificationContent.registerCategories(). */
function categoryIdForKind(kind?: string): string | undefined {
  switch (kind) {
    case "adhan": return CATEGORY_ADHAN;
    case "iqamah": return CATEGORY_IQAMAH;
    case "reminder": return CATEGORY_REMINDER;
    default: return undefined;
  }
}

async function scheduleReminderIfNeeded(
  id: string,
  title: string,
  body: string,
  civilDay: Date,
  hhmm: string,
  minutesBefore: number,
  data: Record<string, string>,
  categoryIdentifier?: string
): Promise<void> {
  // Include reminder minutes in data so iOSNotificationContent can use it
  const dataWithMinutes = { ...data, reminderMinutes: String(minutesBefore) };
  const reminderTime = subtractMinutes(hhmm, minutesBefore);
  if (!reminderTime) return;
  await scheduleIfNeeded(id, title, body, civilDay, reminderTime, dataWithMinutes, categoryIdentifier);
}

function subtractMinutes(time: string, minutes: number): string | null {
  const p = time.split(":").map((s) => parseInt(s.trim(), 10));
  if (p.length !== 2 || Number.isNaN(p[0]) || Number.isNaN(p[1])) return null;
  const total = p[0] * 60 + p[1] - minutes;
  if (total < 0) return null;
  return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
}

export async function requestNotificationAuthorizationIfNeeded(): Promise<boolean> {
  const { status: existingStatus } = await getPermissionsAsync();
  if (existingStatus === "granted") return true;
  const { status } = await requestPermissionsAsync();
  return status === "granted";
}

export async function cancelAllPrayerNotifications(): Promise<void> {
  const pending = await getAllScheduledNotificationsAsync();
  const ids = pending
    .map((n) => n.identifier)
    .filter((id) => id.startsWith(IDENTIFIER_PREFIX));
  for (const id of ids) {
    await cancelScheduledNotificationAsync(id);
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
    try {
      await setNotificationChannelAsync(ANDROID_CHANNEL_ID, {
        name: "Prayer Times",
        importance: AndroidImportance.DEFAULT,
      });
    } catch {
      // Android Expo Go may not support notification channels; fail gracefully.
    }
  }

  const { adhanEnabled, iqamahEnabled } = settings;
  const reminderAdhan = settings.preAdhanReminderMinutes;
  const reminderIqamah = settings.preIqamahReminderMinutes;

  const isPrayerEnabled = (prayer: "fajr" | "dhuhrJummah" | "asr" | "maghrib" | "isha"): boolean =>
    settings[prayer] === true;

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

    // Fajr
    if (isPrayerEnabled("fajr")) {
      if (adhanEnabled) {
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.fajr.adhan`,
          mosque.name,
          translate("notification.fajr_adhan", locale),
          dayDate,
          displayed.fajr,
          { kind: "adhan", prayer: "fajr", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderAdhan != null && reminderAdhan > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.fajr.adhan.reminder`,
            mosque.name,
            translate("notification.reminder.adhan", locale),
            dayDate,
            displayed.fajr,
            reminderAdhan,
            { kind: "reminder", reminderFor: "adhan", prayer: "fajr", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
      if (iqamahEnabled) {
        const fajrIq = getIqamahTime("fajr", displayed.fajr, iq);
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.fajr.iqamah`,
          mosque.name,
          translate("notification.fajr_iqamah", locale),
          dayDate,
          fajrIq,
          { kind: "iqamah", prayer: "fajr", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderIqamah != null && reminderIqamah > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.fajr.iqamah.reminder`,
            mosque.name,
            translate("notification.reminder.iqamah", locale),
            dayDate,
            fajrIq,
            reminderIqamah,
            { kind: "reminder", reminderFor: "iqamah", prayer: "fajr", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
    }

    // Dhuhr / Jummah
    if (isPrayerEnabled("dhuhrJummah")) {
      const adhanKey = isFriday
        ? "notification.jummah_adhan"
        : "notification.dhuhr_adhan";
      if (adhanEnabled) {
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.dhuhr.adhan`,
          mosque.name,
          translate(adhanKey, locale),
          dayDate,
          displayed.dhuhr,
          { kind: "adhan", prayer: isFriday ? "jummah" : "dhuhr", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderAdhan != null && reminderAdhan > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.dhuhr.adhan.reminder`,
            mosque.name,
            translate("notification.reminder.adhan", locale),
            dayDate,
            displayed.dhuhr,
            reminderAdhan,
            { kind: "reminder", reminderFor: "adhan", prayer: isFriday ? "jummah" : "dhuhr", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
      if (iqamahEnabled) {
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
          iqLabel,
          { kind: "iqamah", prayer: iqIdPrayer, mosqueSlug: slug, isoDate: iso }
        );
        if (reminderIqamah != null && reminderIqamah > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.${iqIdPrayer}.iqamah.reminder`,
            mosque.name,
            translate("notification.reminder.iqamah", locale),
            dayDate,
            iqLabel,
            reminderIqamah,
            { kind: "reminder", reminderFor: "iqamah", prayer: iqIdPrayer, mosqueSlug: slug, isoDate: iso }
          );
        }
      }
    }

    // Asr
    if (isPrayerEnabled("asr")) {
      if (adhanEnabled) {
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.asr.adhan`,
          mosque.name,
          translate("notification.asr_adhan", locale),
          dayDate,
          displayed.asr,
          { kind: "adhan", prayer: "asr", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderAdhan != null && reminderAdhan > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.asr.adhan.reminder`,
            mosque.name,
            translate("notification.reminder.adhan", locale),
            dayDate,
            displayed.asr,
            reminderAdhan,
            { kind: "reminder", reminderFor: "adhan", prayer: "asr", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
      if (iqamahEnabled) {
        const asrIq = getIqamahTime("asr", displayed.asr, iq);
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.asr.iqamah`,
          mosque.name,
          translate("notification.asr_iqamah", locale),
          dayDate,
          asrIq,
          { kind: "iqamah", prayer: "asr", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderIqamah != null && reminderIqamah > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.asr.iqamah.reminder`,
            mosque.name,
            translate("notification.reminder.iqamah", locale),
            dayDate,
            asrIq,
            reminderIqamah,
            { kind: "reminder", reminderFor: "iqamah", prayer: "asr", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
    }

    // Maghrib
    if (isPrayerEnabled("maghrib")) {
      if (adhanEnabled) {
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.maghrib.adhan`,
          mosque.name,
          translate("notification.maghrib_adhan", locale),
          dayDate,
          displayed.maghrib,
          { kind: "adhan", prayer: "maghrib", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderAdhan != null && reminderAdhan > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.maghrib.adhan.reminder`,
            mosque.name,
            translate("notification.reminder.adhan", locale),
            dayDate,
            displayed.maghrib,
            reminderAdhan,
            { kind: "reminder", reminderFor: "adhan", prayer: "maghrib", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
      if (iqamahEnabled) {
        const maghribIq = getIqamahTime("maghrib", displayed.maghrib, iq);
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.maghrib.iqamah`,
          mosque.name,
          translate("notification.maghrib_iqamah", locale),
          dayDate,
          maghribIq,
          { kind: "iqamah", prayer: "maghrib", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderIqamah != null && reminderIqamah > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.maghrib.iqamah.reminder`,
            mosque.name,
            translate("notification.reminder.iqamah", locale),
            dayDate,
            maghribIq,
            reminderIqamah,
            { kind: "reminder", reminderFor: "iqamah", prayer: "maghrib", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
    }

    // Isha
    if (isPrayerEnabled("isha")) {
      if (adhanEnabled) {
        await scheduleIfNeeded(
          `${IDENTIFIER_PREFIX}${slug}.${iso}.isha.adhan`,
          mosque.name,
          translate("notification.isha_adhan", locale),
          dayDate,
          displayed.isha,
          { kind: "adhan", prayer: "isha", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderAdhan != null && reminderAdhan > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.isha.adhan.reminder`,
            mosque.name,
            translate("notification.reminder.adhan", locale),
            dayDate,
            displayed.isha,
            reminderAdhan,
            { kind: "reminder", reminderFor: "adhan", prayer: "isha", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
      if (iqamahEnabled) {
        const ishaIq = resolveIshaIqamahForDisplay(
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
          ishaIq,
          { kind: "iqamah", prayer: "isha", mosqueSlug: slug, isoDate: iso }
        );
        if (reminderIqamah != null && reminderIqamah > 0) {
          await scheduleReminderIfNeeded(
            `${IDENTIFIER_PREFIX}${slug}.${iso}.isha.iqamah.reminder`,
            mosque.name,
            translate("notification.reminder.iqamah", locale),
            dayDate,
            ishaIq,
            reminderIqamah,
            { kind: "reminder", reminderFor: "iqamah", prayer: "isha", mosqueSlug: slug, isoDate: iso }
          );
        }
      }
    }
  }
}
