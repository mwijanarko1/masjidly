import { useCallback, useEffect, useState } from "react";
import type {
  DailyPrayerTimes,
  DailyIqamahTimes,
  Mosque,
  MonthPrayerData,
  NextPrayerCountdownResult,
  RamadanPrayerData,
  UkDstYear,
} from "@/types/prayer";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import {
  getDisplayedPrayerTimes,
  getNextPrayerAndCountdown,
  resolvePrayerTimes,
  resolveIqamahTimesWithDstMapping,
  getDateInSheffield,
  isoDateString,
} from "@/lib/prayer/prayerTimesEngine";
import { prayerTimesCache } from "@/lib/prayer/prayerTimesCache";
import { resolveSelectedMosque, cityGroupingKey, countryGroupingKey } from "@/lib/prayer/mosqueDefaults";
import { monthNameFromNumber } from "@/lib/prayer/monthName";
import { useSettingsStore } from "@/store/settings";
import { updateAndroidPrayerWidgetSnapshot } from "@/lib/widgets/prayerWidget";

export interface HomePrayerData {
  loadState: "idle" | "loading" | "loaded" | "empty" | "error";
  mosques: Mosque[];
  selectedMosque: Mosque | null;
  displayedPrayerTimes: DailyPrayerTimes | null;
  iqamahTimes: DailyIqamahTimes | null;
  nextCountdown: NextPrayerCountdownResult | null;
  monthData: MonthPrayerData | null;
  ramadanData: RamadanPrayerData | null;
  ukDst: UkDstYear[];
  displayedDate: Date;
  goToPreviousDay: () => void;
  goToNextDay: () => void;
  goToToday: () => void;
  goToLastAvailablePrayerDate: () => void;
  hasAvailablePrayerTimesFallback: boolean;
  refresh: () => Promise<void>;
}

function addDays(date: Date, days: number): Date {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate() + days,
    date.getHours(),
    date.getMinutes(),
    date.getSeconds(),
    date.getMilliseconds()
  );
}

function isSameSheffieldDay(a: Date, b: Date): boolean {
  const left = getDateInSheffield(a);
  const right = getDateInSheffield(b);
  return left.year === right.year && left.month === right.month && left.day === right.day;
}

