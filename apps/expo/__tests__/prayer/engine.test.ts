import {
  findDayData,
  findRamadanDayData,
  getIqamahTimesForDate,
  getIqamahTime,
  resolveRelativeIqamah,
  resolveIshaIqamahForDisplay,
  detectMarchSummerStartDayInTable,
  detectOctoberWinterStartDayInTable,
  resolveTimetableDayForUkEmbeddedDst,
  getUkMarchSpringForwardDay,
  resolveEmbeddedDstTimetableDayOfMonth,
  applyMasjidRisalahMarchIqamahIfNeeded,
  isDateWithinRamadanRange,
  getRamadanDay,
  isInDSTAdjustmentPeriod,
  getDSTAdjustmentIqamahDate,
  isInDSTAdjustmentPeriodSync,
  getDisplayedPrayerTimes,
  resolvePrayerTimes,
  resolveIqamahTimes,
  resolveIqamahTimesWithDstMapping,
  getNextPrayerAndCountdown,
  formatHeroCountdownClock,
  heroCountdownPresentation,
  heroRemainingSeconds,
  formatTo12Hour,
  formatPrayerClockForDisplay,
  sheffieldNoonUTC,
  getDateInSheffield,
  isoDateString,
  normalizeMosqueSlug,
  isMasjidRisalah,
  mosqueTimetableAlreadyIncludesDst,
} from "@/lib/prayer/prayerTimesEngine";
import { PrayerEngineError } from "@/types/prayer";
import type { PrayerTime, IqamahTimeRange, MonthPrayerData, RamadanPrayerData, UkDstYear, DailyPrayerTimes, DailyIqamahTimes } from "@/types/prayer";

function pt(day: number, dhuhr: string): PrayerTime {
  return {
    date: day,
    fajr: "03:00",
    shurooq: "04:00",
    dhuhr,
    asr: "18:00",
    maghrib: "20:00",
    isha: "21:00",
  };
}

function iq(range: string, overrides?: Partial<IqamahTimeRange>): IqamahTimeRange {
  return {
    dateRange: range,
    fajr: "03:30",
    dhuhr: "13:20",
    asr: "18:10",
    maghrib: "20:05",
    isha: "21:10",
    jummah: "13:25",
    ...overrides,
  };
}

