import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  View, Text, StyleSheet, Pressable, ScrollView, ActivityIndicator,
} from "react-native";
import { useRouter, useLocalSearchParams } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { X, ChevronLeft, ChevronRight } from "lucide-react-native";
import { LinearGradient } from "expo-linear-gradient";
import { COLORS, SPACING, FONT_SIZES } from "@/constants";
import { PrayerRow } from "@/components/ui/PrayerRow";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import { useSettingsStore } from "@/store/settings";
import { formatTo12Hour, getIqamahTimesForDate, findDayData } from "@/lib/prayer/prayerTimesEngine";
import { t } from "@/lib/i18n/translations";
import { resolvedLanguageCode } from "@/lib/i18n/language";
import { getLocales } from "expo-localization";
import type { MonthPrayerData } from "@/types/prayer";

function formatTime(time: string, uses24h: boolean): string {
  if (!time || time === "-" || time === "\u2014") return "\u2014";
  if (uses24h) return time;
  return formatTo12Hour(time);
}

function splitJummahTimes(input: string): string[] {
  if (!input.trim()) return [];
  return input.split(/[,/&|]/).map((s) => s.trim()).filter(Boolean);
}

function isToday(date: Date, year: number, month: number, day: number): boolean {
  return date.getFullYear() === year && date.getMonth() + 1 === month && date.getDate() === day;
}

