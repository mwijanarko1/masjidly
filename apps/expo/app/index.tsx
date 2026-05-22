import React, { useEffect, useMemo, useRef, useState } from "react";

import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
} from "react-native";
import { useRouter, useLocalSearchParams } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { Calendar, Settings } from "lucide-react-native";
import { AtmosphericSkyBackground } from "@/components/ui/AtmosphericSkyBackground";
import { SPACING, FONT_SIZES } from "@/constants";
import { useHomePrayerData } from "@/lib/hooks/useHomePrayerData";
import { useQiblaDirection } from "@/lib/hooks/useQiblaDirection";
import { PrayerLetterPicker, type PrayerName } from "@/components/ui/PrayerLetterPicker";
import { QiblaPrayerIcon } from "@/components/ui/QiblaPrayerIcon";
import { AdhanMiniPlayerBar } from "@/components/ui/AdhanMiniPlayerBar";
import { useSettingsStore, type AppLanguage } from "@/store/settings";
import { useOnboardingStore } from "@/store/onboarding";
import { TutorialOverlay } from "@/components/onboarding/TutorialOverlay";
import { TutorialHighlight } from "@/components/onboarding/CoachMarkCard";
import { WhatsNewModal } from "@/components/updates/WhatsNewModal";
import {
  formatPrayerClockForDisplay,
  formatPrayerTimeHeroParts,
  getIqamahTime,
  resolveIshaIqamahForDisplay,
  heroCountdownPresentation,
  heroRemainingSeconds,
  heroProgress01,
  formatHeroCountdownClock,
} from "@/lib/prayer/prayerTimesEngine";
import { t, type TranslationKey } from "@/lib/i18n/translations";
import type { HeroCountdownLabelKind } from "@/types/prayer";
import { resolvedLocale, useAppLanguage, getFontScale } from "@/lib/i18n/language";
import {
  themeForPrayer,
  getSkyTheme,
  getTextColor,
  getUsesLightForeground,
  resolveTheme,
} from "@/lib/design/themes";
import { currentMasjidlyFullVersion } from "@/lib/updates/whatsNew";

const BASE_PRAYERS: PrayerName[] = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
const FRIDAY_PRAYERS: PrayerName[] = ["Fajr", "Sunrise", "Jummah", "Asr", "Maghrib", "Isha"];

function isFridayInSheffield(date: Date): boolean {
  const cal = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London",
    weekday: "short",
  });
  return cal.format(date).toLowerCase().startsWith("f");
}

function getPrimaryJummahTime(
  prayerTimes: ReturnType<typeof useHomePrayerData>["displayedPrayerTimes"],
  iqamahTimes: ReturnType<typeof useHomePrayerData>["iqamahTimes"]
): string {
  const raw = iqamahTimes?.jummah ?? "";
  const first = raw
    .split(",")
    .map((s) => s.trim())
    .find((s) => s.length > 0);
  return first ?? prayerTimes?.dhuhr ?? "";
}

function getIqamahForSelectedPrayer(
  selected: PrayerName,
  prayerTimes: ReturnType<typeof useHomePrayerData>["displayedPrayerTimes"],
  iqamahTimes: ReturnType<typeof useHomePrayerData>["iqamahTimes"],
  mosqueSlug: string
): string | null {
  if (!prayerTimes || !iqamahTimes) return null;

  const now = new Date();

  switch (selected) {
    case "Fajr": {
      return getIqamahTime("fajr", prayerTimes.fajr, iqamahTimes);
    }
    case "Dhuhr": {
      if (isFridayInSheffield(now)) return null;
      return getIqamahTime("dhuhr", prayerTimes.dhuhr, iqamahTimes);
    }
    case "Jummah": {
      return null;
    }
    case "Asr": {
      return getIqamahTime("asr", prayerTimes.asr, iqamahTimes);
    }
    case "Maghrib": {
      return getIqamahTime("maghrib", prayerTimes.maghrib, iqamahTimes);
    }
    case "Isha": {
      return resolveIshaIqamahForDisplay(
          mosqueSlug,
          now,
          prayerTimes.isha,
          iqamahTimes,
          prayerTimes.maghrib
      );
    }
    case "Sunrise":
      return null;
  }
}

function heroCountdownLabelKey(kind: HeroCountdownLabelKind): TranslationKey {
  switch (kind) {
    case "adhanIn":
      return "home.countdown.adhan_in";
    case "iqamahIn":
      return "home.countdown.iqamah_in";
    case "nextPrayer":
      return "home.countdown.next_prayer";
  }
}

