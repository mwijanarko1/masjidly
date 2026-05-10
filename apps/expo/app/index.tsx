import React, { useEffect, useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  Image,
  ScrollView,
  Dimensions,
} from "react-native";
import { useRouter } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { Calendar, Settings } from "lucide-react-native";
import { LinearGradient } from "expo-linear-gradient";
import { BlurView } from "expo-blur";
import { COLORS, SPACING, FONT_SIZES } from "@/constants";
import { useHomePrayerData } from "@/lib/hooks/useHomePrayerData";
import { PrayerCarousel, type PrayerName } from "@/components/ui/PrayerCarousel";
import { useSettingsStore } from "@/store/settings";
import { formatTo12Hour } from "@/lib/prayer/prayerTimesEngine";
import { t } from "@/lib/i18n/translations";
import { resolvedLanguageCode } from "@/lib/i18n/language";
import { getLocales } from "expo-localization";

const PRAYERS: PrayerName[] = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];

function getIqamahForSelectedPrayer(
  selected: PrayerName,
  prayerTimes: ReturnType<typeof useHomePrayerData>["displayedPrayerTimes"],
  iqamahTimes: ReturnType<typeof useHomePrayerData>["iqamahTimes"]
): string | null {
  if (!prayerTimes || !iqamahTimes) return null;
  switch (selected) {
    case "Fajr":
      return iqamahTimes.fajr !== prayerTimes.fajr ? iqamahTimes.fajr : null;
    case "Dhuhr":
      return iqamahTimes.dhuhr !== prayerTimes.dhuhr ? iqamahTimes.dhuhr : null;
    case "Asr":
      return iqamahTimes.asr !== prayerTimes.asr ? iqamahTimes.asr : null;
    case "Maghrib":
      return iqamahTimes.maghrib !== prayerTimes.maghrib ? iqamahTimes.maghrib : null;
    case "Isha":
      return iqamahTimes.isha !== prayerTimes.isha ? iqamahTimes.isha : null;
    case "Sunrise":
      return null;
  }
}

function formatTime(time: string, uses24h: boolean): string {
  if (uses24h) return time;
  return formatTo12Hour(time);
}

function gregorianDateString(date: Date, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    weekday: "long", day: "numeric", month: "long",
  }).format(date).toUpperCase();
}

function hijriDateString(date: Date, locale: string): string {
  try {
    return new Intl.DateTimeFormat(locale, {
      calendar: "islamic-umalqura", day: "numeric", month: "long", year: "numeric",
    }).format(date).toUpperCase();
  } catch {
    try {
      return new Intl.DateTimeFormat(locale, {
        calendar: "islamic", day: "numeric", month: "long", year: "numeric",
      }).format(date).toUpperCase();
    } catch {
      return "";
    }
  }
}

function resolveInitialPrayer(nextName: string | null | undefined): PrayerName {
  if (!nextName) return "Fajr";
  if (nextName === "Jummah") return "Dhuhr";
  const found = PRAYERS.find((p) => p === nextName);
  return found ?? "Fajr";
}

const prayerImages: Record<PrayerName, ReturnType<typeof require>> = {
  Fajr: require("@/assets/prayers/fajr.png"),
  Sunrise: require("@/assets/prayers/fajr.png"),
  Dhuhr: require("@/assets/prayers/dhuhr.png"),
  Asr: require("@/assets/prayers/asr.png"),
  Maghrib: require("@/assets/prayers/maghrib.png"),
  Isha: require("@/assets/prayers/isha.png"),
};

