import type {
  DailyIqamahTimes,
  DailyPrayerTimes,
  IqamahTimeRange,
  MonthPrayerData,
  NextPrayerCountdownResult,
  PrayerTime,
  RamadanPrayerData,
  RamadanPrayerDay,
  UkDstYear,
} from "@/types/prayer";
import { PrayerEngineError } from "@/types/prayer";

export const SHEFFIELD_TIME_ZONE = "Europe/London";
const RISALAH_SLUG = "masjid-risalah";
const DST_MOSQUE_SLUGS = new Set<string>(["masjid-al-huda-sheffield"]);

export function getDateInSheffield(date: Date): { year: number; month: number; day: number } {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: SHEFFIELD_TIME_ZONE,
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(date);
  const getPart = (type: string) => {
    const p = parts.find((x) => x.type === type);
    return p ? parseInt(p.value, 10) : 0;
  };
  return { year: getPart("year"), month: getPart("month"), day: getPart("day") };
}

export function sheffieldNoonUTC(year: number, month: number, day: number): Date {
  return new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
}

/** Weekday for a civil calendar day in Europe/London (matches iOS TimetableView `isFriday`). */
export function isFridaySheffieldCalendar(
  year: number,
  month: number,
  dayOfMonth: number
): boolean {
  const anchor = new Date(Date.UTC(year, month - 1, dayOfMonth, 12, 0, 0));
  const wd = new Intl.DateTimeFormat("en-GB", {
    timeZone: SHEFFIELD_TIME_ZONE,
    weekday: "short",
  }).format(anchor);
  return wd.toLowerCase().startsWith("f");
}

/** Current time as `HH:mm` in Europe/London for comparing with timetable adhān strings. */
export function formatSystemHHMMSheffield(now: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: SHEFFIELD_TIME_ZONE,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(now);
  const h = parts.find((p) => p.type === "hour")?.value ?? "00";
  const m = parts.find((p) => p.type === "minute")?.value ?? "00";
  return `${h.padStart(2, "0")}:${m.padStart(2, "0")}`;
}

