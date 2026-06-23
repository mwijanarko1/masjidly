import React, { useEffect, useMemo, useRef, useState } from "react";

import {
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
  Linking,
  Animated,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { useLocalSearchParams } from "expo-router";
import { useAppOverlayStore } from "@/store/appOverlay";
import { SafeAreaView } from "react-native-safe-area-context";
import { Calendar, ChevronLeft, ChevronRight, Settings } from "lucide-react-native";
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
  checkNotificationPermissionIssue,
  requestNotificationPermission,
  fixNotificationMasterEnabled,
  type NotificationPermissionIssue,
} from "@/lib/notifications/notificationPermissionCheck";
import { NotificationRecoveryModal } from "@/components/notifications/NotificationRecoveryModal";
import {
  rescheduleUpcomingPrayerNotifications,
} from "@/lib/notifications/prayerNotifications";
import {
  formatPrayerClockForDisplay,
  formatPrayerTimeHeroParts,
  getDisplayIqamah,
  selectAsrIqamahTime,
  heroCountdownPresentation,
  heroRemainingSeconds,
  heroProgress01,
  formatHeroCountdownClock,
  splitJummahIqamahTimes,
} from "@/lib/prayer/prayerTimesEngine";
import { t, type TranslationKey } from "@/lib/i18n/translations";
import type { DailyPrayerTimes, DailyIqamahTimes, HeroCountdownLabelKind, NextPrayerCountdownResult, AsrIqamahPreference } from "@/types/prayer";
import { resolvedLocale, useAppLanguage, getFontScale } from "@/lib/i18n/language";
import {
  themeForPrayer,
  getSkyTheme,
  getTextColor,
  getUsesLightForeground,
  resolveTheme,
  type TimeTheme,
} from "@/lib/design/themes";
import { currentMasjidlyFullVersion } from "@/lib/updates/whatsNew";

const BASE_PRAYERS: PrayerName[] = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];
const FRIDAY_PRAYERS: PrayerName[] = ["Fajr", "Sunrise", "Jummah", "Asr", "Maghrib", "Isha"];
const SUPPORT_EMAIL = "mikhailbuilds@gmail.com";

function openMissingPrayerTimesEmail(input: {
  mosqueName: string;
  monthLabel: string;
  languageCode: AppLanguage;
}) {
  const subject = t("home.missing_times.email_subject", input.languageCode)
    .replace("%s", input.mosqueName)
    .replace("%s", input.monthLabel);
  const body = t("home.missing_times.email_body", input.languageCode)
    .replace("%s", input.mosqueName)
    .replace("%s", input.monthLabel);
  const mailto = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  Linking.openURL(mailto).catch(() => {
    // Fail silently if no mail client is configured.
  });
}

function isFridayInSheffield(date: Date): boolean {
  const cal = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London",
    weekday: "short",
  });
  return cal.format(date).toLowerCase().startsWith("f");
}

function isSameSheffieldDay(a: Date, b: Date): boolean {
  const formatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(a) === formatter.format(b);
}

function getPrimaryJummahTime(
  prayerTimes: ReturnType<typeof useHomePrayerData>["displayedPrayerTimes"],
  iqamahTimes: ReturnType<typeof useHomePrayerData>["iqamahTimes"]
): string {
  const times = splitJummahIqamahTimes(iqamahTimes?.jummah ?? "");
  return times[0] ?? prayerTimes?.dhuhr ?? "";
}

function getSecondJummahTime(
  iqamahTimes: ReturnType<typeof useHomePrayerData>["iqamahTimes"]
): string | null {
  const times = splitJummahIqamahTimes(iqamahTimes?.jummah ?? "");
  return times.length >= 2 ? times[1] : null;
}