export default function HomeScreen() {
  const router = useRouter();
  const {
    loadState,
    displayedPrayerTimes,
    iqamahTimes,
    nextCountdown,
    refresh,
  } = useHomePrayerData();
  const uses24HourTime = useSettingsStore((s) => s.uses24HourTime);
  const appLanguage = useSettingsStore((s) => s.appLanguage);
  const systemLocale = getLocales()[0].languageTag;
  const languageCode = resolvedLanguageCode(appLanguage, systemLocale);

  const [selectedPrayer, setSelectedPrayer] = useState<PrayerName>("Fajr");

  useEffect(() => {
    if (nextCountdown?.nextName) {
      setSelectedPrayer(resolveInitialPrayer(nextCountdown.nextName));
    }
  }, [nextCountdown?.nextName]);

  const now = useMemo(() => new Date(), []);
  const gregorian = gregorianDateString(now, systemLocale);
  const hijri = hijriDateString(now, systemLocale);

  const iqamah = getIqamahForSelectedPrayer(selectedPrayer, displayedPrayerTimes, iqamahTimes);

  const adhanTime = useMemo(() => {
    if (!displayedPrayerTimes) return "";
    switch (selectedPrayer) {
      case "Fajr": return displayedPrayerTimes.fajr;
      case "Sunrise": return displayedPrayerTimes.sunrise;
      case "Dhuhr": return displayedPrayerTimes.dhuhr;
      case "Asr": return displayedPrayerTimes.asr;
      case "Maghrib": return displayedPrayerTimes.maghrib;
      case "Isha": return displayedPrayerTimes.isha;
    }
  }, [displayedPrayerTimes, selectedPrayer]);

  if (loadState === "loading" || loadState === "idle") {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator testID="home-loading" size="large" color={COLORS.accent} />
      </View>
    );
  }

  if (loadState === "empty") {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.emptyText}>No mosque data available</Text>
        <Pressable style={styles.retryButton} onPress={refresh} accessibilityRole="button">
          <Text style={styles.retryButtonText}>Retry</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <LinearGradient colors={[COLORS.background, COLORS.backgroundSecondary]} style={styles.gradient}>
      <SafeAreaView style={styles.safeArea}>
        <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
          <View style={styles.bloomContainer}>
            <BlurView intensity={60} style={styles.bloom}>
              <View style={styles.bloomCircle} />
            </BlurView>
          </View>

          <View style={styles.topRow}>
            <Pressable style={styles.iconButton} onPress={() => router.push("/timetable")}
              accessibilityRole="button" accessibilityLabel={t("accessibility.timetable", languageCode)}>
              <Calendar size={20} color={COLORS.primary} />
            </Pressable>
            <View style={styles.dateContainer}>
              <Text style={styles.gregorianDate}>{gregorian}</Text>
              {hijri ? <Text style={styles.hijriDate}>{hijri}</Text> : null}
            </View>
            <Pressable style={styles.iconButton} onPress={() => router.push("/settings")}
              accessibilityRole="button" accessibilityLabel={t("accessibility.settings", languageCode)}>
              <Settings size={20} color={COLORS.primary} />
            </Pressable>
          </View>

          <View style={styles.mainContent}>
            <Image source={prayerImages[selectedPrayer]} style={styles.prayerImage} resizeMode="contain" />
            <Text style={styles.prayerName}>{selectedPrayer}</Text>
            <Text style={styles.adhanTime}>
              {adhanTime ? formatTime(adhanTime, uses24HourTime) : "--:--"}
            </Text>
            {iqamah ? (
              <Text style={styles.iqamahText}>
                {t("home.iqamah_format", languageCode).replace("%s", formatTime(iqamah, uses24HourTime))}
              </Text>
            ) : null}
          </View>

          {loadState === "error" ? (
            <Pressable style={styles.compactRetry} onPress={refresh} accessibilityRole="button">
              <Text style={styles.compactRetryText}>Retry</Text>
            </Pressable>
          ) : null}
        </ScrollView>

        <View style={styles.carouselContainer}>
          <PrayerCarousel
            prayers={PRAYERS}
            selectedPrayer={selectedPrayer}
            onSelectPrayer={setSelectedPrayer}
            prayerTimes={displayedPrayerTimes}
            iqamahTimes={iqamahTimes}
            uses24HourTime={uses24HourTime}
            languageCode={languageCode}
          />
        </View>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  safeArea: { flex: 1 },
  scrollContent: { flexGrow: 1, paddingHorizontal: SPACING.md },
  loadingContainer: {
    flex: 1, justifyContent: "center", alignItems: "center", backgroundColor: COLORS.background,
  },
  emptyText: { fontSize: FONT_SIZES.md, color: COLORS.secondary, marginBottom: SPACING.md },
  retryButton: {
    backgroundColor: COLORS.accent, paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm, borderRadius: 8,
  },
  retryButtonText: { color: COLORS.background, fontSize: FONT_SIZES.md, fontWeight: "600" },
  bloomContainer: {
    position: "absolute", top: -60,
    left: Dimensions.get("window").width / 2 - 150, width: 300, height: 300, zIndex: 0,
  },
  bloom: { width: 300, height: 300, borderRadius: 150, overflow: "hidden" },
  bloomCircle: { width: 300, height: 300, borderRadius: 150, backgroundColor: COLORS.accent, opacity: 0.12 },
  topRow: {
    flexDirection: "row", alignItems: "center", justifyContent: "space-between",
    paddingTop: SPACING.sm, zIndex: 1,
  },
  iconButton: {
    width: 44, height: 44, borderRadius: 22,
    backgroundColor: `${COLORS.background}30`, justifyContent: "center", alignItems: "center",
  },
  dateContainer: { flex: 1, alignItems: "center", paddingHorizontal: SPACING.sm },
  gregorianDate: {
    fontSize: FONT_SIZES.sm, fontWeight: "600", color: COLORS.secondary,
    opacity: 0.6, textTransform: "uppercase", textAlign: "center",
  },
  hijriDate: {
    fontSize: FONT_SIZES.xs, fontWeight: "500", color: COLORS.secondary,
    opacity: 0.4, textTransform: "uppercase", textAlign: "center", marginTop: 2,
  },
  mainContent: {
    flex: 1, justifyContent: "center", alignItems: "center",
    paddingVertical: SPACING.xl, zIndex: 1,
  },
  prayerImage: { width: 200, height: 200, marginBottom: SPACING.md },
  prayerName: { fontSize: FONT_SIZES.xxl, fontWeight: "500", color: COLORS.primary, marginBottom: SPACING.sm },
  adhanTime: { fontSize: 72, fontWeight: "bold", color: COLORS.primary, lineHeight: 80 },
  iqamahText: { fontSize: FONT_SIZES.md, color: COLORS.secondary, marginTop: SPACING.sm },
  compactRetry: {
    alignSelf: "center", marginBottom: SPACING.md,
    paddingHorizontal: SPACING.md, paddingVertical: SPACING.xs,
    backgroundColor: `${COLORS.accent}20`, borderRadius: 8,
  },
  compactRetryText: { color: COLORS.accent, fontSize: FONT_SIZES.sm, fontWeight: "600" },
  carouselContainer: { paddingBottom: SPACING.lg, zIndex: 1 },
});