export function isoDateString(year: number, month: number, day: number): string {
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

export function normalizeMosqueSlug(slug: string): string {
  return slug.trim().toLowerCase();
}

export function isMasjidRisalah(slug: string): boolean {
  return normalizeMosqueSlug(slug) === RISALAH_SLUG;
}

export function mosqueTimetableAlreadyIncludesDst(slug: string): boolean {
  return DST_MOSQUE_SLUGS.has(normalizeMosqueSlug(slug));
}

export function findDayData(prayerTimes: PrayerTime[], dayOfMonth: number): PrayerTime | null {
  let closestPrevious: PrayerTime | null = null;
  let earliest: PrayerTime | null = null;
  for (const day of prayerTimes) {
    if (earliest === null || day.date < earliest.date) earliest = day;
    if (day.date === dayOfMonth) return day;
    if (day.date <= dayOfMonth) {
      if (closestPrevious === null || day.date > closestPrevious.date) closestPrevious = day;
    }
  }
  return closestPrevious ?? earliest;
}

export function findRamadanDayData(
  prayerTimes: RamadanPrayerDay[],
  ramadanDay: number
): RamadanPrayerDay | null {
  let closestPrevious: RamadanPrayerDay | null = null;
  let earliest: RamadanPrayerDay | null = null;
  for (const day of prayerTimes) {
    if (earliest === null || day.ramadanDay < earliest.ramadanDay) earliest = day;
    if (day.ramadanDay === ramadanDay) return day;
    if (day.ramadanDay <= ramadanDay) {
      if (closestPrevious === null || day.ramadanDay > closestPrevious.ramadanDay) closestPrevious = day;
    }
  }
  return closestPrevious ?? earliest;
}

export function getIqamahTimesForDate(
  dayOfMonth: number,
  iqamahRanges: IqamahTimeRange[]
): DailyIqamahTimes {
  for (const range of iqamahRanges) {
    const parts = range.dateRange
      .split("-")
      .map((s) => s.trim())
      .map((s) => parseInt(s, 10))
      .filter((n) => !Number.isNaN(n));
    const start = parts[0];
    if (Number.isNaN(start)) continue;
    const end = parts.length > 1 ? parts[1] : null;
    if (end === null) {
      if (dayOfMonth === start) return dailyFromRange(range);
    } else if (dayOfMonth >= start && dayOfMonth <= end) {
      return dailyFromRange(range);
    }
  }
  throw PrayerEngineError.noIqamahRange(dayOfMonth);
}

function dailyFromRange(range: IqamahTimeRange): DailyIqamahTimes {
  return {
    fajr: range.fajr,
    dhuhr: range.dhuhr,
    asr: range.asr,
    maghrib: range.maghrib ?? "sunset",
    isha: range.isha,
    jummah: range.jummah?.trim() ?? "",
  };
}

export function isSummerIshaPeriod(date: Date): boolean {
  const { year } = getDateInSheffield(date);
  const may15 = sheffieldNoonUTC(year, 5, 15);
  const aug15 = sheffieldNoonUTC(year, 8, 15);
  return date.getTime() >= may15.getTime() && date.getTime() <= aug15.getTime();
}

export function isRisalahIshaIqamahMatchesAdhanPeriod(date: Date): boolean {
  const { year } = getDateInSheffield(date);
  const may1 = sheffieldNoonUTC(year, 5, 1);
  const july31 = sheffieldNoonUTC(year, 7, 31);
  return date.getTime() >= may1.getTime() && date.getTime() <= july31.getTime();
}

export function resolveIshaIqamahForDisplay(
  slug: string,
  date: Date,
  ishaAdhan: string,
  iqamahTimes: DailyIqamahTimes,
  maghribAdhan: string
): string {
  if (isMasjidRisalah(slug) && isRisalahIshaIqamahMatchesAdhanPeriod(date)) {
    return ishaAdhan;
  }
  if (isSummerIshaPeriod(date)) {
    return "After Maghrib";
  }
  return getIqamahTime("isha", ishaAdhan, iqamahTimes, maghribAdhan);
}

export function getIqamahTime(
  prayer: string,
  adhanTime: string,
  iqamahTimes: DailyIqamahTimes,
  maghribAdhan?: string | null
): string {
  const p = prayer.toLowerCase();
  switch (p) {
    case "fajr": {
      const raw = iqamahTimes.fajr === "Various" ? adhanTime : iqamahTimes.fajr;
      return resolveRelativeIqamah(raw, adhanTime);
    }
    case "dhuhr":
      return resolveRelativeIqamah(iqamahTimes.dhuhr, adhanTime);
    case "asr": {
      if (iqamahTimes.asr.trim().toLowerCase() === "entry time") return adhanTime;
      return resolveRelativeIqamah(iqamahTimes.asr, adhanTime);
    }
    case "maghrib": {
      const raw = iqamahTimes.maghrib === "sunset" ? adhanTime : iqamahTimes.maghrib;
      return resolveRelativeIqamah(raw, adhanTime);
    }
    case "isha": {
      if (iqamahTimes.isha === "Straight after Maghrib") {
        if (maghribAdhan != null) return maghribAdhan;
        return adhanTime;
      }
      if (iqamahTimes.isha === "Entry Time") return adhanTime;
      return resolveRelativeIqamah(iqamahTimes.isha, adhanTime);
    }
    case "jummah":
      return iqamahTimes.jummah;
    default:
      return "-";
  }
}

function addMinutesToTime(time: string, minutesToAdd: number): string | null {
  const parts = time.split(":").map((s) => parseInt(s.trim(), 10));
  if (parts.length !== 2 || Number.isNaN(parts[0]) || Number.isNaN(parts[1])) return null;
  const total = (((parts[0] * 60 + parts[1] + minutesToAdd) % 1440) + 1440) % 1440;
  const h = Math.floor(total / 60);
  const m = total % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

export function resolveRelativeIqamah(iqamahValue: string, adhanTime: string): string {
  const value = iqamahValue.trim();
  const adhanPlusMatch = value.match(/^adhan\s*\+\s*(\d+)\s*(?:mins?|minutes?)?$/i);
  if (adhanPlusMatch) {
    const mins = parseInt(adhanPlusMatch[1], 10);
    if (!Number.isNaN(mins)) return addMinutesToTime(adhanTime, mins) ?? iqamahValue;
  }
  const afterAdhanMatch = value.match(/^(\d+)\s*(?:mins?|minutes?)\s*after\s*adhan$/i);
  if (afterAdhanMatch) {
    const mins = parseInt(afterAdhanMatch[1], 10);
    if (!Number.isNaN(mins)) return addMinutesToTime(adhanTime, mins) ?? iqamahValue;
  }
  return iqamahValue;
}

function dhuhrToMinutes(t: PrayerTime): number | null {
  const parts = t.dhuhr.split(":").map((s) => parseInt(s.trim(), 10));
  if (parts.length !== 2 || Number.isNaN(parts[0]) || Number.isNaN(parts[1])) return null;
  return parts[0] * 60 + parts[1];
}

export function detectMarchSummerStartDayInTable(prayerTimes: PrayerTime[]): number | null {
  const sorted = [...prayerTimes].sort((a, b) => a.date - b.date);
  let bestDay: number | null = null;
  let bestJump = 0;
  for (let i = 1; i < sorted.length; i++) {
    const a = dhuhrToMinutes(sorted[i - 1]);
    const b = dhuhrToMinutes(sorted[i]);
    if (a === null || b === null) continue;
    const jump = b - a;
    if (jump > bestJump) {
      bestJump = jump;
      bestDay = sorted[i].date;
    }
  }
  return bestJump >= 45 ? bestDay : null;
}

export function detectOctoberWinterStartDayInTable(prayerTimes: PrayerTime[]): number | null {
  const sorted = [...prayerTimes].sort((a, b) => a.date - b.date);
  let bestDay: number | null = null;
  let bestFall = 0;
  for (let i = 1; i < sorted.length; i++) {
    const a = dhuhrToMinutes(sorted[i - 1]);
    const b = dhuhrToMinutes(sorted[i]);
    if (a === null || b === null) continue;
    const fall = a - b;
    if (fall > bestFall) {
      bestFall = fall;
      bestDay = sorted[i].date;
    }
  }
  return bestFall >= 45 ? bestDay : null;
}

export function resolveTimetableDayForUkEmbeddedDst(
  calendarDay: number,
  transitionDayInTable: number,
  ukTransitionDay: number,
  maxTableDay: number
): number {
  const t = transitionDayInTable;
  const u = ukTransitionDay;
  if (t === u) return calendarDay;
  const low = Math.min(t, u);
  const high = Math.max(t, u) - 1;
  if (calendarDay < low || calendarDay > high) return calendarDay;
  return Math.min(maxTableDay, Math.max(1, calendarDay + (t - u)));
}

function maxPrayerTableDay(prayerTimes: PrayerTime[], year: number, month: number): number {
  const m = Math.max(0, ...(prayerTimes.map((p) => p.date)));
  if (m > 0) return m;
  return new Date(year, month, 0).getDate();
}

function getLastSundayOfMonth(year: number, month: number): number {
  const lastDay = new Date(Date.UTC(year, month, 0));
  const wd = lastDay.getUTCDay();
  const last = lastDay.getUTCDate();
  const offset = (wd - 0 + 7) % 7;
  return last - offset;
}

export function getUkMarchSpringForwardDay(year: number, dstDates: UkDstYear[]): number {
  const row = dstDates.find((d) => d.year === year);
  if (row) {
    const seg = row.startDate.split("-");
    if (seg.length === 3) {
      const mo = parseInt(seg[1], 10);
      const d = parseInt(seg[2], 10);
      if (mo === 3 && d >= 1 && d <= 31) return d;
    }
  }
  return getLastSundayOfMonth(year, 3);
}

export function resolveEmbeddedDstTimetableDayOfMonth(
  slug: string,
  month: number,
  year: number,
  calendarDay: number,
  prayerTimes: PrayerTime[],
  dstDates: UkDstYear[]
): number {
  if (!mosqueTimetableAlreadyIncludesDst(slug) || (month !== 3 && month !== 10)) {
    return calendarDay;
  }
  const maxDay = maxPrayerTableDay(prayerTimes, year, month);
  if (month === 3) {
    const t = detectMarchSummerStartDayInTable(prayerTimes);
    if (t === null) return calendarDay;
    const u = getUkMarchSpringForwardDay(year, dstDates);
    return resolveTimetableDayForUkEmbeddedDst(calendarDay, t, u, maxDay);
  }
  const t = detectOctoberWinterStartDayInTable(prayerTimes);
  if (t === null) return calendarDay;
  let u = getLastSundayOfMonth(year, 10);
  const row = dstDates.find((d) => d.year === year);
  if (row) {
    const seg = row.endDate.split("-");
    if (seg.length === 3) {
      const mo = parseInt(seg[1], 10);
      const d = parseInt(seg[2], 10);
      if (mo === 10 && d >= 1 && d <= 31) u = d;
    }
  }
  return resolveTimetableDayForUkEmbeddedDst(calendarDay, t, u, maxDay);
}

export function resolveMonthlyDayDisplay(
  slug: string,
  year: number,
  month: number,
  calendarDay: number,
  monthlyData: MonthPrayerData,
  dstDates: UkDstYear[]
): { adhan: PrayerTime; iqamahLookupDay: number } | null {
  const iqamahLookupDay = resolveEmbeddedDstTimetableDayOfMonth(
    slug, month, year, calendarDay, monthlyData.prayerTimes, dstDates
  );
  const adhan = findDayData(monthlyData.prayerTimes, iqamahLookupDay);
  if (!adhan) return null;
  return { adhan, iqamahLookupDay };
}

function buildMasjidRisalahMarchIqamahTimes(springForwardMarchDay: number): IqamahTimeRange[] {
  const maghrib = "5 mins after adhan";
  const fajrLate = "20 minutes after adhan";
  const d = Math.min(31, Math.max(1, springForwardMarchDay));
  const rows: IqamahTimeRange[] = [
    { dateRange: "1-10", fajr: "05:30", dhuhr: "12:45", asr: "15:30", maghrib, isha: "19:45", jummah: null },
    { dateRange: "11-20", fajr: "05:15", dhuhr: "12:45", asr: "15:45", maghrib, isha: "20:00", jummah: null },
  ];
  if (d > 21) {
    rows.push({ dateRange: `21-${d - 1}`, fajr: fajrLate, dhuhr: "12:45", asr: "16:00", maghrib, isha: "20:30", jummah: null });
  }
  rows.push({ dateRange: `${d}-31`, fajr: fajrLate, dhuhr: "13:30", asr: "17:00", maghrib, isha: "21:30", jummah: null });
  return rows;
}

export function applyMasjidRisalahMarchIqamahIfNeeded(
  slug: string,
  monthNum: number,
  year: number,
  data: MonthPrayerData,
  dstDates: UkDstYear[]
): MonthPrayerData {
  if (normalizeMosqueSlug(slug) !== RISALAH_SLUG || monthNum !== 3) return data;
  const spring = getUkMarchSpringForwardDay(year, dstDates);
  return {
    month: data.month,
    prayerTimes: data.prayerTimes,
    iqamahTimes: buildMasjidRisalahMarchIqamahTimes(spring),
    jummahIqamah: data.jummahIqamah,
  };
}

export function isDateWithinRamadanRange(date: Date, ramadan: RamadanPrayerData): boolean {
  const { year, month, day } = getDateInSheffield(date);
  const dateStr = isoDateString(year, month, day);
  return dateStr >= ramadan.gregorianStart && dateStr <= ramadan.gregorianEnd;
}

export function getRamadanDay(date: Date, ramadan: RamadanPrayerData): number {
  const { year, month, day } = getDateInSheffield(date);
  const start = sheffieldNoonUTCFromISO(ramadan.gregorianStart);
  const dateAtNoon = sheffieldNoonUTC(year, month, day);
  const diffMs = dateAtNoon.getTime() - start.getTime();
  const diffDays = Math.floor(diffMs / 86400000);
  return Math.min(30, Math.max(1, diffDays + 1));
}

function sheffieldNoonUTCFromISO(yyyyMMdd: string): Date {
  const parts = yyyyMMdd.split("-").map((s) => parseInt(s.trim(), 10));
  if (parts.length !== 3 || parts.some((n) => Number.isNaN(n))) return new Date();
  return sheffieldNoonUTC(parts[0], parts[1], parts[2]);
}

export function isInDSTAdjustmentPeriod(date: Date, dstDates: UkDstYear[]): boolean {
  const { year: y } = getDateInSheffield(date);
  const row = dstDates.find((d) => d.year === y);
  if (!row) return false;
  const start = parseISODate(row.startDate);
  const end = parseISODate(row.endDate);
  const checkMonth = parseInt(
    new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, month: "numeric" })
      .formatToParts(date).find((p) => p.type === "month")?.value ?? "0",
    10
  );
  const checkDay = parseInt(
    new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, day: "numeric" })
      .formatToParts(date).find((p) => p.type === "day")?.value ?? "0",
    10
  );
  if (checkMonth === 10) {
    const endY = parseInt(
      new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, year: "numeric" })
        .formatToParts(end).find((p) => p.type === "year")?.value ?? "0",
      10
    );
    const endM = parseInt(
      new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, month: "numeric" })
        .formatToParts(end).find((p) => p.type === "month")?.value ?? "0",
      10
    );
    const endD = parseInt(
      new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, day: "numeric" })
        .formatToParts(end).find((p) => p.type === "day")?.value ?? "0",
      10
    );
    const isAfter = y > endY || (y === endY && checkMonth > endM) || (y === endY && checkMonth === endM && checkDay >= endD);
    return isAfter && checkMonth === 10;
  }
  if (checkMonth === 3) {
    const sY = parseInt(
      new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, year: "numeric" })
        .formatToParts(start).find((p) => p.type === "year")?.value ?? "0",
      10
    );
    const sM = parseInt(
      new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, month: "numeric" })
        .formatToParts(start).find((p) => p.type === "month")?.value ?? "0",
      10
    );
    const sD = parseInt(
      new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, day: "numeric" })
        .formatToParts(start).find((p) => p.type === "day")?.value ?? "0",
      10
    );
    const isAfter = y > sY || (y === sY && checkMonth > sM) || (y === sY && checkMonth === sM && checkDay >= sD);
    return isAfter && checkMonth === 3;
  }
  return false;
}