function getIqamahForSelectedPrayer(
  selected: PrayerName,
  prayerTimes: ReturnType<typeof useHomePrayerData>["displayedPrayerTimes"],
  iqamahTimes: ReturnType<typeof useHomePrayerData>["iqamahTimes"],
  mosqueSlug: string,
  asrIqamahPreference: "first" | "second",
  displayedDate: Date
): string | null {
  if (!prayerTimes || !iqamahTimes) return null;

  const now = displayedDate;

  switch (selected) {
    case "Fajr":
    case "Dhuhr":
    case "Maghrib":
    case "Isha": {
      if (selected === "Dhuhr" && isFridayInSheffield(now)) return null;
      return getDisplayIqamah(
        selected.toLowerCase(),
        prayerTimes[selected.toLowerCase() as keyof DailyPrayerTimes] as string,
        iqamahTimes,
        mosqueSlug,
        now,
        prayerTimes.maghrib
      );
    }
    case "Asr":
      return selectAsrIqamahTime(iqamahTimes.asr, prayerTimes.asr, asrIqamahPreference);
    case "Sunrise":
    case "Jummah":
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

/**
 * Self-contained hero orb that isolates the 1s countdown tick state from the parent HomeScreen.
 * Only this sub-component re-renders each second, preventing full-page re-renders.
 */
const HeroOrbSection = React.memo(function HeroOrbSection({
  nextCountdown,
  displayedPrayerTimes,
  iqamahTimes,
  mosqueSlug,
  asrIqamahPreference,
  languageCode,
  theme,
  hideQiblaCompass,
  animatedRotation,
  textColor,
}: {
  nextCountdown: NextPrayerCountdownResult | null;
  displayedPrayerTimes: DailyPrayerTimes | null;
  iqamahTimes: DailyIqamahTimes | null;
  mosqueSlug: string;
  asrIqamahPreference: AsrIqamahPreference;
  languageCode: AppLanguage;
  theme: TimeTheme;
  hideQiblaCompass: boolean;
  animatedRotation?: Animated.Value;
  textColor: string;
}) {
  const [visible, setVisible] = useState(false);
  const [locked, setLocked] = useState(false);
  const [tick, setTick] = useState(0);

  const showCountdown = visible || locked;

  useEffect(() => {
    if (!showCountdown) return;
    const id = setInterval(() => setTick((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, [showCountdown]);

  const orbCountdown = useMemo(() => {
    void tick;
    if (!nextCountdown || !displayedPrayerTimes || !iqamahTimes || !mosqueSlug) {
      return { hasCountdown: false, label: "", time: "", progress: 0 };
    }
    const tickNow = new Date();
    const pres = heroCountdownPresentation(
      displayedPrayerTimes,
      iqamahTimes,
      mosqueSlug,
      tickNow,
      asrIqamahPreference
    );
    if (!pres) return { hasCountdown: false, label: "", time: "", progress: 0 };
    const secs = heroRemainingSeconds(pres, tickNow);
    return {
      hasCountdown: true,
      label: t(heroCountdownLabelKey(pres.labelKind), languageCode),
      time: formatHeroCountdownClock(secs),
      progress: heroProgress01(pres, tickNow),
    };
  }, [
    tick,
    displayedPrayerTimes,
    iqamahTimes,
    mosqueSlug,
    languageCode,
    asrIqamahPreference,
    nextCountdown,
  ]);

  const countdownEnabled = orbCountdown.hasCountdown;

  const handlePress = () => {
    if (!countdownEnabled) return;
    if (locked) {
      setLocked(false);
      setVisible(false);
      return;
    }
    setVisible((v) => !v);
  };

  const handleLongPress = () => {
    if (!countdownEnabled) return;
    setLocked(true);
    setVisible(true);
  };

  const a11yLabel = showCountdown
    ? `${orbCountdown.label}, ${orbCountdown.time}`
    : t("onboarding.qibla.title", languageCode);

  return (
    <Pressable
      onPress={handlePress}
      onLongPress={handleLongPress}
      delayLongPress={450}
      disabled={!countdownEnabled}
      accessibilityRole={countdownEnabled ? "button" : "image"}
      accessibilityLabel={a11yLabel}
      accessibilityHint={
        countdownEnabled
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
        showCountdown={showCountdown && countdownEnabled}
        countdownLabel={orbCountdown.label}
        countdownTime={orbCountdown.time}
        countdownProgress={orbCountdown.progress}
      />
    </Pressable>
  );
});


export default function HomeScreen() {
  const openSettings = useAppOverlayStore((s) => s.openSettings);
  const openTimetable = useAppOverlayStore((s) => s.openTimetable);
  const { showWhatsNew } = useLocalSearchParams<{ showWhatsNew?: string }>();
  const {
    loadState,
    mosques,
    displayedPrayerTimes,
    iqamahTimes,
    nextCountdown,
    refresh,
    selectedMosque,
    displayedDate,
    goToPreviousDay,
    goToNextDay,
    goToToday,
    goToLastAvailablePrayerDate,
    hasAvailablePrayerTimesFallback,
  } = useHomePrayerData();
  const uses24HourTime = useSettingsStore((s) => s.uses24HourTime);
  const hideQiblaCompass = useSettingsStore((s) => s.hideQiblaCompass);
  const hasCompletedOnboarding = useSettingsStore((s) => s.hasCompletedOnboarding);
  const lastSeenBuildVersion = useSettingsStore((s) => s.lastSeenBuildVersion);
  const setLastSeenBuildVersion = useSettingsStore((s) => s.setLastSeenBuildVersion);
  const themeMode = useSettingsStore((s) => s.themeMode);
  const fixedTheme = useSettingsStore((s) => s.fixedTheme);
  const asrIqamahPreference = useSettingsStore((s) => s.asrIqamahPreference);
  const languageCode = useAppLanguage();
  const locale = resolvedLocale(languageCode);
  const fontScale = getFontScale(languageCode);


  const [selectedPrayer, setSelectedPrayer] = useState<PrayerName>("Fajr");
  const [showingWhatsNew, setShowingWhatsNew] = useState(false);
  const [notificationIssue, setNotificationIssue] = useState<NotificationPermissionIssue>(null);


  const onboarding = useOnboardingStore();
  const currentStep = onboarding.currentStep;
  const tutorialStarted = useRef(false);
  const prayers = isFridayInSheffield(displayedDate) ? FRIDAY_PRAYERS : BASE_PRAYERS;
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
      onboarding.handlePrayerShortcutTap(idx);
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

  // ── Notification Permission Recovery ──
  const [checkDone, setCheckDone] = useState(false);
  useEffect(() => {
    if (!hasCompletedOnboarding) return;
    if (loadState === "loading" || loadState === "idle") return;
    if (checkDone) return;
    // Don't show recovery prompt while the What's New modal is visible.
    if (showingWhatsNew) return;

    setCheckDone(true);
    checkNotificationPermissionIssue().then(setNotificationIssue);
  }, [hasCompletedOnboarding, loadState, showingWhatsNew, checkDone]);

  const handleNotificationRecovery = async () => {
    if (notificationIssue?.kind === "bug_recovery") {
      fixNotificationMasterEnabled();
    }

    const granted = await requestNotificationPermission();
    if (granted && selectedMosque) {
      const settings = useSettingsStore.getState();
      await rescheduleUpcomingPrayerNotifications({
        mosque: selectedMosque,
        settings: settings.notifications,
        locale: languageCode,
        asrIqamahPreference: settings.asrIqamahPreference,
      });
    }
    setNotificationIssue(null);
  };

  useEffect(() => {
    if (showWhatsNew === "1") {
      setShowingWhatsNew(true);
    }
  }, [showWhatsNew]);

  useEffect(() => {
    if (nextCountdown?.nextName) {
      setSelectedPrayer(resolveInitialPrayer(nextCountdown.nextName));
    } else if (displayedPrayerTimes && isSameSheffieldDay(displayedDate, new Date())) {
      setSelectedPrayer("Isha");
    }
  }, [displayedDate, displayedPrayerTimes, nextCountdown?.nextName]);

  const gregorian = gregorianDateString(displayedDate, locale);
  const hijri = hijriDateString(displayedDate, locale);
  const currentMonthLabel = useMemo(
    () => new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }).format(displayedDate),
    [locale, displayedDate]
  );

  const mosqueSlug = selectedMosque?.slug ?? "";

  const iqamah = getIqamahForSelectedPrayer(
    selectedPrayer,
    displayedPrayerTimes,
    iqamahTimes,
    mosqueSlug,
    asrIqamahPreference,
    displayedDate
  );

  const adhanTime = useMemo(() => {
    if (!displayedPrayerTimes) return "";
    switch (selectedPrayer) {
      case "Fajr":
        return displayedPrayerTimes.fajr;
      case "Sunrise":
        return displayedPrayerTimes.sunrise;
      case "Dhuhr":
        return isFridayInSheffield(displayedDate) ? getPrimaryJummahTime(displayedPrayerTimes, iqamahTimes) : displayedPrayerTimes.dhuhr;
      case "Jummah":
        return getPrimaryJummahTime(displayedPrayerTimes, iqamahTimes);
      case "Asr":
        return displayedPrayerTimes.asr;
      case "Maghrib":
        return displayedPrayerTimes.maghrib;
      case "Isha":
        return displayedPrayerTimes.isha;
    }
  }, [displayedDate, displayedPrayerTimes, iqamahTimes, selectedPrayer]);

  useEffect(() => {
    if (!prayers.includes(selectedPrayer)) {
      setSelectedPrayer("Dhuhr");
    }
  }, [prayers, selectedPrayer]);

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

  const heroParts = useMemo(() => {
    if (!adhanTime) return { clock: "--:--", meridiem: null as string | null };
    return formatPrayerTimeHeroParts(adhanTime, uses24HourTime, locale);
  }, [adhanTime, uses24HourTime, locale]);

  const selectedPrayerDisplayName = translatePrayerName(selectedPrayer, languageCode);

  const selectedPrayerSubtitle = selectedPrayer === "Jummah"
    ? (() => {
        const secondJummah = getSecondJummahTime(iqamahTimes);
        return secondJummah
          ? `${translatePrayerName("Jummah", languageCode)} 2: ${formatTime(secondJummah, uses24HourTime, locale)}`
          : null;
      })()
    : iqamah
      ? t("home.iqamah_format", languageCode).replace(
          "%s",
          formatTime(iqamah, uses24HourTime, locale)
        )
      : null;

  if (loadState === "loading" || loadState === "idle") {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: sky.baseColors[0] }]}>
        <ActivityIndicator testID="home-loading" size="large" color="#47A6FF" />
      </View>
    );
  }

  if (loadState === "empty") {
    if (selectedMosque) {
      return (
        <View style={[styles.loadingContainer, { backgroundColor: sky.baseColors[0], paddingHorizontal: 32 }]}> 
          <Text style={[styles.missingTimesTitle, { color: textColor }]}>{t("home.missing_times.title", languageCode)}</Text>
          <Text style={[styles.missingTimesMonth, { color: textColor + "B8" }]}>{currentMonthLabel}</Text>
          {hasAvailablePrayerTimesFallback ? (
            <Pressable
              style={[styles.retryButton, { marginTop: SPACING.md }]}
              onPress={goToLastAvailablePrayerDate}
              accessibilityRole="button"
            >
              <Text style={styles.retryButtonText}>{t("home.go_to_available_times", languageCode)}</Text>
            </Pressable>
          ) : null}
          <Pressable
            style={[styles.retryButton, { marginTop: SPACING.md }]}
            onPress={() => openMissingPrayerTimesEmail({
              mosqueName: selectedMosque.name,
              monthLabel: currentMonthLabel,
              languageCode,
            })}
            accessibilityRole="button"
          >
            <Text style={styles.retryButtonText}>{t("home.missing_times.email_button", languageCode)}</Text>
          </Pressable>
          <Pressable style={styles.secondaryRetryButton} onPress={refresh} accessibilityRole="button">
            <Text style={[styles.secondaryRetryButtonText, { color: textColor + "CC" }]}>{t("action.retry", languageCode)}</Text>
          </Pressable>
        </View>
      );
    }

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
                  openTimetable({
                    theme: selectedPrayer,
                    mosqueName: selectedMosque?.name ?? "",
                    mosqueSlug,
                  });
                }}
                accessibilityRole="button"
                accessibilityLabel={t("accessibility.timetable", languageCode)}
              >
                <Calendar size={20} color={textColor} strokeWidth={1.5} />
              </Pressable>
            </TutorialHighlight>

            <View style={styles.dateNavigator}>
              <Pressable
                style={styles.dateArrowButton}
                onPress={goToPreviousDay}
                accessibilityRole="button"
                accessibilityLabel="Previous day"
              >
                <ChevronLeft size={18} color={textColor + "80"} strokeWidth={2} />
              </Pressable>

              <Pressable
                style={styles.dateContainer}
                onPress={goToToday}
                accessibilityRole="button"
                accessibilityLabel="Go to today"
              >
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
              </Pressable>

              <Pressable
                style={styles.dateArrowButton}
                onPress={goToNextDay}
                accessibilityRole="button"
                accessibilityLabel="Next day"
              >
                <ChevronRight size={18} color={textColor + "80"} strokeWidth={2} />
              </Pressable>
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
                  openSettings({ theme: selectedPrayer });
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
                <HeroOrbSection
                  nextCountdown={nextCountdown}
                  displayedPrayerTimes={displayedPrayerTimes}
                  iqamahTimes={iqamahTimes}
                  mosqueSlug={mosqueSlug}
                  asrIqamahPreference={asrIqamahPreference}
                  languageCode={languageCode}
                  theme={theme}
                  hideQiblaCompass={hideQiblaCompass}
                  animatedRotation={animatedRotation}
                  textColor={textColor}
                />
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

              {/* Iqamah / secondary Jummah subtitle */}
              {selectedPrayerSubtitle ? (
                <Text
                  style={[
                    styles.iqamahText,
                    { color: textColor + "C7", fontSize: 26 * fontScale },
                  ]}
                >
                  {selectedPrayerSubtitle}
                </Text>
              ) : null}
            </View>

            <View style={{ flex: 1 }} />

            {/* Bottom: Prayer Name + Letter Picker */}
            <View style={{ alignItems: "center", paddingBottom: 80, gap: 24 }}>
              <Text style={[styles.prayerName, { color: textColor, fontSize: 36 * fontScale }]}>
                {selectedPrayerDisplayName}
              </Text>

              <PrayerLetterPicker
                prayers={prayers}
                selectedPrayer={selectedPrayer}
                onSelectPrayer={handlePrayerSelect}
                theme={theme}
                highlightAllPrayers={currentStep?.type === "prayerShortcut"}
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
            openSettings({ theme: selectedPrayer });
          } else if (action === "timetable") {
            openTimetable({
              theme: selectedPrayer,
              mosqueName: selectedMosque?.name ?? "",
              mosqueSlug,
            });
          }
        }}
      />

      <NotificationRecoveryModal
        visible={notificationIssue !== null && !currentStep}
        theme={theme}
        language={languageCode}
        issue={notificationIssue}
        onEnable={handleNotificationRecovery}
        onDismiss={() => setNotificationIssue(null)}
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
  secondaryRetryButton: {
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm,
    marginTop: SPACING.xs,
  },
  secondaryRetryButtonText: {
    fontSize: FONT_SIZES.sm,
    fontFamily: "Comfortaa_600SemiBold",
  },
  missingTimesTitle: {
    fontSize: 24,
    lineHeight: 32,
    textAlign: "center",
    fontFamily: "Comfortaa_600SemiBold",
  },
  missingTimesMonth: {
    marginTop: SPACING.xs,
    fontSize: FONT_SIZES.md,
    lineHeight: 24,
    textAlign: "center",
    fontFamily: "Comfortaa_400Regular",
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
  dateNavigator: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: SPACING.xs,
  },
  dateArrowButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: "center",
    alignItems: "center",
  },
  dateContainer: {
    flexShrink: 1,
    alignItems: "center",
    paddingHorizontal: SPACING.xs,
    minWidth: 0,
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
