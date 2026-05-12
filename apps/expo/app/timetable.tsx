import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  View, Text, StyleSheet, Pressable, ScrollView, ActivityIndicator,
} from "react-native";
import { useRouter, useLocalSearchParams } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { X, ChevronLeft, ChevronRight } from "lucide-react-native";
import { AtmosphericSkyBackground } from "@/components/ui/AtmosphericSkyBackground";
import { TutorialHighlight } from "@/components/onboarding/CoachMarkCard";
import { TutorialOverlay } from "@/components/onboarding/TutorialOverlay";
import { useOnboardingStore } from "@/store/onboarding";
import { SPACING, FONT_SIZES } from "@/constants";
import { PrayerRow } from "@/components/ui/PrayerRow";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import { useSettingsStore } from "@/store/settings";
import { formatPrayerClockForDisplay, getIqamahTimesForDate, getIqamahTime, formatSystemHHMMSheffield, isFridaySheffieldCalendar, findDayData } from "@/lib/prayer/prayerTimesEngine";
import { t } from "@/lib/i18n/translations";
import { resolvedLanguageCode, resolvedLocale } from "@/lib/i18n/language";
import type { MonthPrayerData, DailyIqamahTimes } from "@/types/prayer";
import {
  themeForPrayer,
  getSkyTheme,
  getTextColor,
  getUsesLightForeground,
} from "@/lib/design/themes";

function formatTime(time: string, uses24h: boolean, locale: string): string {
  if (!time || time === "-" || time === "\u2014") return "-";
  return formatPrayerClockForDisplay(time, uses24h, locale);
}

function timetableIqamahDisplay(
  prayerId: "fajr" | "dhuhr" | "asr" | "maghrib" | "isha",
  adhan: string,
  daily: DailyIqamahTimes | null,
  maghribAdhan: string,
  uses24h: boolean,
  locale: string
): string {
  if (!daily) return "-";
  const raw = getIqamahTime(prayerId, adhan, daily, maghribAdhan);
  const trimmed = raw.trim();
  if (!trimmed || trimmed.toLowerCase() === "no iqamah") return "-";
  return formatPrayerClockForDisplay(trimmed, uses24h, locale);
}

function resolvedJummahRaw(daily: DailyIqamahTimes | null, monthFallback: string): string {
  const fromRange = daily?.jummah?.trim() ?? "";
  if (fromRange.length > 0) return fromRange;
  return monthFallback.trim();
}