function parseISODate(s: string): Date {
  const p = s.split("-").map((x) => parseInt(x.trim(), 10));
  if (p.length !== 3 || p.some((n) => Number.isNaN(n))) return new Date();
  return sheffieldNoonUTC(p[0], p[1], p[2]);
}

export function getDSTAdjustmentIqamahDate(
  date: Date,
  dstDates: UkDstYear[]
): { month: number; day: number } | null {
  const { year, month: checkMonth, day: checkDay } = getDateInSheffield(date);
  const anchor = sheffieldNoonUTC(year, checkMonth, checkDay);
  if (!isInDSTAdjustmentPeriod(anchor, dstDates)) return null;
  const yearData = dstDates.find((d) => d.year === year);
  if (!yearData) return null;
  const dstStartDay = parseInt(yearData.startDate.slice(-2), 10) || 0;
  const dstEndDay = parseInt(yearData.endDate.slice(-2), 10) || 0;
  if (checkMonth === 10) {
    const dayOffset = checkDay - dstEndDay;
    if (dayOffset >= 0) {
      const novemberDate = Math.min(dayOffset + 1, 30);
      return { month: 11, day: novemberDate };
    }
  }
  if (checkMonth === 3) {
    const dayOffset = checkDay - dstStartDay;
    if (dayOffset >= 0) {
      const aprilDate = Math.min(dayOffset + 1, 30);
      return { month: 4, day: aprilDate };
    }
  }
  return null;
}