export function useHomePrayerData(): HomePrayerData {
  const selectedMosqueId = useSettingsStore((s) => s.selectedMosqueId);
  const selectedMosqueSlug = useSettingsStore((s) => s.selectedMosqueSlug);
  const uses24HourTime = useSettingsStore((s) => s.uses24HourTime);
  const appLanguage = useSettingsStore((s) => s.appLanguage);
  const asrIqamahPreference = useSettingsStore((s) => s.asrIqamahPreference);
  const setSelectedMosque = useSettingsStore((s) => s.setSelectedMosque);

  const [loadState, setLoadState] = useState<HomePrayerData["loadState"]>("idle");
  const [mosques, setMosques] = useState<Mosque[]>([]);
  const [selectedMosque, setSelectedMosqueLocal] = useState<Mosque | null>(null);
  const [displayedPrayerTimes, setDisplayedPrayerTimes] = useState<DailyPrayerTimes | null>(null);
  const [iqamahTimes, setIqamahTimes] = useState<DailyIqamahTimes | null>(null);
  const [nextCountdown, setNextCountdown] = useState<NextPrayerCountdownResult | null>(null);
  const [monthData, setMonthData] = useState<MonthPrayerData | null>(null);
  const [ramadanData, setRamadanData] = useState<RamadanPrayerData | null>(null);
  const [ukDst, setUkDst] = useState<UkDstYear[]>([]);
  const [displayedDate, setDisplayedDate] = useState(() => new Date());
  const [loadedMonth, setLoadedMonth] = useState<{ month: number; year: number } | null>(null);
  const [lastAvailablePrayerDate, setLastAvailablePrayerDate] = useState<Date | null>(null);

  const applyPrayerPayload = useCallback((input: {
    mosque: Mosque;
    mosques: Mosque[];
    monthly: MonthPrayerData | null;
    ramadan: RamadanPrayerData | null;
    dstCalendar: { ukDstDates: UkDstYear[] } | null;
    now: Date;
  }): boolean => {
    const { mosque, monthly, ramadan, dstCalendar, now } = input;
    const dstDates = dstCalendar?.ukDstDates ?? [];
    const parts = getDateInSheffield(now);
    setMosques(input.mosques);
    setSelectedMosqueLocal(mosque);
    setMonthData(monthly);
    setRamadanData(ramadan);
    setUkDst(dstDates);
    setLoadedMonth({ month: parts.month, year: parts.year });

    try {
      const prayerTimes = resolvePrayerTimes(
        mosque.slug,
        now,
        monthly ?? undefined,
        ramadan ?? undefined,
        dstDates,
        asrIqamahPreference
      );
      const displayed = getDisplayedPrayerTimes(prayerTimes, now, mosque.slug);
      const iqamah = resolveIqamahTimesWithDstMapping(
        mosque.slug,
        now,
        monthly ?? undefined,
        ramadan ?? undefined,
        dstDates
      );
      setDisplayedPrayerTimes(displayed);
      setIqamahTimes(iqamah);
      setLastAvailablePrayerDate(now);
      setNextCountdown(
        isSameSheffieldDay(now, new Date())
          ? getNextPrayerAndCountdown(displayed, iqamah, mosque.slug, new Date(), asrIqamahPreference, false)
          : null
      );

      updateAndroidPrayerWidgetSnapshot({
        mosque,
        monthData: monthly,
        ramadanData: ramadan,
        ukDst: dstDates,
        uses24HourTime,
        appLanguage,
        asrIqamahPreference,
        now: new Date(),
      }).catch((error) => {
        if (__DEV__) {
          console.warn("[useHomePrayerData] widget update failed:", error);
        }
      });

      setLoadState("loaded");
      return true;
    } catch (err) {
      setDisplayedPrayerTimes(null);
      setIqamahTimes(null);
      setNextCountdown(null);
      if (__DEV__) {
        console.warn("[useHomePrayerData] unable to apply prayer payload:", err);
      }
      return false;
    }
  }, [appLanguage, asrIqamahPreference, uses24HourTime]);

  const loadPrayerPayloadForDate = useCallback(async (targetDate: Date, mosque: Mosque, mosqueList: Mosque[] = mosques) => {
    const { year, month, day } = getDateInSheffield(targetDate);
    const monthName = monthNameFromNumber(month);
    if (!monthName) return;
    const iso = isoDateString(year, month, day);

    try {
      const [monthly, ramadan, dstCalendar] = await Promise.all([
        prayerRepository.getMonthlyPrayerTimes(mosque.slug, monthName, year),
        prayerRepository.getRamadanTimetable(mosque.slug, iso),
        prayerRepository.getUkDstDates(),
      ]);

      if (monthly && monthly.prayerTimes.length > 0) {
        await prayerTimesCache.saveMonthly(mosque.slug, monthName, year, monthly);
      } else {
        await prayerTimesCache.removeMonthly(mosque.slug, monthName, year);
      }
      if (ramadan) {
        await prayerTimesCache.saveRamadan(mosque.slug, iso, ramadan);
        await prayerTimesCache.saveRamadan(mosque.slug, undefined, ramadan);
      }
      if (dstCalendar) {
        await prayerTimesCache.saveUkDst(dstCalendar);
      }

      applyPrayerPayload({ mosque, mosques: mosqueList, monthly, ramadan, dstCalendar, now: targetDate });
    } catch (err) {
      const [monthly, ramadanByDate, ramadanLatest, dstCalendar] = await Promise.all([
        prayerTimesCache.loadMonthly(mosque.slug, monthName, year),
        prayerTimesCache.loadRamadan(mosque.slug, iso),
        prayerTimesCache.loadRamadan(mosque.slug),
        prayerTimesCache.loadUkDst(),
      ]);
      applyPrayerPayload({
        mosque,
        mosques: mosqueList,
        monthly,
        ramadan: ramadanByDate ?? ramadanLatest,
        dstCalendar,
        now: targetDate,
      });
      if (__DEV__) {
        console.warn("[useHomePrayerData] unable to load displayed date payload:", err);
      }
    }
  }, [applyPrayerPayload, mosques]);

  const refresh = useCallback(async () => {
    setLoadState((prev) => (prev === "idle" ? "loading" : prev));

    const now = displayedDate;
    const { year, month, day } = getDateInSheffield(now);
    const monthName = monthNameFromNumber(month);
    let showedCachedData = false;
    let cachedRamadan: RamadanPrayerData | null = null;
    let cachedDstCalendar: { ukDstDates: UkDstYear[] } | null = null;

    const cachedMosques = await prayerTimesCache.loadMosques();
    if (cachedMosques && monthName) {
      const cachedMosque = resolveSelectedMosque(cachedMosques, selectedMosqueId, selectedMosqueSlug);
      if (cachedMosque) {
        const iso = isoDateString(year, month, day);
        const [monthly, ramadanByDate, ramadanLatest, dstCalendar] = await Promise.all([
          prayerTimesCache.loadMonthly(cachedMosque.slug, monthName, year),
          prayerTimesCache.loadRamadan(cachedMosque.slug, iso),
          prayerTimesCache.loadRamadan(cachedMosque.slug),
          prayerTimesCache.loadUkDst(),
        ]);
        cachedRamadan = ramadanByDate ?? ramadanLatest;
        cachedDstCalendar = dstCalendar;
        showedCachedData = applyPrayerPayload({
          mosque: cachedMosque,
          mosques: cachedMosques,
          monthly,
          ramadan: cachedRamadan,
          dstCalendar: cachedDstCalendar,
          now,
        });
      } else {
        setMosques(cachedMosques);
      }
    }

    try {
      const allMosques = await prayerRepository.listMosques();
      await prayerTimesCache.saveMosques(allMosques);
      setMosques(allMosques);

      const resolved = resolveSelectedMosque(
        allMosques,
        selectedMosqueId,
        selectedMosqueSlug
      );
      setSelectedMosqueLocal(resolved);

      if (!resolved) {
        setLoadState("empty");
        return;
      }

      if (resolved.id !== selectedMosqueId || resolved.slug !== selectedMosqueSlug) {
        setSelectedMosque(resolved.id, resolved.slug, cityGroupingKey(resolved), countryGroupingKey(resolved));
      }

      const [monthly, ramadan, dstCalendar] = await Promise.all([
        monthName
          ? prayerRepository.getMonthlyPrayerTimes(resolved.slug, monthName, year)
          : Promise.resolve(null),
        prayerRepository.getRamadanTimetable(resolved.slug, isoDateString(year, month, day)),
        prayerRepository.getUkDstDates(),
      ]);

      if (monthName) {
        if (monthly && monthly.prayerTimes.length > 0) {
          await prayerTimesCache.saveMonthly(resolved.slug, monthName, year, monthly);
        } else {
          await prayerTimesCache.removeMonthly(resolved.slug, monthName, year);
        }
      }
      if (ramadan) {
        await prayerTimesCache.saveRamadan(resolved.slug, isoDateString(year, month, day), ramadan);
        await prayerTimesCache.saveRamadan(resolved.slug, undefined, ramadan);
      }
      if (dstCalendar) {
        await prayerTimesCache.saveUkDst(dstCalendar);
      }

      const applied = applyPrayerPayload({
        mosque: resolved,
        mosques: allMosques,
        monthly,
        ramadan: ramadan ?? cachedRamadan,
        dstCalendar: dstCalendar ?? cachedDstCalendar,
        now,
      });
      setLoadState(applied ? "loaded" : "empty");
    } catch (err) {
      if (__DEV__) {
        console.error("[useHomePrayerData] error:", err);
      }
      setLoadState(showedCachedData ? "loaded" : "error");
    }
  }, [selectedMosqueId, selectedMosqueSlug, setSelectedMosque, applyPrayerPayload, displayedDate]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const applyDisplayedDate = useCallback((date: Date) => {
    setDisplayedDate(date);
    if (!selectedMosque) return;

    const parts = getDateInSheffield(date);
    if (loadedMonth?.month === parts.month && loadedMonth.year === parts.year) {
      applyPrayerPayload({
        mosque: selectedMosque,
        mosques,
        monthly: monthData,
        ramadan: ramadanData,
        dstCalendar: { ukDstDates: ukDst },
        now: date,
      });
      return;
    }

    setDisplayedPrayerTimes(null);
    setIqamahTimes(null);
    setNextCountdown(null);
    loadPrayerPayloadForDate(date, selectedMosque);
  }, [applyPrayerPayload, loadPrayerPayloadForDate, loadedMonth, monthData, mosques, ramadanData, selectedMosque, ukDst]);

  const goToPreviousDay = useCallback(() => {
    applyDisplayedDate(addDays(displayedDate, -1));
  }, [applyDisplayedDate, displayedDate]);

  const goToNextDay = useCallback(() => {
    applyDisplayedDate(addDays(displayedDate, 1));
  }, [applyDisplayedDate, displayedDate]);

  const goToToday = useCallback(() => {
    applyDisplayedDate(new Date());
  }, [applyDisplayedDate]);

  const goToLastAvailablePrayerDate = useCallback(() => {
    if (lastAvailablePrayerDate) {
      applyDisplayedDate(lastAvailablePrayerDate);
    }
  }, [applyDisplayedDate, lastAvailablePrayerDate]);

  return {
    loadState,
    mosques,
    selectedMosque,
    displayedPrayerTimes,
    iqamahTimes,
    nextCountdown,
    monthData,
    ramadanData,
    ukDst,
    displayedDate,
    goToPreviousDay,
    goToNextDay,
    goToToday,
    goToLastAvailablePrayerDate,
    hasAvailablePrayerTimesFallback: lastAvailablePrayerDate !== null,
    refresh,
  };
}
