import { useCallback, useEffect, useRef, useState } from "react";
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
} from "@/lib/prayer/prayerTimesEngine";
import { resolveSelectedMosque } from "@/lib/prayer/mosqueDefaults";
import { monthNameFromNumber } from "@/lib/prayer/monthName";
import { useSettingsStore } from "@/store/settings";

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
  refresh: () => Promise<void>;
}

export function useHomePrayerData(): HomePrayerData {
  const selectedMosqueId = useSettingsStore((s) => s.selectedMosqueId);
  const selectedMosqueSlug = useSettingsStore((s) => s.selectedMosqueSlug);
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

  const lastGoodData = useRef<Partial<Omit<HomePrayerData, "loadState" | "refresh">>>({});

  const refresh = useCallback(async () => {
    setLoadState((prev) => (prev === "idle" ? "loading" : prev));
    try {
      const allMosques = await prayerRepository.listMosques();
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
        setSelectedMosque(resolved.id, resolved.slug);
      }

      const now = new Date();
      const { year, month, day } = getDateInSheffield(now);
      const monthName = monthNameFromNumber(month);

      const [monthly, ramadan, dstCalendar] = await Promise.all([
        monthName
          ? prayerRepository.getMonthlyPrayerTimes(resolved.slug, monthName, year)
          : Promise.resolve(null),
        prayerRepository.getRamadanTimetable(resolved.slug),
        prayerRepository.getUkDstDates(),
      ]);

      const dstDates = dstCalendar?.ukDstDates ?? [];
      setMonthData(monthly);
      setRamadanData(ramadan);
      setUkDst(dstDates);

      const prayerTimes = resolvePrayerTimes(
        resolved.slug,
        now,
        monthly ?? undefined,
        ramadan ?? undefined,
        dstDates
      );
      const displayed = getDisplayedPrayerTimes(prayerTimes, now, resolved.slug);
      setDisplayedPrayerTimes(displayed);

      const iqamah = resolveIqamahTimesWithDstMapping(
        resolved.slug,
        now,
        monthly ?? undefined,
        ramadan ?? undefined,
        dstDates
      );
      setIqamahTimes(iqamah);

      const countdown = getNextPrayerAndCountdown(displayed, iqamah, resolved.slug, now);
      setNextCountdown(countdown);

      lastGoodData.current = {
        mosques: allMosques,
        selectedMosque: resolved,
        displayedPrayerTimes: displayed,
        iqamahTimes: iqamah,
        nextCountdown: countdown,
        monthData: monthly,
        ramadanData: ramadan,
        ukDst: dstDates,
      };

      setLoadState("loaded");
    } catch (err) {
      if (__DEV__) {
        console.error("[useHomePrayerData] error:", err);
      }
      setLoadState("error");
    }
  }, [selectedMosqueId, selectedMosqueSlug, setSelectedMosque]);

  useEffect(() => {
    refresh();
  }, [refresh]);

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
    refresh,
  };
}