function isInOctoberTransition(date: Date): boolean {
  const m = parseInt(
    new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, month: "numeric" })
      .formatToParts(date).find((p) => p.type === "month")?.value ?? "0",
    10
  );
  const d = parseInt(
    new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, day: "numeric" })
      .formatToParts(date).find((p) => p.type === "day")?.value ?? "0",
    10
  );
  return m === 10 && d >= 22;
}

function isInMarchTransition(date: Date): boolean {
  const m = parseInt(
    new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, month: "numeric" })
      .formatToParts(date).find((p) => p.type === "month")?.value ?? "0",
    10
  );
  const d = parseInt(
    new Intl.DateTimeFormat("en-GB", { timeZone: SHEFFIELD_TIME_ZONE, day: "numeric" })
      .formatToParts(date).find((p) => p.type === "day")?.value ?? "0",
    10
  );
  return m === 3 && d >= 21;
}

function subtractOneHour(time: string): string {
  const p = time.split(":").map((s) => parseInt(s.trim(), 10));
  if (p.length !== 2 || Number.isNaN(p[0]) || Number.isNaN(p[1])) return time;
  let h = p[0] - 1;
  if (h < 0) h = 23;
  return `${String(h).padStart(2, "0")}:${String(p[1]).padStart(2, "0")}`;
}