function formatTime(time: string, uses24h: boolean, locale: string): string {
  if (!time) return "";
  return formatPrayerClockForDisplay(time, uses24h, locale);
}

function gregorianDateString(date: Date, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    weekday: "long",
    day: "numeric",
    month: "long",
  })
      .format(date)
      .toUpperCase();
}

function hijriDateString(date: Date, locale: string): string {
  try {
    return new Intl.DateTimeFormat(locale, {
      calendar: "islamic-umalqura",
      day: "numeric",
      month: "long",
      year: "numeric",
    })
        .format(date)
        .toUpperCase();
  } catch {
    try {
      return new Intl.DateTimeFormat(locale, {
        calendar: "islamic",
        day: "numeric",
        month: "long",
        year: "numeric",
      })
          .format(date)
          .toUpperCase();
    } catch {
      return "";
    }
  }
}

function resolveInitialPrayer(nextName: string | null | undefined): PrayerName {
  if (!nextName) return "Fajr";
  if (nextName === "Jummah") return "Jummah";
  const found = BASE_PRAYERS.find((p) => p === nextName);
  return found ?? "Fajr";
}

function translatePrayerName(name: PrayerName, lang: AppLanguage): string {
  const keyMap: Record<PrayerName, TranslationKey> = {
    Fajr: "prayer.fajr",
    Sunrise: "prayer.sunrise",
    Dhuhr: "prayer.dhuhr",
    Jummah: "prayer.jummah",
    Asr: "prayer.asr",
    Maghrib: "prayer.maghrib",
    Isha: "prayer.isha",
  };
  return t(keyMap[name], lang);
}