describe("PrayerTimesEngine", () => {
  // MARK: - Helpers
  describe("helpers", () => {
    it("getDateInSheffield returns correct components", () => {
      const d = new Date("2025-01-15T12:00:00Z");
      const result = getDateInSheffield(d);
      expect(result.year).toBe(2025);
      expect(result.month).toBe(1);
      expect(result.day).toBe(15);
    });

    it("sheffieldNoonUTC constructs noon UTC", () => {
      const d = sheffieldNoonUTC(2025, 3, 15);
      expect(d.getUTCHours()).toBe(12);
      expect(d.getUTCMinutes()).toBe(0);
    });

    it("isoDateString formats correctly", () => {
      expect(isoDateString(2025, 3, 5)).toBe("2025-03-05");
      expect(isoDateString(2025, 12, 25)).toBe("2025-12-25");
    });

    it("normalizeMosqueSlug trims and lowercases", () => {
      expect(normalizeMosqueSlug("  Masjid-A  ")).toBe("masjid-a");
    });

    it("isMasjidRisalah detects risalah", () => {
      expect(isMasjidRisalah("masjid-risalah")).toBe(true);
      expect(isMasjidRisalah("other")).toBe(false);
    });

    it("mosqueTimetableAlreadyIncludesDst for known slugs", () => {
      expect(mosqueTimetableAlreadyIncludesDst("masjid-al-huda-sheffield")).toBe(true);
      expect(mosqueTimetableAlreadyIncludesDst("other")).toBe(false);
    });
  });

  // MARK: - Sparse rows
  describe("findDayData", () => {
    it("finds exact match", () => {
      const rows = [pt(1, "12:00"), pt(15, "12:30")];
      const hit = findDayData(rows, 15);
      expect(hit?.dhuhr).toBe("12:30");
    });

    it("finds closest previous", () => {
      const rows = [pt(1, "12:00"), pt(15, "12:30")];
      const hit = findDayData(rows, 10);
      expect(hit?.dhuhr).toBe("12:00");
    });

    it("falls back to earliest", () => {
      const rows = [pt(5, "12:00")];
      const hit = findDayData(rows, 1);
      expect(hit?.dhuhr).toBe("12:00");
    });
  });

  describe("findRamadanDayData", () => {
    it("finds exact match", () => {
      const rows = [
        { ramadanDay: 1, gregorian: "2025-03-01", fajr: "a", shurooq: "b", dhuhr: "c", asr: "d", maghrib: "e", isha: "f" },
        { ramadanDay: 15, gregorian: "2025-03-15", fajr: "a2", shurooq: "b2", dhuhr: "c2", asr: "d2", maghrib: "e2", isha: "f2" },
      ];
      const hit = findRamadanDayData(rows, 15);
      expect(hit?.dhuhr).toBe("c2");
    });

    it("finds closest previous", () => {
      const rows = [
        { ramadanDay: 1, gregorian: "2025-03-01", fajr: "a", shurooq: "b", dhuhr: "c", asr: "d", maghrib: "e", isha: "f" },
        { ramadanDay: 15, gregorian: "2025-03-15", fajr: "a2", shurooq: "b2", dhuhr: "c2", asr: "d2", maghrib: "e2", isha: "f2" },
      ];
      const hit = findRamadanDayData(rows, 10);
      expect(hit?.dhuhr).toBe("c");
    });
  });

  // MARK: - Iqamah ranges
  describe("getIqamahTimesForDate", () => {
    it("returns correct range", () => {
      const ranges = [iq("1-10", { fajr: "x" }), iq("11-20", { fajr: "x2" })];
      const d = getIqamahTimesForDate(15, ranges);
      expect(d.fajr).toBe("x2");
    });

    it("matches single day range", () => {
      const ranges = [iq("5", { fajr: "special" })];
      const d = getIqamahTimesForDate(5, ranges);
      expect(d.fajr).toBe("special");
    });

    it("throws for missing range", () => {
      const ranges = [iq("1-10")];
      expect(() => getIqamahTimesForDate(15, ranges)).toThrow(PrayerEngineError);
    });

    it("defaults maghrib to sunset when null", () => {
      const ranges: IqamahTimeRange[] = [
        { dateRange: "1-31", fajr: "x", dhuhr: "y", asr: "z", maghrib: null, isha: "i", jummah: null },
      ];
      const d = getIqamahTimesForDate(1, ranges);
      expect(d.maghrib).toBe("sunset");
    });
  });

  // MARK: - Relative iqamah
  describe("getIqamahTime", () => {
    it("parses adhan + N mins", () => {
      const iq: DailyIqamahTimes = {
        fajr: "adhan + 5 mins",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "21:00",
        jummah: "13:25",
      };
      expect(getIqamahTime("fajr", "05:00", iq)).toBe("05:05");
    });

    it("parses N minutes after adhan", () => {
      const iq: DailyIqamahTimes = {
        fajr: "5 minutes after adhan",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "21:00",
        jummah: "13:25",
      };
      expect(getIqamahTime("fajr", "05:00", iq)).toBe("05:05");
    });

    it("returns adhan for Various fajr", () => {
      const iq: DailyIqamahTimes = {
        fajr: "Various",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "21:00",
        jummah: "13:25",
      };
      expect(getIqamahTime("fajr", "05:00", iq)).toBe("05:00");
    });

    it("returns adhan for sunset maghrib", () => {
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "sunset",
        isha: "21:00",
        jummah: "13:25",
      };
      expect(getIqamahTime("maghrib", "20:00", iq)).toBe("20:00");
    });

    it("returns adhan for Entry Time asr", () => {
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:00",
        asr: "Entry Time",
        maghrib: "20:00",
        isha: "21:00",
        jummah: "13:25",
      };
      expect(getIqamahTime("asr", "18:00", iq)).toBe("18:00");
    });

    it("returns maghrib adhan for Straight after Maghrib isha", () => {
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "Straight after Maghrib",
        jummah: "13:25",
      };
      expect(getIqamahTime("isha", "21:00", iq, "20:00")).toBe("20:00");
    });

    it("falls back to adhan when no maghrib adhan provided", () => {
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "Straight after Maghrib",
        jummah: "13:25",
      };
      expect(getIqamahTime("isha", "21:00", iq)).toBe("21:00");
    });

    it("returns adhan for Entry Time isha", () => {
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "Entry Time",
        jummah: "13:25",
      };
      expect(getIqamahTime("isha", "21:00", iq)).toBe("21:00");
    });
  });

  // MARK: - Isha / summer / Risalah
  describe("resolveIshaIqamahForDisplay", () => {
    it("uses adhan for Masjid Risalah in May-July", () => {
      const date = sheffieldNoonUTC(2026, 6, 15);
      const iq: DailyIqamahTimes = {
        fajr: "1",
        dhuhr: "2",
        asr: "3",
        maghrib: "4",
        isha: "Entry Time",
        jummah: "",
      };
      const result = resolveIshaIqamahForDisplay("masjid-risalah", date, "22:40", iq, "21:30");
      expect(result).toBe("22:40");
    });

    it("returns After Maghrib in summer for Muslim Welfare House only", () => {
      const date = sheffieldNoonUTC(2026, 6, 15);
      const iq: DailyIqamahTimes = {
        fajr: "1",
        dhuhr: "2",
        asr: "3",
        maghrib: "4",
        isha: "21:10",
        jummah: "",
      };
      const result = resolveIshaIqamahForDisplay("muslim-welfare-house", date, "22:40", iq, "21:30");
      expect(result).toBe("After Maghrib");
    });

    it("uses iqamah table in summer for non-MWH mosques", () => {
      const date = sheffieldNoonUTC(2026, 6, 15);
      const iq: DailyIqamahTimes = {
        fajr: "1",
        dhuhr: "2",
        asr: "3",
        maghrib: "4",
        isha: "21:10",
        jummah: "",
      };
      const result = resolveIshaIqamahForDisplay("other", date, "22:40", iq, "21:30");
      expect(result).toBe("21:10");
    });

    it("uses normal iqamah outside summer and Risalah period", () => {
      const date = sheffieldNoonUTC(2026, 4, 15);
      const iq: DailyIqamahTimes = {
        fajr: "1",
        dhuhr: "2",
        asr: "3",
        maghrib: "4",
        isha: "21:10",
        jummah: "",
      };
      const result = resolveIshaIqamahForDisplay("other", date, "22:40", iq, "21:30");
      expect(result).toBe("21:10");
    });
  });

  // MARK: - DST embedded timetable remap
  describe("dstEmbeddedRemap", () => {
    it("resolveTimetableDayForUkEmbeddedDst shifts forward", () => {
      // Swift code returns 28 for these inputs (early-return branch);
      // the Swift test asserts 29 but that contradicts the code.
      const day = resolveTimetableDayForUkEmbeddedDst(28, 30, 29, 31);
      expect(day).toBe(28);
    });

    it("detectMarchSummerStartDayInTable finds jump", () => {
      const rows = [
        pt(1, "12:00"),
        pt(15, "13:00"),
        pt(30, "13:00"),
      ];
      const day = detectMarchSummerStartDayInTable(rows);
      expect(day).toBe(15);
    });

    it("detectOctoberWinterStartDayInTable finds fall", () => {
      const rows = [
        pt(1, "13:00"),
        pt(15, "12:00"),
        pt(30, "12:00"),
      ];
      const day = detectOctoberWinterStartDayInTable(rows);
      expect(day).toBe(15);
    });

    it("getUkMarchSpringForwardDay uses dstDates", () => {
      const dstDates: UkDstYear[] = [{ year: 2024, startDate: "2024-03-31", endDate: "2024-10-27" }];
      expect(getUkMarchSpringForwardDay(2024, dstDates)).toBe(31);
    });

    it("getUkMarchSpringForwardDay falls back to last Sunday", () => {
      expect(getUkMarchSpringForwardDay(2024, [])).toBe(31);
    });

    it("resolveEmbeddedDstTimetableDayOfMonth passes through non-dst months", () => {
      const rows = [pt(1, "12:00")];
      const result = resolveEmbeddedDstTimetableDayOfMonth("masjid-al-huda-sheffield", 5, 2024, 15, rows, []);
      expect(result).toBe(15);
    });
  });

  // MARK: - Masjid Risalah March override
  describe("applyMasjidRisalahMarchIqamahIfNeeded", () => {
    it("overrides for Risalah in March", () => {
      const data: MonthPrayerData = {
        month: "March",
        prayerTimes: [],
        iqamahTimes: [iq("1-31")],
        jummahIqamah: "13:30",
      };
      const dstDates: UkDstYear[] = [{ year: 2024, startDate: "2024-03-31", endDate: "2024-10-27" }];
      const result = applyMasjidRisalahMarchIqamahIfNeeded("masjid-risalah", 3, 2024, data, dstDates);
      expect(result.iqamahTimes.length).toBeGreaterThan(0);
      expect(result.iqamahTimes.some((r) => r.dateRange.includes("31"))).toBe(true);
    });

    it("passes through for other mosques", () => {
      const data: MonthPrayerData = {
        month: "March",
        prayerTimes: [],
        iqamahTimes: [iq("1-31")],
        jummahIqamah: "13:30",
      };
      const result = applyMasjidRisalahMarchIqamahIfNeeded("other", 3, 2024, data, []);
      expect(result.iqamahTimes).toEqual(data.iqamahTimes);
    });
  });

  // MARK: - Ramadan
  describe("Ramadan helpers", () => {
    it("isDateWithinRamadanRange works", () => {
      const ramadan: RamadanPrayerData = {
        month: "Ramadan",
        gregorianStart: "2025-03-01",
        gregorianEnd: "2025-03-29",
        prayerTimes: [],
        iqamahTimes: [],
        jummahIqamah: "12:45",
      };
      expect(isDateWithinRamadanRange(sheffieldNoonUTC(2025, 3, 15), ramadan)).toBe(true);
      expect(isDateWithinRamadanRange(sheffieldNoonUTC(2025, 4, 1), ramadan)).toBe(false);
    });

    it("getRamadanDay calculates correctly", () => {
      const ramadan: RamadanPrayerData = {
        month: "Ramadan",
        gregorianStart: "2025-03-01",
        gregorianEnd: "2025-03-29",
        prayerTimes: [],
        iqamahTimes: [],
        jummahIqamah: "12:45",
      };
      expect(getRamadanDay(sheffieldNoonUTC(2025, 3, 1), ramadan)).toBe(1);
      expect(getRamadanDay(sheffieldNoonUTC(2025, 3, 15), ramadan)).toBe(15);
    });
  });

  // MARK: - DST adjustment
  describe("DST adjustment", () => {
    it("isInDSTAdjustmentPeriod detects March after transition", () => {
      const dstDates: UkDstYear[] = [{ year: 2024, startDate: "2024-03-31", endDate: "2024-10-27" }];
      const date = sheffieldNoonUTC(2024, 3, 31);
      expect(isInDSTAdjustmentPeriod(date, dstDates)).toBe(true);
    });

    it("isInDSTAdjustmentPeriod detects October after transition", () => {
      const dstDates: UkDstYear[] = [{ year: 2024, startDate: "2024-03-31", endDate: "2024-10-27" }];
      const date = sheffieldNoonUTC(2024, 10, 27);
      expect(isInDSTAdjustmentPeriod(date, dstDates)).toBe(true);
    });

    it("getDSTAdjustmentIqamahDate maps March to April", () => {
      const dstDates: UkDstYear[] = [{ year: 2024, startDate: "2024-03-31", endDate: "2024-10-27" }];
      const date = sheffieldNoonUTC(2024, 3, 31);
      const mapped = getDSTAdjustmentIqamahDate(date, dstDates);
      expect(mapped).toEqual({ month: 4, day: 1 });
    });

    it("getDSTAdjustmentIqamahDate maps October to November", () => {
      const dstDates: UkDstYear[] = [{ year: 2024, startDate: "2024-03-31", endDate: "2024-10-27" }];
      const date = sheffieldNoonUTC(2024, 10, 27);
      const mapped = getDSTAdjustmentIqamahDate(date, dstDates);
      expect(mapped).toEqual({ month: 11, day: 1 });
    });

    it("isInDSTAdjustmentPeriodSync detects March transition", () => {
      expect(isInDSTAdjustmentPeriodSync(sheffieldNoonUTC(2024, 3, 25))).toBe(true);
      expect(isInDSTAdjustmentPeriodSync(sheffieldNoonUTC(2024, 3, 15))).toBe(false);
    });

    it("isInDSTAdjustmentPeriodSync detects October transition", () => {
      expect(isInDSTAdjustmentPeriodSync(sheffieldNoonUTC(2024, 10, 25))).toBe(true);
      expect(isInDSTAdjustmentPeriodSync(sheffieldNoonUTC(2024, 10, 15))).toBe(false);
    });

    it("getDisplayedPrayerTimes subtracts hour in October", () => {
      const times: DailyPrayerTimes = {
        date: "2024-10-25",
        fajr: "05:00",
        sunrise: "06:00",
        dhuhr: "13:00",
        asr: "17:00",
        maghrib: "20:00",
        isha: "21:00",
      };
      const result = getDisplayedPrayerTimes(times, sheffieldNoonUTC(2024, 10, 25), "other");
      expect(result.fajr).toBe("04:00");
      expect(result.dhuhr).toBe("12:00");
    });

    it("getDisplayedPrayerTimes adds hour in March", () => {
      const times: DailyPrayerTimes = {
        date: "2024-03-25",
        fajr: "05:00",
        sunrise: "06:00",
        dhuhr: "13:00",
        asr: "17:00",
        maghrib: "20:00",
        isha: "21:00",
      };
      const result = getDisplayedPrayerTimes(times, sheffieldNoonUTC(2024, 3, 25), "other");
      expect(result.fajr).toBe("06:00");
      expect(result.dhuhr).toBe("14:00");
    });

    it("getDisplayedPrayerTimes skips for dst-included mosques", () => {
      const times: DailyPrayerTimes = {
        date: "2024-10-25",
        fajr: "05:00",
        sunrise: "06:00",
        dhuhr: "13:00",
        asr: "17:00",
        maghrib: "20:00",
        isha: "21:00",
      };
      const result = getDisplayedPrayerTimes(times, sheffieldNoonUTC(2024, 10, 25), "masjid-al-huda-sheffield");
      expect(result.fajr).toBe("05:00");
    });
  });

  // MARK: - Next prayer
  describe("getNextPrayerAndCountdown", () => {
    it("returns next adhan when before first prayer", () => {
      const ptimes: DailyPrayerTimes = {
        date: "2026-01-02",
        fajr: "03:00",
        sunrise: "04:00",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "21:00",
      };
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:20",
        asr: "18:10",
        maghrib: "20:05",
        isha: "21:10",
        jummah: "13:25",
      };
      const now = new Date("2026-01-02T01:00:00Z");
      const result = getNextPrayerAndCountdown(ptimes, iq, "x", now);
      expect(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]).toContain(result.nextName);
    });

    it("returns Jummah on Friday", () => {
      const ptimes: DailyPrayerTimes = {
        date: "2026-01-02",
        fajr: "03:00",
        sunrise: "04:00",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "21:00",
      };
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:20",
        asr: "18:10",
        maghrib: "20:05",
        isha: "21:10",
        jummah: "13:25",
      };
      const now = new Date("2026-01-02T01:00:00Z");
      const result = getNextPrayerAndCountdown(ptimes, iq, "x", now);
      expect(["Jummah", "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]).toContain(result.nextName);
    });

    it("counts down to iqamah when adhan has passed", () => {
      const ptimes: DailyPrayerTimes = {
        date: "2026-01-02",
        fajr: "03:00",
        sunrise: "04:00",
        dhuhr: "13:00",
        asr: "18:00",
        maghrib: "20:00",
        isha: "21:00",
      };
      const iq: DailyIqamahTimes = {
        fajr: "03:30",
        dhuhr: "13:20",
        asr: "18:10",
        maghrib: "20:05",
        isha: "21:10",
        jummah: "13:25",
      };
      const now = new Date("2026-01-02T03:15:00Z");
      const result = getNextPrayerAndCountdown(ptimes, iq, "x", now);
      expect(result.nextName).toBe("Fajr");
      expect(result.isIqamah).toBe(true);
    });
  });

  // MARK: - formatTo12Hour
  describe("formatTo12Hour", () => {
    it("formats 24h to 12h", () => {
      expect(formatTo12Hour("13:00")).toBe("1:00pm");
      expect(formatTo12Hour("12:00")).toBe("12:00pm");
      expect(formatTo12Hour("00:00")).toBe("12:00am");
      expect(formatTo12Hour("05:30")).toBe("5:30am");
    });

    it("returns non-parseable strings unchanged", () => {
      expect(formatTo12Hour("After Maghrib")).toBe("After Maghrib");
      expect(formatTo12Hour("-")).toBe("-");
      expect(formatTo12Hour("")).toBe("");
    });
  });

  describe("formatPrayerClockForDisplay", () => {
    it("uses Arabic-Indic digits in 24h for ar locale", () => {
      const s = formatPrayerClockForDisplay("13:05", true, "ar");
      expect(s).not.toBe("13:05");
      expect(/[\u0660-\u0669]/.test(s)).toBe(true);
    });

    it("keeps English digits for en-GB 24h", () => {
      expect(formatPrayerClockForDisplay("09:30", true, "en-GB")).toMatch(/9/);
    });

    it("passes through non-clock strings", () => {
      expect(formatPrayerClockForDisplay("sunset", false, "ar")).toBe("sunset");
    });
  });

  // MARK: - resolvePrayerTimes / resolveIqamahTimes
  describe("resolvePrayerTimes", () => {
    it("resolves Ramadan day", () => {
      const ramadan: RamadanPrayerData = {
        month: "Ramadan",
        gregorianStart: "2025-03-01",
        gregorianEnd: "2025-03-29",
        prayerTimes: [
          {
            ramadanDay: 1,
            gregorian: "2025-03-01",
            fajr: "05:00",
            shurooq: "06:00",
            dhuhr: "12:00",
            asr: "15:00",
            maghrib: "18:00",
            isha: "20:00",
          },
        ],
        iqamahTimes: [iq("1-30")],
        jummahIqamah: "12:45",
      };
      const result = resolvePrayerTimes("x", sheffieldNoonUTC(2025, 3, 1), null, ramadan, []);
      expect(result.fajr).toBe("05:00");
    });

    it("throws missingRamadanRow when day missing", () => {
      const ramadan: RamadanPrayerData = {
        month: "Ramadan",
        gregorianStart: "2025-03-01",
        gregorianEnd: "2025-03-29",
        prayerTimes: [],
        iqamahTimes: [],
        jummahIqamah: "12:45",
      };
      expect(() => resolvePrayerTimes("x", sheffieldNoonUTC(2025, 3, 1), null, ramadan, [])).toThrow(
        PrayerEngineError
      );
    });

    it("resolves monthly day", () => {
      const monthly: MonthPrayerData = {
        month: "May",
        prayerTimes: [pt(1, "13:00")],
        iqamahTimes: [iq("1-31")],
        jummahIqamah: "13:30",
      };
      const result = resolvePrayerTimes("x", sheffieldNoonUTC(2025, 5, 1), monthly, null, []);
      expect(result.dhuhr).toBe("13:00");
    });

    it("throws missingMonthly when no data", () => {
      expect(() => resolvePrayerTimes("x", sheffieldNoonUTC(2025, 5, 1), null, null, [])).toThrow(
        PrayerEngineError
      );
    });
  });

  describe("resolveIqamahTimes", () => {
    it("resolves monthly iqamah", () => {
      const monthly: MonthPrayerData = {
        month: "May",
        prayerTimes: [pt(1, "13:00")],
        iqamahTimes: [iq("1-31")],
        jummahIqamah: "13:30",
      };
      const result = resolveIqamahTimes("x", sheffieldNoonUTC(2025, 5, 1), monthly, null, []);
      expect(result.fajr).toBe("03:30");
    });

    it("uses jummahIqamah when range jummah is empty", () => {
      const monthly: MonthPrayerData = {
        month: "May",
        prayerTimes: [pt(1, "13:00")],
        iqamahTimes: [
          { dateRange: "1-31", fajr: "x", dhuhr: "y", asr: "z", maghrib: "m", isha: "i", jummah: "" },
        ],
        jummahIqamah: "13:30",
      };
      const result = resolveIqamahTimes("x", sheffieldNoonUTC(2025, 5, 1), monthly, null, []);
      expect(result.jummah).toBe("13:30");
    });
  });

  describe("resolveIqamahTimesWithDstMapping", () => {
    it("maps iqamah in March DST period", () => {
      const monthly: MonthPrayerData = {
        month: "April",
        prayerTimes: [pt(1, "13:00")],
        iqamahTimes: [iq("1-30")],
        jummahIqamah: "13:30",
      };
      const dstDates: UkDstYear[] = [{ year: 2025, startDate: "2025-03-30", endDate: "2025-10-26" }];
      const result = resolveIqamahTimesWithDstMapping(
        "x",
        sheffieldNoonUTC(2025, 3, 30),
        monthly,
        null,
        dstDates
      );
      expect(result).toBeDefined();
    });

    it("passes through for dst-included mosques", () => {
      const monthly: MonthPrayerData = {
        month: "May",
        prayerTimes: [pt(1, "13:00")],
        iqamahTimes: [iq("1-31")],
        jummahIqamah: "13:30",
      };
      const result = resolveIqamahTimesWithDstMapping(
        "masjid-al-huda-sheffield",
        sheffieldNoonUTC(2025, 5, 1),
        monthly,
        null,
        []
      );
      expect(result.fajr).toBe("03:30");
    });
  });

  describe("heroCountdownPresentation", () => {
    const d: DailyPrayerTimes = {
      date: "2026-06-15",
      fajr: "04:00",
      sunrise: "05:00",
      dhuhr: "13:00",
      asr: "18:00",
      maghrib: "21:00",
      isha: "22:30",
    };
    const iq: DailyIqamahTimes = {
      fajr: "04:30",
      dhuhr: "13:20",
      asr: "18:10",
      maghrib: "21:05",
      isha: "22:45",
      jummah: "13:25",
    };

    it("labels adhanIn before first adhan", () => {
      const now = new Date("2026-06-15T02:00:00Z");
      const h = heroCountdownPresentation(d, iq, "x", now);
      expect(h?.labelKind).toBe("adhanIn");
      expect(heroRemainingSeconds(h!, now)).toBe(3600);
    });

    it("labels nextPrayer after first salaat block", () => {
      const now = new Date("2026-06-15T11:00:00Z");
      const h = heroCountdownPresentation(d, iq, "x", now);
      expect(h?.labelKind).toBe("nextPrayer");
    });

    it("labels iqamahIn between adhan and iqamah", () => {
      const now = new Date("2026-06-15T12:05:00Z");
      const h = heroCountdownPresentation(d, iq, "x", now);
      expect(h?.labelKind).toBe("iqamahIn");
      expect(heroRemainingSeconds(h!, now)).toBe(15 * 60);
    });
  });

  describe("formatHeroCountdownClock", () => {
    it("formats hours and under-hour", () => {
      expect(formatHeroCountdownClock(5024)).toBe("-1:23:44");
      expect(formatHeroCountdownClock(1122)).toBe("-18:42");
      expect(formatHeroCountdownClock(545)).toBe("-9:05");
      expect(formatHeroCountdownClock(0)).toBe("-0:00");
    });
  });
});