function addOneHour(time: string): string {
  const p = time.split(":").map((s) => parseInt(s.trim(), 10));
  if (p.length !== 2 || Number.isNaN(p[0]) || Number.isNaN(p[1])) return time;
  let h = p[0] + 1;
  if (h >= 24) h = 0;
  return `${String(h).padStart(2, "0")}:${String(p[1]).padStart(2, "0")}`;
}

function adjustPrayerTimeForDSTSync(time: string, date: Date): string {
  if (isInOctoberTransition(date)) return subtractOneHour(time);
  if (isInMarchTransition(date)) return addOneHour(time);
  return time;
}

export function isInDSTAdjustmentPeriodSync(date: Date): boolean {
  return isInOctoberTransition(date) || isInMarchTransition(date);
}

export function getDisplayedPrayerTimes(
  prayerTimes: DailyPrayerTimes,
  date: Date,
  mosqueSlug: string
): DailyPrayerTimes {
  if (mosqueTimetableAlreadyIncludesDst(mosqueSlug)) return prayerTimes;
  if (!isInDSTAdjustmentPeriodSync(date)) return prayerTimes;
  return {
    date: prayerTimes.date,
    fajr: adjustPrayerTimeForDSTSync(prayerTimes.fajr, date),
    sunrise: adjustPrayerTimeForDSTSync(prayerTimes.sunrise, date),
    dhuhr: adjustPrayerTimeForDSTSync(prayerTimes.dhuhr, date),
    asr: adjustPrayerTimeForDSTSync(prayerTimes.asr, date),
    maghrib: adjustPrayerTimeForDSTSync(prayerTimes.maghrib, date),
    isha: adjustPrayerTimeForDSTSync(prayerTimes.isha, date),
  };
}