export default function TimetableScreen() {
  const router = useRouter();
  const { mosqueSlug } = useLocalSearchParams<{ mosqueSlug?: string }>();
  const selectedMosqueSlug = useSettingsStore((s) => s.selectedMosqueSlug);
  const uses24HourTime = useSettingsStore((s) => s.uses24HourTime);
  const appLanguage = useSettingsStore((s) => s.appLanguage);
  const activeMosqueSlug = mosqueSlug ?? selectedMosqueSlug;
  const systemLocale = getLocales()[0].languageTag;
  const languageCode = resolvedLanguageCode(appLanguage, systemLocale);

  const [currentDate, setCurrentDate] = useState(new Date());
  const [monthData, setMonthData] = useState<MonthPrayerData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);

  const year = currentDate.getFullYear();
  const month = currentDate.getMonth() + 1;
  const daysInMonth = new Date(year, month, 0).getDate();

  const [selectedDay, setSelectedDay] = useState(() => {
    const today = new Date();
    return isToday(today, year, month, today.getDate()) ? today.getDate() : 1;
  });

  const fetchMonth = useCallback(async () => {
    if (!activeMosqueSlug) return;
    setLoading(true); setError(false);
    try {
      const monthNames = ["january","february","march","april","may","june","july","august","september","october","november","december"] as const;
      const data = await prayerRepository.getMonthlyPrayerTimes(activeMosqueSlug, monthNames[month - 1], year);
      setMonthData(data);
    } catch { setError(true); } finally { setLoading(false); }
  }, [activeMosqueSlug, month, year]);

  useEffect(() => { fetchMonth(); }, [fetchMonth]);
  useEffect(() => {
    const today = new Date();
    setSelectedDay(isToday(today, year, month, today.getDate()) ? today.getDate() : 1);
  }, [year, month]);

  const dayData = useMemo(() => {
    if (!monthData) return null;
    return findDayData(monthData.prayerTimes, selectedDay);
  }, [monthData, selectedDay]);

  const iqamah = useMemo(() => {
    if (!monthData) return null;
    try { return getIqamahTimesForDate(selectedDay, monthData.iqamahTimes); } catch { return null; }
  }, [monthData, selectedDay]);

  const isFriday = useMemo(() => new Date(year, month - 1, selectedDay).getDay() === 5, [year, month, selectedDay]);
  const today = new Date();
  const selectedIsToday = isToday(today, year, month, selectedDay);

  const nextPrayerName = useMemo(() => {
    if (!selectedIsToday || !dayData) return null;
    const now = new Date();
    const prayers = [
      { name: "Fajr", time: dayData.fajr }, { name: "Sunrise", time: dayData.shurooq },
      { name: "Dhuhr", time: dayData.dhuhr }, { name: "Asr", time: dayData.asr },
      { name: "Maghrib", time: dayData.maghrib }, { name: "Isha", time: dayData.isha },
    ];
    for (const p of prayers) {
      const parts = p.time.split(":").map((s) => parseInt(s.trim(), 10));
      if (parts.length === 2) {
        const pd = new Date(year, month - 1, selectedDay, parts[0], parts[1]);
        if (pd.getTime() > now.getTime()) return p.name;
      }
    }
    return "Fajr";
  }, [selectedIsToday, dayData, year, month, selectedDay]);

  const monthLabel = new Intl.DateTimeFormat(systemLocale, { month: "long", year: "numeric" }).format(currentDate);

  const goPrev = () => setCurrentDate((p) => new Date(p.getFullYear(), p.getMonth() - 1, 1));
  const goNext = () => setCurrentDate((p) => new Date(p.getFullYear(), p.getMonth() + 1, 1));

  return (
    <LinearGradient colors={[COLORS.background, COLORS.backgroundSecondary]} style={styles.gradient}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <Pressable onPress={() => router.back()} accessibilityRole="button">
            <X size={24} color={COLORS.primary} />
          </Pressable>
          <Text style={styles.headerTitle} numberOfLines={1}>{activeMosqueSlug ?? ""}</Text>
          <View style={{ width: 24 }} />
        </View>

        <View style={styles.monthSwitcher}>
          <Pressable onPress={goPrev} accessibilityRole="button" accessibilityLabel="Previous month">
            <ChevronLeft size={24} color={COLORS.primary} />
          </Pressable>
          <Text style={styles.monthLabel}>{monthLabel}</Text>
          <Pressable onPress={goNext} accessibilityRole="button" accessibilityLabel="Next month">
            <ChevronRight size={24} color={COLORS.primary} />
          </Pressable>
        </View>

        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.daysContainer}>
          {Array.from({ length: daysInMonth }, (_, i) => i + 1).map((day) => {
            const sel = day === selectedDay;
            const td = isToday(today, year, month, day);
            return (
              <Pressable key={day} onPress={() => setSelectedDay(day)} style={[styles.dayCell, sel && styles.dayCellSelected, td && !sel && styles.dayCellToday]}
                accessibilityRole="button" accessibilityLabel={`Day ${day}`}>
                <Text style={[styles.dayText, sel && styles.dayTextSelected]}>{day}</Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {loading ? <ActivityIndicator style={styles.loader} color={COLORS.accent} /> : error || !dayData ? (
          <View style={styles.loader}>
            <Text style={styles.errorText}>Failed to load timetable</Text>
            <Pressable onPress={fetchMonth} accessibilityRole="button"><Text style={styles.retryText}>Retry</Text></Pressable>
          </View>
        ) : (
          <ScrollView contentContainerStyle={styles.tableContainer}>
            <View style={styles.tableHeader}>
              <Text style={[styles.headerCell, styles.nameCell]}>Prayer</Text>
              <Text style={[styles.headerCell, styles.timeCell]}>Adhan</Text>
              <Text style={[styles.headerCell, styles.timeCell]}>Iqamah</Text>
            </View>
            <PrayerRow name={t("timetable.header.fajr", languageCode)} adhan={dayData.fajr} iqamah={iqamah?.fajr ?? "-"} highlighted={nextPrayerName === "Fajr"} uses24HourTime={uses24HourTime} />
            <PrayerRow name={t("timetable.header.shu", languageCode)} adhan={dayData.shurooq} iqamah="-" highlighted={nextPrayerName === "Sunrise"} uses24HourTime={uses24HourTime} />
            {isFriday ? (
              <PrayerRow name={t("timetable.header.dhu", languageCode)} adhan={dayData.dhuhr}
                iqamah={(() => { const tms = splitJummahTimes(iqamah?.jummah ?? ""); return tms.length === 0 ? "-" : tms.map((tm) => formatTime(tm, uses24HourTime)).join(" \u00b7 "); })()}
                highlighted={nextPrayerName === "Dhuhr"} uses24HourTime={uses24HourTime} />
            ) : (
              <PrayerRow name={t("timetable.header.dhu", languageCode)} adhan={dayData.dhuhr} iqamah={iqamah?.dhuhr ?? "-"} highlighted={nextPrayerName === "Dhuhr"} uses24HourTime={uses24HourTime} />
            )}
            <PrayerRow name={t("timetable.header.asr", languageCode)} adhan={dayData.asr} iqamah={iqamah?.asr ?? "-"} highlighted={nextPrayerName === "Asr"} uses24HourTime={uses24HourTime} />
            <PrayerRow name={t("timetable.header.mag", languageCode)} adhan={dayData.maghrib} iqamah={iqamah?.maghrib ?? "-"} highlighted={nextPrayerName === "Maghrib"} uses24HourTime={uses24HourTime} />
            <PrayerRow name={t("timetable.header.ish", languageCode)} adhan={dayData.isha} iqamah={iqamah?.isha ?? "-"} highlighted={nextPrayerName === "Isha"} uses24HourTime={uses24HourTime} />
          </ScrollView>
        )}
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  safeArea: { flex: 1 },
  header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: SPACING.md, paddingVertical: SPACING.sm },
  headerTitle: { fontSize: FONT_SIZES.md, fontWeight: "600", color: COLORS.primary, flex: 1, textAlign: "center", marginHorizontal: SPACING.sm },
  monthSwitcher: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: SPACING.md, paddingVertical: SPACING.sm },
  monthLabel: { fontSize: FONT_SIZES.lg, fontWeight: "600", color: COLORS.primary },
  daysContainer: { paddingHorizontal: SPACING.md, paddingVertical: SPACING.sm, gap: SPACING.xs },
  dayCell: { width: 44, height: 44, borderRadius: 22, justifyContent: "center", alignItems: "center", backgroundColor: `${COLORS.background}80`, marginRight: SPACING.xs },
  dayCellSelected: { backgroundColor: COLORS.accent },
  dayCellToday: { borderWidth: 1, borderColor: COLORS.accent },
  dayText: { fontSize: FONT_SIZES.md, color: COLORS.primary },
  dayTextSelected: { color: COLORS.background, fontWeight: "600" },
  loader: { flex: 1, justifyContent: "center", alignItems: "center" },
  errorText: { fontSize: FONT_SIZES.md, color: COLORS.secondary, marginBottom: SPACING.sm },
  retryText: { fontSize: FONT_SIZES.md, color: COLORS.accent, fontWeight: "600" },
  tableContainer: { paddingHorizontal: SPACING.md, paddingBottom: SPACING.lg },
  tableHeader: { flexDirection: "row", alignItems: "center", paddingVertical: SPACING.sm, paddingHorizontal: SPACING.md, borderBottomWidth: 1, borderBottomColor: `${COLORS.secondary}20` },
  headerCell: { fontSize: FONT_SIZES.sm, fontWeight: "700", color: COLORS.secondary, textTransform: "uppercase" },
  nameCell: { flex: 1 },
  timeCell: { width: 80, textAlign: "center" },
});