function splitJummahTimes(input: string): string[] {
  if (!input.trim()) return [];
  return input
    .split(/[,/&|]/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function isToday(date: Date, year: number, month: number, day: number): boolean {
  return date.getFullYear() === year && date.getMonth() + 1 === month && date.getDate() === day;
}

export default function TimetableScreen() {
  const router = useRouter();
  const { mosqueSlug, mosqueName: mosqueNameParam, theme: themeParam } = useLocalSearchParams<{
    mosqueSlug?: string;
    mosqueName?: string;
    theme?: string;
  }>();
  const selectedMosqueSlug = useSettingsStore((s) => s.selectedMosqueSlug);
  const uses24HourTime = useSettingsStore((s) => s.uses24HourTime);
  const activeMosqueSlug = mosqueSlug ?? selectedMosqueSlug;
  const languageCode = resolvedLanguageCode();
  const locale = resolvedLocale();

  // ── Onboarding ──
  const onboarding = useOnboardingStore();
  const currentStep = onboarding.currentStep;
  useEffect(() => {
    // Safety-advance if the user navigated here during openTimetable without the tap handler firing
    if (currentStep?.type === "openTimetable") {
      onboarding.handleTimetableOpened();
    }
  }, [currentStep?.type]);
  // ── End Onboarding ──

  const theme = themeForPrayer(themeParam ?? "Fajr");
  const sky = getSkyTheme(theme);
  const textColor = getTextColor(theme);
  const usesLightForeground = getUsesLightForeground(theme);

  const [currentDate, setCurrentDate] = useState(new Date());
  const [monthData, setMonthData] = useState<MonthPrayerData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);

  const year = currentDate.getFullYear();
  const month = currentDate.getMonth() + 1;

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
    try {
      return getIqamahTimesForDate(selectedDay, monthData.iqamahTimes);
    } catch {
      return null;
    }
  }, [monthData, selectedDay]);

  const isFriday = isFridaySheffieldCalendar(year, month, selectedDay);
  const today = new Date();
  const selectedIsToday = isToday(today, year, month, selectedDay);
  const currentHHMM = formatSystemHHMMSheffield(today);

  const nextPrayerId = useMemo(() => {
    if (!selectedIsToday || !dayData) return null;
    const prayers = [
      { id: "fajr", time: dayData.fajr },
      { id: "sunrise", time: dayData.shurooq },
      { id: "dhuhr", time: dayData.dhuhr },
      { id: "asr", time: dayData.asr },
      { id: "maghrib", time: dayData.maghrib },
      { id: "isha", time: dayData.isha },
    ];
    for (const p of prayers) {
      if (p.time > currentHHMM) return p.id;
    }
    return null;
  }, [selectedIsToday, dayData, currentHHMM]);

  const monthSwitcherTitle = useMemo(() => {
    const d = new Date(year, month - 1, 15);
    return new Intl.DateTimeFormat(locale, { year: "numeric", month: "short" }).format(d);
  }, [year, month, locale]);

  const formattedSelectedDate = useMemo(() => {
    const d = new Date(year, month - 1, selectedDay);
    return new Intl.DateTimeFormat(locale, { weekday: "long", day: "numeric", month: "long" }).format(d);
  }, [year, month, selectedDay, locale]);

  const goPrev = () => setCurrentDate((p) => new Date(p.getFullYear(), p.getMonth() - 1, 1));
  const goNext = () => setCurrentDate((p) => new Date(p.getFullYear(), p.getMonth() + 1, 1));

  const shortWeekday = (day: number): string => {
    const d = new Date(year, month - 1, day);
    return new Intl.DateTimeFormat(locale, { weekday: "short" }).format(d);
  };

  if (!activeMosqueSlug) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: sky.baseColors[0] }]}>
        <Text style={{ color: textColor, fontFamily: "Comfortaa_400Regular" }}>
          {t("home.empty.no_mosque_data", languageCode)}
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <AtmosphericSkyBackground sky={sky} variant="home" diagonalBase />

      <SafeAreaView style={styles.safeArea}>
        {/* Header Bar */}
        <View style={[styles.header, { paddingHorizontal: 24, paddingTop: 24, paddingBottom: 24 }]}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.headerDate, { color: textColor }]} numberOfLines={1}>
              {formattedSelectedDate}
            </Text>
            <Text style={[styles.headerMosque, { color: textColor + "B3" }]} numberOfLines={1}>
              {mosqueNameParam || activeMosqueSlug}
            </Text>
          </View>
          <TutorialHighlight
            isHighlighted={currentStep?.type === "closeTimetable"}
            size={36}
            color={textColor}
          >
            <Pressable
              onPress={() => {
                if (currentStep?.type === "closeTimetable") {
                  onboarding.handleTimetableClosed();
                }
                router.back();
              }}
              style={[styles.closeButton, { backgroundColor: "rgba(255,255,255,0.18)" }]}
              accessibilityRole="button"
              accessibilityLabel={t("timetable.close_a11y", languageCode)}
            >
              <X size={16} color={textColor} strokeWidth={2.5} />
            </Pressable>
          </TutorialHighlight>
        </View>

        {/* Month Switcher */}
        <View style={[styles.monthSwitcher, { paddingHorizontal: 24, paddingBottom: 24 }]}>
          <Pressable onPress={goPrev} accessibilityRole="button" accessibilityLabel={t("timetable.previous_month_a11y", languageCode)}>
            <ChevronLeft size={24} color={textColor} />
          </Pressable>
          <Text style={[styles.monthLabel, { color: textColor }]}>{monthSwitcherTitle}</Text>
          <Pressable onPress={goNext} accessibilityRole="button" accessibilityLabel={t("timetable.next_month_a11y", languageCode)}>
            <ChevronRight size={24} color={textColor} />
          </Pressable>
        </View>

        {/* Date Strip */}
        {monthData ? (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 24, paddingBottom: 32 }}>
            {monthData.prayerTimes.map((pt) => {
              const sel = pt.date === selectedDay;
              const td = isToday(today, year, month, pt.date);
              return (
                <Pressable
                  key={pt.date}
                  onPress={() => setSelectedDay(pt.date)}
                  style={[
                    styles.dayCell,
                    sel && { backgroundColor: textColor + "1F" },
                  ]}
                  accessibilityRole="button"
                  accessibilityLabel={t("timetable.day_a11y_format", languageCode).replace("%s", String(pt.date))}
                >
                  <Text style={[styles.dayWeekday, { color: sel ? textColor : textColor + "66" }]}>
                    {shortWeekday(pt.date).toUpperCase()}
                  </Text>
                  <Text style={[styles.dayNumber, { color: sel ? textColor : textColor + "80", fontFamily: sel ? "Comfortaa_500Medium" : "Comfortaa_400Regular" }]}>
                    {new Intl.NumberFormat(locale).format(pt.date)}
                  </Text>
                  <View style={{ width: 4, height: 4, borderRadius: 2, backgroundColor: td ? textColor : "transparent", marginTop: 4 }} />
                </Pressable>
              );
            })}
          </ScrollView>
        ) : null}

        {loading ? (
          <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }}>
            <ActivityIndicator color={textColor} />
          </View>
        ) : error || !dayData ? (
          <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }}>
            <Text style={{ color: textColor + "B3", fontFamily: "Comfortaa_400Regular", fontSize: FONT_SIZES.md }}>
              {t("timetable.load_error", languageCode)}
            </Text>
            <Pressable onPress={fetchMonth} accessibilityRole="button" style={{ marginTop: SPACING.sm }}>
              <Text style={{ color: "#47A6FF", fontFamily: "Comfortaa_600SemiBold", fontSize: FONT_SIZES.md }}>
                {t("action.retry", languageCode)}
              </Text>
            </Pressable>
          </View>
        ) : (
          <ScrollView contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: SPACING.xl }}>
            {/* Column Header */}
            <View style={[styles.tableHeader, { paddingHorizontal: 24, paddingBottom: 4 }]}>
              <Text style={[styles.headerCell, styles.nameCell, { color: textColor + "80" }]}>
                {t("timetable.header.prayer", languageCode)}
              </Text>
              <Text style={[styles.headerCell, styles.timeCell, { color: textColor + "80" }]}>
                {t("timetable.header.adhan", languageCode)}
              </Text>
              <Text style={[styles.headerCell, styles.timeCell, { color: textColor + "80" }]}>
                {t("timetable.header.iqamah", languageCode)}
              </Text>
            </View>

            <PrayerRow
              name={t("timetable.header.fajr", languageCode)}
              adhan={dayData.fajr}
              iqamah={timetableIqamahDisplay("fajr", dayData.fajr, iqamah, dayData.maghrib, uses24HourTime, locale)}
              isNext={nextPrayerId === "fajr"}
              isPast={selectedIsToday && dayData.fajr <= currentHHMM}
              uses24HourTime={uses24HourTime}
              locale={locale}
              textColor={textColor}
            />
            <PrayerRow
              name={t("timetable.header.shu", languageCode)}
              adhan={dayData.shurooq}
              iqamah="-"
              isNext={nextPrayerId === "sunrise"}
              isPast={selectedIsToday && dayData.shurooq <= currentHHMM}
              uses24HourTime={uses24HourTime}
              locale={locale}
              textColor={textColor}
            />
            {isFriday ? (
              (() => {
                const rawJummah = resolvedJummahRaw(iqamah, monthData?.jummahIqamah ?? "");
                const jTimes = splitJummahTimes(rawJummah);
                if (jTimes.length === 0) {
                  return (
                    <PrayerRow
                      name={t("prayer.jummah", languageCode)}
                      adhan={dayData.dhuhr}
                      iqamah="-"
                      isNext={nextPrayerId === "dhuhr"}
                      isPast={selectedIsToday && dayData.dhuhr <= currentHHMM}
                      uses24HourTime={uses24HourTime}
                      locale={locale}
                      textColor={textColor}
                    />
                  );
                }
                return jTimes.map((jt, idx) => {
                  const parts = jt.split(/\s+/).filter(Boolean);
                  const iqCell = parts.length >= 2
                    ? `${formatTime(parts[0], uses24HourTime, locale)} \u00b7 ${formatTime(parts[1], uses24HourTime, locale)}`
                    : formatTime(parts[0] ?? jt, uses24HourTime, locale);
                  return (
                    <PrayerRow
                      key={idx}
                      name={t("prayer.jummah", languageCode)}
                      adhan={dayData.dhuhr}
                      iqamah={iqCell}
                      isNext={nextPrayerId === "dhuhr" && idx === 0}
                      isPast={selectedIsToday && dayData.dhuhr <= currentHHMM}
                      uses24HourTime={uses24HourTime}
                      locale={locale}
                      textColor={textColor}
                    />
                  );
                });
              })()
            ) : (
              <PrayerRow
                name={t("timetable.header.dhu", languageCode)}
                adhan={dayData.dhuhr}
                iqamah={timetableIqamahDisplay("dhuhr", dayData.dhuhr, iqamah, dayData.maghrib, uses24HourTime, locale)}
                isNext={nextPrayerId === "dhuhr"}
                isPast={selectedIsToday && dayData.dhuhr <= currentHHMM}
                uses24HourTime={uses24HourTime}
                locale={locale}
                textColor={textColor}
              />
            )}
            <PrayerRow
              name={t("timetable.header.asr", languageCode)}
              adhan={dayData.asr}
              iqamah={timetableIqamahDisplay("asr", dayData.asr, iqamah, dayData.maghrib, uses24HourTime, locale)}
              isNext={nextPrayerId === "asr"}
              isPast={selectedIsToday && dayData.asr <= currentHHMM}
              uses24HourTime={uses24HourTime}
              locale={locale}
              textColor={textColor}
            />
            <PrayerRow
              name={t("timetable.header.mag", languageCode)}
              adhan={dayData.maghrib}
              iqamah={timetableIqamahDisplay("maghrib", dayData.maghrib, iqamah, dayData.maghrib, uses24HourTime, locale)}
              isNext={nextPrayerId === "maghrib"}
              isPast={selectedIsToday && dayData.maghrib <= currentHHMM}
              uses24HourTime={uses24HourTime}
              locale={locale}
              textColor={textColor}
            />
            <PrayerRow
              name={t("timetable.header.ish", languageCode)}
              adhan={dayData.isha}
              iqamah={timetableIqamahDisplay("isha", dayData.isha, iqamah, dayData.maghrib, uses24HourTime, locale)}
              isNext={nextPrayerId === "isha"}
              isPast={selectedIsToday && dayData.isha <= currentHHMM}
              uses24HourTime={uses24HourTime}
              locale={locale}
              textColor={textColor}
            />
          </ScrollView>
        )}
      </SafeAreaView>

      {/* Tutorial Overlay */}
      {currentStep?.type === "exploreTimetable" || currentStep?.type === "closeTimetable" ? (
        <TutorialOverlay
          screen="timetable"
          mosques={[]}
          theme={theme}
          textColor={textColor}
          usesLightForeground={usesLightForeground}
          locale={languageCode}
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  safeArea: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: "center", alignItems: "center" },
  header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  headerDate: { fontSize: 24, fontFamily: "Comfortaa_300Light", lineHeight: 32 },
  headerMosque: { fontSize: 15, fontFamily: "Comfortaa_400Regular", marginTop: 4 },
  closeButton: { width: 36, height: 36, borderRadius: 18, justifyContent: "center", alignItems: "center" },
  monthSwitcher: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  monthLabel: { fontSize: 18, fontFamily: "Comfortaa_500Medium" },
  dayCell: { width: 48, height: 70, borderRadius: 14, justifyContent: "center", alignItems: "center", marginRight: 8 },
  dayWeekday: { fontSize: 10, fontFamily: "Comfortaa_600SemiBold", marginBottom: 4 },
  dayNumber: { fontSize: 20 },
  tableHeader: { flexDirection: "row", alignItems: "center", marginTop: 8 },
  headerCell: { fontSize: 13, fontFamily: "Comfortaa_500Medium" },
  nameCell: { flex: 1 },
  timeCell: { width: 94, maxWidth: 94, textAlign: "right" },
});