export function resolvePrayerTimes(
  slug: string,
  on: Date,
  monthly: MonthPrayerData | null | undefined,
  ramadan: RamadanPrayerData | null | undefined,
  ukDst: UkDstYear[]
): DailyPrayerTimes {
  const { year: y, month: m, day: d } = getDateInSheffield(on);
  const dateStr = isoDateString(y, m, d);
  if (ramadan && isDateWithinRamadanRange(on, ramadan)) {
    const ramadanDay = getRamadanDay(on, ramadan);
    const row = findRamadanDayData(ramadan.prayerTimes, ramadanDay);
    if (!row) throw PrayerEngineError.missingRamadanRow();
    return {
      date: dateStr,
      fajr: row.fajr,
      sunrise: row.shurooq,
      dhuhr: row.dhuhr,
      asr: row.asr,
      maghrib: row.maghrib,
      isha: row.isha,
    };
  }
  if (!monthly) throw PrayerEngineError.missingMonthly();
  const adjustedMonthly = applyMasjidRisalahMarchIqamahIfNeeded(slug, m, y, monthly, ukDst);
  const resolved = resolveMonthlyDayDisplay(slug, y, m, d, adjustedMonthly, ukDst);
  if (!resolved) throw PrayerEngineError.missingDayRow();
  const adhan = resolved.adhan;
  return {
    date: dateStr,
    fajr: adhan.fajr,
    sunrise: adhan.shurooq,
    dhuhr: adhan.dhuhr,
    asr: adhan.asr,
    maghrib: adhan.maghrib,
    isha: adhan.isha,
  };
}

export function resolveIqamahTimes(
  slug: string,
  on: Date,
  monthly: MonthPrayerData | null | undefined,
  ramadan: RamadanPrayerData | null | undefined,
  ukDst: UkDstYear[]
): DailyIqamahTimes {
  const { year: y, month: m, day: d } = getDateInSheffield(on);
  if (ramadan && isDateWithinRamadanRange(on, ramadan)) {
    const ramadanDay = getRamadanDay(on, ramadan);
    const iq = getIqamahTimesForDate(ramadanDay, ramadan.iqamahTimes);
    const j = iq.jummah.trim().length === 0 ? ramadan.jummahIqamah : iq.jummah;
    return { fajr: iq.fajr, dhuhr: iq.dhuhr, asr: iq.asr, maghrib: iq.maghrib, isha: iq.isha, jummah: j };
  }
  if (!monthly) throw PrayerEngineError.missingMonthly();
  const adjustedMonthly = applyMasjidRisalahMarchIqamahIfNeeded(slug, m, y, monthly, ukDst);
  const resolved = resolveMonthlyDayDisplay(slug, y, m, d, adjustedMonthly, ukDst);
  if (!resolved) throw PrayerEngineError.missingDayRow();
  const iq = getIqamahTimesForDate(resolved.iqamahLookupDay, adjustedMonthly.iqamahTimes);
  const j = iq.jummah.trim().length === 0 ? adjustedMonthly.jummahIqamah : iq.jummah;
  return { fajr: iq.fajr, dhuhr: iq.dhuhr, asr: iq.asr, maghrib: iq.maghrib, isha: iq.isha, jummah: j };
}