export default function HomeScreen() {
  const router = useRouter();
  const { showWhatsNew } = useLocalSearchParams<{ showWhatsNew?: string }>();
  const {
    loadState,
    mosques,
    displayedPrayerTimes,
    iqamahTimes,
    nextCountdown,
    refresh,
    selectedMosque,
  } = useHomePrayerData();
  const uses24HourTime = useSettingsStore((s) => s.uses24HourTime);
  const hideQiblaCompass = useSettingsStore((s) => s.hideQiblaCompass);
  const hasCompletedOnboarding = useSettingsStore((s) => s.hasCompletedOnboarding);
  const lastSeenBuildVersion = useSettingsStore((s) => s.lastSeenBuildVersion);
  const setLastSeenBuildVersion = useSettingsStore((s) => s.setLastSeenBuildVersion);
  const themeMode = useSettingsStore((s) => s.themeMode);
  const fixedTheme = useSettingsStore((s) => s.fixedTheme);
  const languageCode = useAppLanguage();
  const locale = resolvedLocale(languageCode);
  const fontScale = getFontScale(languageCode);


  const [selectedPrayer, setSelectedPrayer] = useState<PrayerName>("Fajr");
  const [showingWhatsNew, setShowingWhatsNew] = useState(false);
  const [heroCountdownVisible, setHeroCountdownVisible] = useState(false);
  const [heroCountdownLocked, setHeroCountdownLocked] = useState(false);
  const [heroTick, setHeroTick] = useState(0);

  const onboarding = useOnboardingStore();
  const currentStep = onboarding.currentStep;
  const tutorialStarted = useRef(false);
  const prayers = isFridayInSheffield(new Date()) ? FRIDAY_PRAYERS : BASE_PRAYERS;
  useEffect(() => {
    if (!tutorialStarted.current && mosques.length > 0) {
      tutorialStarted.current = true;
      onboarding.startIfNeeded(mosques);
    }
  }, [mosques, onboarding]);

  const handlePrayerSelect = (prayer: PrayerName) => {
    setSelectedPrayer(prayer);
    if (currentStep?.type === "prayerShortcut") {
      const idx = prayers.indexOf(prayer);
      if (idx === currentStep.index) {
        onboarding.handlePrayerShortcutTap(idx);
      }
    }
  };

  // ── End Onboarding ──

  const dismissWhatsNew = () => {
    setShowingWhatsNew(false);
    setLastSeenBuildVersion(currentMasjidlyFullVersion());
  };

  useEffect(() => {
    if (!hasCompletedOnboarding) return;
    if (loadState === "loading" || loadState === "idle") return;
    const currentBuild = currentMasjidlyFullVersion();
    if (lastSeenBuildVersion !== currentBuild) {
      setShowingWhatsNew(true);
    }
  }, [hasCompletedOnboarding, lastSeenBuildVersion, loadState]);

  useEffect(() => {
    if (showWhatsNew === "1") {
      setShowingWhatsNew(true);
    }
  }, [showWhatsNew]);

  useEffect(() => {
    if (nextCountdown?.nextName) {
      setSelectedPrayer(resolveInitialPrayer(nextCountdown.nextName));
    }
  }, [nextCountdown?.nextName]);

  const now = useMemo(() => new Date(), []);
  const gregorian = gregorianDateString(now, locale);
  const hijri = hijriDateString(now, locale);

  const mosqueSlug = selectedMosque?.slug ?? "";

  const heroCountdownEnabled = Boolean(
    displayedPrayerTimes && iqamahTimes && mosqueSlug
  );

  const showHeroCountdown = heroCountdownVisible || heroCountdownLocked;

  useEffect(() => {
    if (!showHeroCountdown) return;
    const id = setInterval(() => setHeroTick((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, [showHeroCountdown]);

  const iqamah = getIqamahForSelectedPrayer(
    selectedPrayer,
    displayedPrayerTimes,
    iqamahTimes,
    mosqueSlug
  );

  const adhanTime = useMemo(() => {
    if (!displayedPrayerTimes) return "";
    switch (selectedPrayer) {
      case "Fajr":
        return displayedPrayerTimes.fajr;
      case "Sunrise":
        return displayedPrayerTimes.sunrise;
      case "Dhuhr":
        return isFridayInSheffield(new Date()) ? getPrimaryJummahTime(displayedPrayerTimes, iqamahTimes) : displayedPrayerTimes.dhuhr;
      case "Jummah":
        return getPrimaryJummahTime(displayedPrayerTimes, iqamahTimes);
      case "Asr":
        return displayedPrayerTimes.asr;
      case "Maghrib":
        return displayedPrayerTimes.maghrib;
      case "Isha":
        return displayedPrayerTimes.isha;
    }
  }, [displayedPrayerTimes, iqamahTimes, selectedPrayer]);

  const dynamicTheme = themeForPrayer(selectedPrayer);
  const theme = resolveTheme(dynamicTheme, themeMode, fixedTheme);
  const sky = getSkyTheme(theme);
  const textColor = getTextColor(theme);
  const usesLightForeground = getUsesLightForeground(theme);

  const { animatedRotation } = useQiblaDirection({
    fallbackMosque: selectedMosque,
    enabled: selectedMosque !== null && !hideQiblaCompass,
    deferAuthorization: !hasCompletedOnboarding || hideQiblaCompass,
  });

  const heroOrbCountdown = useMemo(() => {
    void heroTick;
    if (!displayedPrayerTimes || !iqamahTimes || !mosqueSlug) {
      return { label: "", time: "", progress: 0 };
    }
    const tickNow = new Date();
    const pres = heroCountdownPresentation(
      displayedPrayerTimes,
      iqamahTimes,
      mosqueSlug,
      tickNow
    );
    if (!pres) return { label: "", time: "", progress: 0 };
    const secs = heroRemainingSeconds(pres, tickNow);
    return {
      label: t(heroCountdownLabelKey(pres.labelKind), languageCode),
      time: formatHeroCountdownClock(secs),
      progress: heroProgress01(pres, tickNow),
    };
  }, [
    heroTick,
    displayedPrayerTimes,
    iqamahTimes,
    mosqueSlug,
    languageCode,
  ]);

  const onHeroOrbPress = () => {
    if (!heroCountdownEnabled) return;
    if (heroCountdownLocked) {
      setHeroCountdownLocked(false);
      setHeroCountdownVisible(false);
      return;
    }
    setHeroCountdownVisible((v) => !v);
  };

  const onHeroOrbLongPress = () => {
    if (!heroCountdownEnabled) return;
    setHeroCountdownLocked(true);
    setHeroCountdownVisible(true);
  };

  const heroOrbA11yLabel = showHeroCountdown
    ? `${heroOrbCountdown.label}, ${heroOrbCountdown.time}`
    : t("onboarding.qibla.title", languageCode);

  const heroParts = useMemo(() => {
    if (!adhanTime) return { clock: "--:--", meridiem: null as string | null };
    return formatPrayerTimeHeroParts(adhanTime, uses24HourTime, locale);
  }, [adhanTime, uses24HourTime, locale]);

  if (loadState === "loading" || loadState === "idle") {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: sky.baseColors[0] }]}>
        <ActivityIndicator testID="home-loading" size="large" color="#47A6FF" />
      </View>
    );
  }

  if (loadState === "empty") {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: sky.baseColors[0] }]}>
        <Text style={styles.emptyText}>{t("home.empty.no_mosque_data", languageCode)}</Text>
        <Pressable style={styles.retryButton} onPress={refresh} accessibilityRole="button">
          <Text style={styles.retryButtonText}>{t("action.retry", languageCode)}</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <AtmosphericSkyBackground sky={sky} variant="home" />

      <SafeAreaView style={styles.safeArea}>
        <View style={styles.content}>
          {/* Top Chrome */}
          <View style={styles.topRow}>
            <TutorialHighlight
              isHighlighted={currentStep?.type === "openTimetable"}
              size={44}
              color={textColor}
            >
              <Pressable
                style={[styles.iconButton, { backgroundColor: "rgba(255,255,255,0.18)" }]}
                onPress={() => {
                  if (currentStep?.type === "openTimetable") {
                    onboarding.handleTimetableOpened();
                  }
                  router.push({ pathname: "/timetable", params: { theme: selectedPrayer, mosqueName: selectedMosque?.name ?? "" } });
                }}
                accessibilityRole="button"
                accessibilityLabel={t("accessibility.timetable", languageCode)}
              >
                <Calendar size={20} color={textColor} strokeWidth={1.5} />
              </Pressable>
            </TutorialHighlight>

            <View style={styles.dateContainer}>
              <Text
                style={[
                  styles.gregorianDate,
                  { color: textColor + "99", letterSpacing: 1.0, fontSize: 13 * fontScale },
                ]}
              >
                {gregorian}
              </Text>
              {hijri ? (
                <Text
                  style={[
                    styles.hijriDate,
                    { color: textColor + "66", letterSpacing: 0.8, fontSize: 10 * fontScale },
                  ]}
                >
                  {hijri}
                </Text>
              ) : null}
            </View>

            <TutorialHighlight
              isHighlighted={currentStep?.type === "openSettings"}
              size={44}
              color={textColor}
            >
              <Pressable
                style={[styles.iconButton, { backgroundColor: "rgba(255,255,255,0.18)" }]}
                onPress={() => {
                  if (currentStep?.type === "openSettings") {
                    onboarding.handleSettingsOpened();
                  }
                  router.push({ pathname: "/settings", params: { theme: selectedPrayer } });
                }}
                accessibilityRole="button"
                accessibilityLabel={t("accessibility.settings", languageCode)}
              >
                <Settings size={20} color={textColor} strokeWidth={1.5} />
              </Pressable>
            </TutorialHighlight>
          </View>

          {/* Main Prayer Content */}
          <View style={styles.mainContent}>
            <View style={{ paddingTop: 40, alignItems: "center" }}>
              <TutorialHighlight
                isHighlighted={currentStep?.type === "qibla"}
                size={88}
                color={textColor}
              >
                <Pressable
                  onPress={onHeroOrbPress}
                  onLongPress={onHeroOrbLongPress}
                  delayLongPress={450}
                  disabled={!heroCountdownEnabled}
                  accessibilityRole={heroCountdownEnabled ? "button" : "image"}
                  accessibilityLabel={heroOrbA11yLabel}
                  accessibilityHint={
                    heroCountdownEnabled
                      ? t("home.countdown.a11y.hint", languageCode)
                      : undefined
                  }
                  testID="HeroPrayerOrb"
                >
                  <QiblaPrayerIcon
                    theme={theme}
                    animatedRotation={
                      !hideQiblaCompass ? animatedRotation : undefined
                    }
                    showCountdown={showHeroCountdown}
                    countdownLabel={heroOrbCountdown.label}
                    countdownTime={heroOrbCountdown.time}
                    countdownProgress={heroOrbCountdown.progress}
                  />
                </Pressable>
              </TutorialHighlight>
            </View>

            <View style={{ marginTop: 32, alignItems: "center" }}>
              {/* Hero Clock */}
              <View style={{ flexDirection: "row", alignItems: "baseline" }}>
                <Text style={[styles.heroClock, { color: textColor, fontSize: 88 * fontScale, lineHeight: 96 * fontScale }]}>
                  {heroParts.clock}
                </Text>
                {heroParts.meridiem ? (
                  <Text
                    style={[
                      styles.heroClock,
                      {
                        color: textColor,
                        fontSize: 48 * fontScale,
                        letterSpacing: 0,
                        marginLeft: 6,
                      },
                    ]}
                  >
                    {heroParts.meridiem}
                  </Text>
                ) : null}
              </View>

              {/* Iqamah Subtitle */}
              {iqamah ? (
                <Text
                  style={[
                    styles.iqamahText,
                    { color: textColor + "C7", fontSize: 26 * fontScale },
                  ]}
                >
                  {t("home.iqamah_format", languageCode).replace(
                    "%s",
                    formatTime(iqamah, uses24HourTime, locale)
                  )}
                </Text>
              ) : null}
            </View>

            <View style={{ flex: 1 }} />

            {/* Bottom: Prayer Name + Letter Picker */}
            <View style={{ alignItems: "center", paddingBottom: 80, gap: 24 }}>
              <Text style={[styles.prayerName, { color: textColor, fontSize: 36 * fontScale }]}>
                {translatePrayerName(selectedPrayer, languageCode)}
              </Text>

              <PrayerLetterPicker
                prayers={prayers}
                selectedPrayer={selectedPrayer}
                onSelectPrayer={handlePrayerSelect}
                theme={theme}
                highlightedPrayerIndex={
                  currentStep?.type === "prayerShortcut"
                    ? currentStep.index
                    : undefined
                }
              />
            </View>
          </View>

          {loadState === "error" ? (
            <Pressable style={styles.compactRetry} onPress={refresh} accessibilityRole="button">
              <Text style={styles.compactRetryText}>{t("action.retry", languageCode)}</Text>
            </Pressable>
          ) : null}
        </View>

        <AdhanMiniPlayerBar textColor={textColor} />

      </SafeAreaView>

      {/* Tutorial Overlay */}
      {currentStep ? (
        <TutorialOverlay
          screen="home"
          mosques={mosques}
          theme={theme}
          textColor={textColor}
          usesLightForeground={usesLightForeground}
          locale={languageCode}
        />
      ) : null}

      <WhatsNewModal
        visible={showingWhatsNew && !currentStep}
        theme={theme}
        language={languageCode}
        onDismiss={dismissWhatsNew}
        onAction={(action) => {
          if (action === "settings") {
            router.push({ pathname: "/settings", params: { theme: selectedPrayer } });
          } else if (action === "timetable") {
            router.push({ pathname: "/timetable", params: { theme: selectedPrayer, mosqueName: selectedMosque?.name ?? "" } });
          }
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: SPACING.md,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
  },
  emptyText: {
    fontSize: FONT_SIZES.md,
    color: "#9095A1",
    marginBottom: SPACING.md,
    fontFamily: "Comfortaa_400Regular",
  },
  retryButton: {
    backgroundColor: "#47A6FF",
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm,
    borderRadius: 8,
  },
  retryButtonText: {
    color: "#FFFFFF",
    fontSize: FONT_SIZES.md,
    fontFamily: "Comfortaa_600SemiBold",
  },
  topRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingTop: SPACING.sm,
    zIndex: 1,
  },
  iconButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: "center",
    alignItems: "center",
  },
  dateContainer: {
    flex: 1,
    alignItems: "center",
    paddingHorizontal: SPACING.sm,
  },
  gregorianDate: {
    fontSize: 13,
    fontFamily: "Comfortaa_600SemiBold",
    textAlign: "center",
  },
  hijriDate: {
    fontSize: 10,
    fontFamily: "Comfortaa_500Medium",
    textAlign: "center",
    marginTop: 2,
  },
  mainContent: {
    flex: 1,
    zIndex: 1,
  },
  heroClock: {
    fontSize: 88,
    fontFamily: "Comfortaa_300Light",
    letterSpacing: -1.76,
    lineHeight: 96,
    textShadowColor: "rgba(0,0,0,0.1)",
    textShadowRadius: 10,
    textShadowOffset: { width: 0, height: 5 },
  },
  iqamahText: {
    fontSize: 26,
    fontFamily: "Comfortaa_400Regular",
    letterSpacing: 0.6,
    marginTop: 6,
    textAlign: "center",
  },
  prayerName: {
    fontSize: 36,
    fontFamily: "Comfortaa_400Regular",
    letterSpacing: -0.36,
    textAlign: "center",
  },
  compactRetry: {
    alignSelf: "center",
    marginBottom: SPACING.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.xs,
    backgroundColor: "rgba(71,166,255,0.12)",
    borderRadius: 8,
  },
  compactRetryText: {
    color: "#47A6FF",
    fontSize: FONT_SIZES.sm,
    fontFamily: "Comfortaa_600SemiBold",
  },
});