export function resolveIqamahTimesWithDstMapping(
  slug: string,
  on: Date,
  monthly: MonthPrayerData | null | undefined,
  ramadan: RamadanPrayerData | null | undefined,
  ukDst: UkDstYear[]
): DailyIqamahTimes {
  if (mosqueTimetableAlreadyIncludesDst(slug)) {
    return resolveIqamahTimes(slug, on, monthly, ramadan, ukDst);
  }
  const mapped = getDSTAdjustmentIqamahDate(on, ukDst);
  if (mapped) {
    const { year: y } = getDateInSheffield(on);
    const adj = sheffieldNoonUTC(y, mapped.month, mapped.day);
    return resolveIqamahTimes(slug, adj, monthly, ramadan, ukDst);
  }
  return resolveIqamahTimes(slug, on, monthly, ramadan, ukDst);
}

export function getNextPrayerAndCountdown(
  prayerTimes: DailyPrayerTimes,
  iqamahTimes: DailyIqamahTimes,
  mosqueSlug: string,
  now: Date = new Date()
): NextPrayerCountdownResult {
  const dayStartParts = new Intl.DateTimeFormat("en-GB", {
    timeZone: SHEFFIELD_TIME_ZONE,
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(now);
  const getPart = (type: string) => {
    const p = dayStartParts.find((x) => x.type === type);
    return p ? parseInt(p.value, 10) : 0;
  };
  const dsYear = getPart("year");
  const dsMonth = getPart("month");
  const dsDay = getPart("day");

  const weekday = new Intl.DateTimeFormat("en-GB", {
    timeZone: SHEFFIELD_TIME_ZONE,
    weekday: "short",
  })
    .format(now)
    .toLowerCase();
  const isFriday = weekday === "fri";
  const checkDate = new Date(dsYear, dsMonth - 1, dsDay, 12, 0, 0);

  function wallClockToday(hhmm: string): Date | null {
    const p = hhmm.split(":").map((s) => parseInt(s.trim(), 10));
    if (p.length !== 2 || Number.isNaN(p[0]) || Number.isNaN(p[1])) return null;
    return new Date(dsYear, dsMonth - 1, dsDay, p[0], p[1], 0);
  }

  const slug = mosqueSlug;

  const prayers = [
    {
      name: "Fajr",
      adhan: prayerTimes.fajr,
      iqamah: getIqamahTime("fajr", prayerTimes.fajr, iqamahTimes),
    },
    {
      name: isFriday ? "Jummah" : "Dhuhr",
      adhan: prayerTimes.dhuhr,
      iqamah: isFriday ? iqamahTimes.jummah : getIqamahTime("dhuhr", prayerTimes.dhuhr, iqamahTimes),
    },
    {
      name: "Asr",
      adhan: prayerTimes.asr,
      iqamah: getIqamahTime("asr", prayerTimes.asr, iqamahTimes),
    },
    {
      name: "Maghrib",
      adhan: prayerTimes.maghrib,
      iqamah: getIqamahTime("maghrib", prayerTimes.maghrib, iqamahTimes),
    },
    {
      name: "Isha",
      adhan: prayerTimes.isha,
      iqamah: resolveIshaIqamahForDisplay(slug, checkDate, prayerTimes.isha, iqamahTimes, prayerTimes.maghrib),
    },
  ];

  for (const prayer of prayers) {
    const isJummah = prayer.name === "Jummah";
    if (!isJummah) {
      const adhanT = wallClockToday(prayer.adhan);
      if (adhanT && adhanT.getTime() > now.getTime()) {
        const diff = Math.floor((adhanT.getTime() - now.getTime()) / 1000);
        return {
          nextName: prayer.name,
          nextTime: prayer.adhan,
          totalSeconds: diff,
          isIqamah: false,
          isJummah: false,
          hours: Math.floor(diff / 3600),
          minutes: Math.floor((diff % 3600) / 60),
          seconds: diff % 60,
        };
      }
    }
    if (isParseableTime(prayer.iqamah) && prayer.iqamah !== prayer.adhan) {
      const iqT = wallClockToday(prayer.iqamah);
      if (iqT && iqT.getTime() > now.getTime()) {
        const diff = Math.floor((iqT.getTime() - now.getTime()) / 1000);
        return {
          nextName: prayer.name,
          nextTime: prayer.iqamah,
          totalSeconds: diff,
          isIqamah: true,
          isJummah,
          hours: Math.floor(diff / 3600),
          minutes: Math.floor((diff % 3600) / 60),
          seconds: diff % 60,
        };
      }
    }
  }

  const fajrT = wallClockToday(prayers[0].adhan);
  if (fajrT) {
    const tomorrow = new Date(dsYear, dsMonth - 1, dsDay + 1);
    const nextFajr = new Date(
      tomorrow.getFullYear(),
      tomorrow.getMonth(),
      tomorrow.getDate(),
      fajrT.getHours(),
      fajrT.getMinutes(),
      0
    );
    const diff = Math.floor((nextFajr.getTime() - now.getTime()) / 1000);
    return {
      nextName: "Fajr",
      nextTime: prayers[0].adhan,
      totalSeconds: Math.max(0, diff),
      isIqamah: false,
      isJummah: false,
      hours: Math.floor(Math.max(0, diff) / 3600),
      minutes: Math.floor((Math.max(0, diff) % 3600) / 60),
      seconds: Math.max(0, diff) % 60,
    };
  }

  return {
    nextName: "Fajr",
    nextTime: prayers[0].adhan,
    totalSeconds: 0,
    isIqamah: false,
    isJummah: false,
    hours: 0,
    minutes: 0,
    seconds: 0,
  };
}

function isParseableTime(t: string): boolean {
  if (t === "" || t === "-" || t === "\u2014" || t === "--:--") return false;
  if (/after maghrib|entry time|straight after/i.test(t)) return false;
  return /^\d{1,2}:\d{2}$/.test(t.trim());
}

/** Localized clock for `HH:mm` data (digits, separators, AM/PM). */
export function formatPrayerClockForDisplay(
  timeString: string,
  uses24h: boolean,
  locale: string
): string {
  if (!isParseableTime(timeString)) return timeString;
  const m = /^(\d{1,2}):(\d{2})$/.exec(timeString.trim());
  if (!m) return timeString;
  const hour = parseInt(m[1], 10);
  const minute = parseInt(m[2], 10);
  const d = new Date(2000, 5, 15, hour, minute, 0, 0);
  const opts: Intl.DateTimeFormatOptions = {
    hour: "numeric",
    minute: "2-digit",
    hour12: !uses24h,
  };
  if (locale.startsWith("ar")) {
    (opts as { numberingSystem?: string }).numberingSystem = "arab";
  }
  return new Intl.DateTimeFormat(locale, opts).format(d);
}

/**
 * Splits a prayer time into hero clock and optional meridiem.
 * For 12-hour locales this returns ("h:mm", "AM/PM") so the meridiem can be
 * rendered tightly beside the clock. For 24-hour or unparseable times the
 * meridiem is null.
 */
export function formatPrayerTimeHeroParts(
  timeString: string,
  uses24h: boolean,
  locale: string
): { clock: string; meridiem: string | null } {
  if (!isParseableTime(timeString)) {
    return { clock: timeString, meridiem: null };
  }
  const m = /^(\d{1,2}):(\d{2})$/.exec(timeString.trim());
  if (!m) {
    return { clock: timeString, meridiem: null };
  }
  const hour = parseInt(m[1], 10);
  const minute = parseInt(m[2], 10);
  const d = new Date(2000, 5, 15, hour, minute, 0, 0);

  if (uses24h) {
    const opts: Intl.DateTimeFormatOptions = {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    };
    if (locale.startsWith("ar")) {
      (opts as { numberingSystem?: string }).numberingSystem = "arab";
    }
    const clock = new Intl.DateTimeFormat(locale, opts).format(d);
    return { clock, meridiem: null };
  }

  const parts = new Intl.DateTimeFormat(locale, {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).formatToParts(d);

  const clock = parts
    .filter((p) => p.type !== "dayPeriod")
    .map((p) => p.value)
    .join("")
    .trim();

  const meridiemPart = parts.find((p) => p.type === "dayPeriod");
  const meridiem = meridiemPart ? meridiemPart.value : null;

  return { clock, meridiem };
}

export function formatTo12Hour(timeString: string): string {
  if (!isParseableTime(timeString)) return timeString;
  const p = timeString.split(":").map((s) => parseInt(s.trim(), 10));
  if (p.length !== 2 || Number.isNaN(p[0]) || Number.isNaN(p[1])) return timeString;
  const ampm = p[0] >= 12 ? "pm" : "am";
  const h12 = p[0] % 12 === 0 ? 12 : p[0] % 12;
  return `${h12}:${String(p[1]).padStart(2, "0")}${ampm}`;
}
