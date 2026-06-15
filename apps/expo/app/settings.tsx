import React, { useEffect, useState, useCallback, useMemo } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Linking,
  Platform,
  Alert,
  DeviceEventEmitter,
  LayoutAnimation,
  Switch,
  UIManager,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { useRouter, useLocalSearchParams } from "expo-router";
import * as Location from "expo-location";
import { SafeAreaView } from "react-native-safe-area-context";
import { ChevronRight, X } from "lucide-react-native";
import { AtmosphericSkyBackground } from "@/components/ui/AtmosphericSkyBackground";
import { TutorialHighlight } from "@/components/onboarding/CoachMarkCard";
import { TutorialOverlay } from "@/components/onboarding/TutorialOverlay";
import { useOnboardingStore } from "@/store/onboarding";
import { SettingsMenuPickerRow } from "@/components/ui/SettingsMenuPickerRow";
import { SPACING, FONT_SIZES } from "@/constants";
import { SettingsToggleRow } from "@/components/ui/SettingsToggleRow";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import { prayerTimesCache } from "@/lib/prayer/prayerTimesCache";
import { visibleMosques, cityOptions, mosquesInCity, mosquesInCountry, countryOptions, countryGroupingKey, cityGroupingKey } from "@/lib/prayer/mosqueDefaults";
import { useShallow } from "zustand/react/shallow";
import { useSettingsStore, type AppLanguage } from "@/store/settings";
import { t, type TranslationKey } from "@/lib/i18n/translations";
import { APP_LANGUAGES, useAppLanguage } from "@/lib/i18n/language";
import {
  cancelAllPrayerNotifications,
  rescheduleUpcomingPrayerNotifications,
  requestNotificationAuthorizationIfNeeded,
} from "@/lib/notifications/prayerNotifications";
import {
  scheduleNotificationAsync,
  SchedulableTriggerInputTypes,
} from "@/lib/notifications/expoNotificationApi";
import { resolveSelectedMosque } from "@/lib/prayer/mosqueDefaults";
import { getDateInSheffield } from "@/lib/prayer/prayerTimesEngine";
import { MONTH_NAMES, monthNameFromNumber, type MonthName } from "@/lib/prayer/monthName";
import type { MonthPrayerData, Mosque } from "@/types/prayer";
import {
  themeForPrayer,
  getSkyTheme,
  getTextColor,
  getUsesLightForeground,
  resolveTheme,
  SELECTABLE_PRAYER_THEMES,
  type ThemeMode,
  type TimeTheme,
} from "@/lib/design/themes";

type NotificationPrayerKey = "fajr" | "dhuhrJummah" | "asr" | "maghrib" | "isha";

const NOTIFICATION_PRAYER_KEYS: readonly NotificationPrayerKey[] = [
  "fajr",
  "dhuhrJummah",
  "asr",
  "maghrib",
  "isha",
];

if (Platform.OS === "android" && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

function notificationField(prefix: "adhan" | "iqamah", prayer: NotificationPrayerKey) {
  return `${prefix}${prayer.charAt(0).toUpperCase()}${prayer.slice(1)}`;
}

function notificationPrayerLabelKey(prayer: NotificationPrayerKey): TranslationKey {
  switch (prayer) {
    case "fajr": return "settings.notification.fajr";
    case "dhuhrJummah": return "settings.notification.dhuhr_jummah";
    case "asr": return "settings.notification.asr";
    case "maghrib": return "settings.notification.maghrib";
    case "isha": return "settings.notification.isha";
  }
}

async function rescheduleNotifications(
  settings: ReturnType<typeof useSettingsStore.getState>
): Promise<void> {
  try {
    if (!settings.notifications.masterEnabled) {
      await cancelAllPrayerNotifications();
      return;
    }
    const mosques = await prayerRepository.listMosques().then(async (all) => {
      await prayerTimesCache.saveMosques(all);
      return all;
    }).catch(async () => (await prayerTimesCache.loadMosques()) ?? []);
    const mosque = resolveSelectedMosque(
      mosques,
      settings.selectedMosqueId,
      settings.selectedMosqueSlug
    );
    if (!mosque) return;
    const locale = useSettingsStore.getState().appLanguage;
    await rescheduleUpcomingPrayerNotifications({
      mosque,
      settings: settings.notifications,
      locale,
      asrIqamahPreference: settings.asrIqamahPreference,
    });
  } catch {
    // Notification native modules may not be available (Android Expo Go); fail silently.
  }
}

async function loadMonthlyPrayerTimesWithCache(
  mosqueSlug: string,
  month: MonthName,
  year: number
) {
  const cached = await prayerTimesCache.loadMonthly(mosqueSlug, month, year);
  if (cached) return cached;
  const monthly = await prayerRepository.getMonthlyPrayerTimes(mosqueSlug, month, year);
  if (monthly) {
    await prayerTimesCache.saveMonthly(mosqueSlug, month, year, monthly);
  }
  return monthly;
}

function monthHasSecondAsrAdhan(monthly: MonthPrayerData | null): boolean {
  return monthly?.prayerTimes.some((row) => Boolean(row.asrMithl2)) ?? false;
}

export default function SettingsScreen() {
  const router = useRouter();
  const { theme: themeParam } = useLocalSearchParams<{ theme?: string }>();
  const settings = useSettingsStore(
    useShallow((s) => ({
      selectedMosqueId: s.selectedMosqueId,
      selectedMosqueSlug: s.selectedMosqueSlug,
      selectedCityGroupingKey: s.selectedCityGroupingKey,
      selectedCountryGroupingKey: s.selectedCountryGroupingKey,
      hideQiblaCompass: s.hideQiblaCompass,
      themeMode: s.themeMode,
      fixedTheme: s.fixedTheme,
      asrIqamahPreference: s.asrIqamahPreference,
      uses24HourTime: s.uses24HourTime,
      appLanguage: s.appLanguage,
      notifications: s.notifications,
      setSelectedMosque: s.setSelectedMosque,
      setSelectedCityGroupingKey: s.setSelectedCityGroupingKey,
      setSelectedCountryGroupingKey: s.setSelectedCountryGroupingKey,
      setUses24HourTime: s.setUses24HourTime,
      setHideQiblaCompass: s.setHideQiblaCompass,
      setNotificationMaster: s.setNotificationMaster,
      setPreAdhanReminderMinutes: s.setPreAdhanReminderMinutes,
      setPreIqamahReminderMinutes: s.setPreIqamahReminderMinutes,
      setAsrIqamahPreference: s.setAsrIqamahPreference,
      setThemeMode: s.setThemeMode,
      setFixedTheme: s.setFixedTheme,
      setAppLanguage: s.setAppLanguage,
    }))
  );
  const dynamicTheme = themeForPrayer(themeParam ?? "Fajr");
  const theme = resolveTheme(dynamicTheme, settings.themeMode, settings.fixedTheme);
  const sky = getSkyTheme(theme);
  const textColor = getTextColor(theme);
  const invertSheet = getUsesLightForeground(theme);

  // ── Onboarding ──
  const onboarding = useOnboardingStore();
  const currentStep = onboarding.currentStep;
  useEffect(() => {
    // Safety-advance if navigated here during openSettings without the tap handler
    if (currentStep?.type === "openSettings") {
      onboarding.handleSettingsOpened();
    }
  }, [currentStep?.type]);
  // ── End Onboarding ──

  const [mosques, setMosques] = useState<Mosque[]>([]);
  const [loading, setLoading] = useState(true);
  const [locationPermissionStatus, setLocationPermissionStatus] = useState<Location.PermissionStatus | null>(null);
  const [userCoordinates, setUserCoordinates] = useState<Location.LocationObjectCoords | null>(null);
  const [supportsMultipleAsr, setSupportsMultipleAsr] = useState(false);
  const [adhanPrayerSettingsExpanded, setAdhanPrayerSettingsExpanded] = useState(false);
  const [iqamahPrayerSettingsExpanded, setIqamahPrayerSettingsExpanded] = useState(false);
  const langCode = useAppLanguage();

  useEffect(() => {
    let cancelled = false;
    async function loadMosques() {
      const cached = await prayerTimesCache.loadMosques();
      if (!cancelled && cached) {
        setMosques(visibleMosques(cached));
        setLoading(false);
      }
      try {
        const all = await prayerRepository.listMosques();
        await prayerTimesCache.saveMosques(all);
        if (!cancelled) {
          setMosques(visibleMosques(all));
          setLoading(false);
        }
      } catch {
        if (!cancelled) setLoading(false);
      }
    }
    loadMosques();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function loadAsrSupport() {
      const selected = mosques.find((m) => m.id === settings.selectedMosqueId) ?? mosques.find((m) => m.slug === settings.selectedMosqueSlug);
      if (!selected) {
        setSupportsMultipleAsr(false);
        return;
      }
      const { year, month } = getDateInSheffield(new Date());
      const monthName = monthNameFromNumber(month);
      if (!monthName) {
        setSupportsMultipleAsr(false);
        return;
      }
      try {
        const currentMonth = await loadMonthlyPrayerTimesWithCache(selected.slug, monthName, year);
        if (monthHasSecondAsrAdhan(currentMonth)) {
          if (!cancelled) setSupportsMultipleAsr(true);
          return;
        }

        // The setting should be available for mosques that support a second Asr
        // adhan anywhere in the yearly timetable, not only in the current month.
        for (const candidateMonth of MONTH_NAMES) {
          if (candidateMonth === monthName) continue;
          const monthly = await loadMonthlyPrayerTimesWithCache(selected.slug, candidateMonth, year);
          if (cancelled) return;
          if (monthHasSecondAsrAdhan(monthly)) {
            setSupportsMultipleAsr(true);
            return;
          }
        }

        if (!cancelled) setSupportsMultipleAsr(false);
      } catch {
        if (!cancelled) setSupportsMultipleAsr(false);
      }
    }
    loadAsrSupport();
    return () => {
      cancelled = true;
    };
  }, [mosques, settings.selectedMosqueId, settings.selectedMosqueSlug]);

  useEffect(() => {
    let cancelled = false;

    async function loadUserCoordinates() {
      if (settings.hideQiblaCompass) {
        setUserCoordinates(null);
        return;
      }

      try {
        const permission = await Location.getForegroundPermissionsAsync();
        if (cancelled) return;
        setLocationPermissionStatus(permission.status);
        if (permission.status !== Location.PermissionStatus.GRANTED) {
          setUserCoordinates(null);
          return;
        }

        const position = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.Balanced,
        });
        if (!cancelled) {
          setUserCoordinates(position.coords);
        }
      } catch {
        // Location can fail in simulators or when services are unavailable; leave closest mosque unset.
      }
    }

    loadUserCoordinates();
    return () => {
      cancelled = true;
    };
  }, [settings.hideQiblaCompass]);

  const countries = useMemo(() => countryOptions(mosques), [mosques]);

  const effectiveCountryKey = useMemo(() => {
    const stored = settings.selectedCountryGroupingKey;
    if (stored && mosquesInCountry(stored, mosques).length > 0) {
      return stored;
    }
    const m = mosques.find((x) => x.id === settings.selectedMosqueId);
    if (m) return countryGroupingKey(m);
    return countries[0]?.key ?? "";
  }, [mosques, settings.selectedCountryGroupingKey, settings.selectedMosqueId, countries]);

  const cities = useMemo(() => cityOptions(mosques, effectiveCountryKey), [mosques, effectiveCountryKey]);

  const effectiveCityKey = useMemo(() => {
    const stored = settings.selectedCityGroupingKey;
    const mosquesInSelectedCountry = mosquesInCountry(effectiveCountryKey, mosques);
    if (stored && mosquesInCity(stored, mosquesInSelectedCountry).length > 0) {
      return stored;
    }
    const m = mosques.find((x) => x.id === settings.selectedMosqueId);
    if (m) return cityGroupingKey(m);
    return cities[0]?.key ?? "";
  }, [
    mosques,
    settings.selectedCityGroupingKey,
    settings.selectedMosqueId,
    cities,
    effectiveCountryKey,
  ]);

  const mosquesInSelectedCity = useMemo(() => {
    const countryMosques = mosquesInCountry(effectiveCountryKey, mosques);
    if (!effectiveCityKey) return countryMosques;
    return mosquesInCity(effectiveCityKey, countryMosques);
  }, [mosques, effectiveCountryKey, effectiveCityKey]);

  const handleMosqueSelect = (mosque: Mosque) => {
    settings.setSelectedMosque(mosque.id, mosque.slug, cityGroupingKey(mosque), countryGroupingKey(mosque));
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleCountrySelect = (key: string) => {
    settings.setSelectedCountryGroupingKey(key);
    // Reset city selection when country changes
    const inCountry = mosquesInCountry(key, mosques);
    const inCity = mosquesInCity(effectiveCityKey, inCountry);
    const currentOk = inCity.some((m) => m.id === settings.selectedMosqueId);
    if (!currentOk && inCountry[0]) {
      handleMosqueSelect(inCountry[0]);
    } else {
      rescheduleNotifications(useSettingsStore.getState());
    }
  };

  const handleCitySelect = (key: string) => {
    settings.setSelectedCityGroupingKey(key);
    const inCountry = mosquesInCountry(effectiveCountryKey, mosques);
    const inCity = mosquesInCity(key, inCountry);
    const currentOk = inCity.some((m) => m.id === settings.selectedMosqueId);
    if (!currentOk && inCity[0]) {
      handleMosqueSelect(inCity[0]);
    } else {
      rescheduleNotifications(useSettingsStore.getState());
    }
  };

  const handle24hToggle = (v: boolean) => {
    settings.setUses24HourTime(v);
  };

  const handleAsrIqamahPreference = (v: "first" | "second") => {
    settings.setAsrIqamahPreference(v);
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleQiblaToggle = (v: boolean) => {
    settings.setHideQiblaCompass(!v);
    if (v && locationPermissionStatus === Location.PermissionStatus.UNDETERMINED) {
      Location.requestForegroundPermissionsAsync()
        .then((permission) => setLocationPermissionStatus(permission.status))
        .catch(() => {});
    }
  };

  const handleMasterToggle = (v: boolean) => {
    settings.setNotificationMaster(v);
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleAdhanToggle = (v: boolean) => {
    const current = useSettingsStore.getState().notifications;
    useSettingsStore.setState({
      notifications: {
        ...current,
        masterEnabled:
          v ||
          current.iqamahEnabled ||
          current.preAdhanReminderMinutes !== null ||
          current.preIqamahReminderMinutes !== null,
        adhanEnabled: v,
        adhanFajr: v,
        adhanDhuhrJummah: v,
        adhanAsr: v,
        adhanMaghrib: v,
        adhanIsha: v,
      },
    });
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleIqamahToggle = (v: boolean) => {
    const current = useSettingsStore.getState().notifications;
    useSettingsStore.setState({
      notifications: {
        ...current,
        masterEnabled:
          current.adhanEnabled ||
          v ||
          current.preAdhanReminderMinutes !== null ||
          current.preIqamahReminderMinutes !== null,
        iqamahEnabled: v,
        iqamahFajr: v,
        iqamahDhuhrJummah: v,
        iqamahAsr: v,
        iqamahMaghrib: v,
        iqamahIsha: v,
      },
    });
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleAdhanReminder = (v: number | null) => {
    settings.setPreAdhanReminderMinutes(v);
    const state = useSettingsStore.getState();
    if (v !== null && !state.notifications.masterEnabled) {
      settings.setNotificationMaster(true);
    }
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleIqamahReminder = (v: number | null) => {
    settings.setPreIqamahReminderMinutes(v);
    const state = useSettingsStore.getState();
    if (v !== null && !state.notifications.masterEnabled) {
      settings.setNotificationMaster(true);
    }
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleAdhanPrayerToggle = useCallback((prayer: NotificationPrayerKey, enabled: boolean) => {
    const current = useSettingsStore.getState().notifications;
    const next = {
      ...current,
      [notificationField("adhan", prayer)]: enabled,
    };
    const anyAdhanEnabled = NOTIFICATION_PRAYER_KEYS.some((key) =>
      Boolean((next as unknown as Record<string, boolean>)[notificationField("adhan", key)])
    );
    useSettingsStore.setState({
      notifications: {
        ...next,
        adhanEnabled: anyAdhanEnabled,
        masterEnabled:
          anyAdhanEnabled ||
          next.iqamahEnabled ||
          next.preAdhanReminderMinutes !== null ||
          next.preIqamahReminderMinutes !== null,
      },
    });
    rescheduleNotifications(useSettingsStore.getState());
  }, []);

  const handleIqamahPrayerToggle = useCallback((prayer: NotificationPrayerKey, enabled: boolean) => {
    const current = useSettingsStore.getState().notifications;
    const next = {
      ...current,
      [notificationField("iqamah", prayer)]: enabled,
    };
    const anyIqamahEnabled = NOTIFICATION_PRAYER_KEYS.some((key) =>
      Boolean((next as unknown as Record<string, boolean>)[notificationField("iqamah", key)])
    );
    useSettingsStore.setState({
      notifications: {
        ...next,
        iqamahEnabled: anyIqamahEnabled,
        masterEnabled:
          next.adhanEnabled ||
          anyIqamahEnabled ||
          next.preAdhanReminderMinutes !== null ||
          next.preIqamahReminderMinutes !== null,
      },
    });
    rescheduleNotifications(useSettingsStore.getState());
  }, []);

  const allAdhanPrayerTogglesEnabled = NOTIFICATION_PRAYER_KEYS.every((prayer) =>
    Boolean((settings.notifications as unknown as Record<string, boolean>)[notificationField("adhan", prayer)])
  );
  const allIqamahPrayerTogglesEnabled = NOTIFICATION_PRAYER_KEYS.every((prayer) =>
    Boolean((settings.notifications as unknown as Record<string, boolean>)[notificationField("iqamah", prayer)])
  );
  const adhanNotificationsEnabled = settings.notifications.adhanEnabled && allAdhanPrayerTogglesEnabled;
  const iqamahNotificationsEnabled = settings.notifications.iqamahEnabled && allIqamahPrayerTogglesEnabled;

  const REMINDER_OPTIONS: { labelKey: TranslationKey; value: number | null }[] = [
    { labelKey: "settings.reminder.none", value: null },
    { labelKey: "settings.reminder.5min", value: 5 },
    { labelKey: "settings.reminder.10min", value: 10 },
    { labelKey: "settings.reminder.15min", value: 15 },
    { labelKey: "settings.reminder.30min", value: 30 },
  ];

  // ── Contact mailto ──
  const openSupportMail = useCallback(
    (category: "feedback" | "prayerTimes" | "requestMasjid") => {
      const mosqueName =
        mosques.find((m) => m.id === settings.selectedMosqueId)?.name ?? null;
      const subject =
        category === "feedback"
          ? t("settings.email.feedback.subject", langCode)
          : category === "prayerTimes"
            ? t("settings.email.prayer_times.subject", langCode)
            : t("settings.email.request_masjid.subject", langCode);
      const bodyLines: string[] = [];
      if (category === "requestMasjid") {
        bodyLines.push("Hi Masjidly team,");
        bodyLines.push("");
        bodyLines.push("I'd like to request adding a masjid to Masjidly.");
        bodyLines.push("");
        bodyLines.push("Masjid name:");
        bodyLines.push("City / country:");
        bodyLines.push("Website or contact details:");
        bodyLines.push("Prayer timetable source:");
      }
      bodyLines.push("");
      bodyLines.push("---");
      bodyLines.push(`App: Masjidly`);
      bodyLines.push(`Mosque: ${mosqueName ?? t("settings.email.mosque.not_selected", langCode)}`);
      bodyLines.push(`Language: ${langCode}`);
      const body = bodyLines.join("\n");
      const mailto = `mailto:mikhailbuilds@gmail.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
      Linking.openURL(mailto).catch(() => {
        // Fail silently if no mail client
      });
    },
    [mosques, settings.selectedMosqueId, langCode]
  );

  // ── Location recovery ──
  useEffect(() => {
    let mounted = true;
    Location.getForegroundPermissionsAsync()
      .then((permission) => {
        if (mounted) setLocationPermissionStatus(permission.status);
      })
      .catch(() => {});
    return () => {
      mounted = false;
    };
  }, []);

  const qiblaIsHidden = settings.hideQiblaCompass;
  const shouldShowLocationRecovery =
    qiblaIsHidden || locationPermissionStatus === Location.PermissionStatus.DENIED;

  const handleLocationRecovery = useCallback(() => {
    if (locationPermissionStatus === Location.PermissionStatus.UNDETERMINED) {
      Location.requestForegroundPermissionsAsync()
        .then((permission) => setLocationPermissionStatus(permission.status))
        .catch(() => {});
      return;
    }

    if (Platform.OS === "ios") {
      Linking.openURL("app-settings:");
    } else {
      Linking.openSettings();
    }
  }, [locationPermissionStatus]);

  // ── Test notifications (dev) ──
  const fireTestNotification = useCallback(
    async (type: "adhan" | "iqamah" | "reminder" | "all") => {
      try {
        const granted = await requestNotificationAuthorizationIfNeeded();
        if (!granted) {
          Alert.alert(
            t("settings.alert.notifications_not_enabled.title", langCode),
            t("settings.alert.notifications_not_enabled.message", langCode)
          );
          return;
        }

        const slug = settings.selectedMosqueSlug ?? "";

        const scheduleOne = async (
          title: string,
          body: string,
          category: string,
          data: Record<string, string>
        ) => {
          const identifier = `masjidly.debug.${Date.now()}.${Math.random().toString(36).slice(2)}`;
          await scheduleNotificationAsync({
            identifier,
            content: {
              title,
              body,
              sound: true,
              data,
              ...(Platform.OS === "ios" ? { categoryIdentifier: category } : {}),
            },
            trigger: {
              type: SchedulableTriggerInputTypes.TIME_INTERVAL,
              seconds: 1,
            },
          });
        };

      if (type === "adhan" || type === "all") {
        await scheduleOne(
          t("notification.maghrib_adhan", langCode),
          t("notification.test.tap_adhan", langCode),
          "adhan",
          { kind: "adhan", prayer: "maghrib", mosqueSlug: slug }
        );
      }
      if (type === "iqamah" || type === "all") {
        await scheduleOne(
          t("notification.maghrib_iqamah", langCode),
          t("notification.test.iqamah_now", langCode),
          "iqamah",
          { kind: "iqamah", prayer: "maghrib", mosqueSlug: slug }
        );
      }
      if (type === "reminder" || type === "all") {
        await scheduleOne(
          t("notification.test.maghrib_soon", langCode),
          t("notification.test.adhan_in_10", langCode),
          "reminder",
          { kind: "reminder", prayer: "maghrib", mosqueSlug: slug }
        );
      }
      } catch (e) {
        Alert.alert(
          t("settings.alert.test_failed.title", langCode),
          e instanceof Error ? e.message : t("settings.alert.unknown_error", langCode)
        );
      }
    },
    [settings.selectedMosqueSlug, langCode]
  );

  const SectionCaption: React.FC<{ children: React.ReactNode }> = ({ children }) => (
    <Text style={[styles.sectionCaption, { color: textColor + "85" }]}>
      {children}
    </Text>
  );

  const RowDivider = () => (
    <View style={[styles.divider, { backgroundColor: textColor + "2E" }]} />
  );

  const formatMosqueLabel = (mosque: Mosque) => mosque.name;

  const selectedCountryLabel =
    countries.find((c) => c.key === effectiveCountryKey)?.label ??
    t("settings.reminder.none", langCode);

  const selectedCityLabel =
    cities.find((c) => c.key === effectiveCityKey)?.label ??
    t("settings.reminder.none", langCode);

  const selectedMosqueName =
    (() => {
      const mosque = mosques.find((m) => m.id === settings.selectedMosqueId);
      return mosque ? formatMosqueLabel(mosque) : t("settings.reminder.none", langCode);
    })();

  const closestMosque = useMemo(() => {
    if (settings.hideQiblaCompass || !userCoordinates || mosques.length === 0) return null;
    return mosques.reduce((closest, mosque) => {
      const closestDistance = distanceInMeters(userCoordinates.latitude, userCoordinates.longitude, closest.lat, closest.lng);
      const mosqueDistance = distanceInMeters(userCoordinates.latitude, userCoordinates.longitude, mosque.lat, mosque.lng);
      return mosqueDistance < closestDistance ? mosque : closest;
    }, mosques[0]);
  }, [mosques, settings.hideQiblaCompass, userCoordinates]);

  const closestMosqueName = closestMosque?.name ?? null;

  const reminderDisplayLabel = (minutes: number | null) => {
    const opt = REMINDER_OPTIONS.find((o) => o.value === minutes);
    return opt ? t(opt.labelKey, langCode) : t("settings.reminder.none", langCode);
  };

  const themeModeLabel = (mode: ThemeMode) =>
    mode === "dynamic"
      ? t("settings.theme.mode.dynamic", langCode)
      : t("settings.theme.mode.fixed", langCode);

  const themeLabel = (timeTheme: TimeTheme) => {
    const keyMap: Record<TimeTheme, TranslationKey> = {
      fajr: "prayer.fajr",
      sunrise: "prayer.sunrise",
      dhuhr: "prayer.dhuhr",
      asr: "prayer.asr",
      maghrib: "prayer.maghrib",
      isha: "prayer.isha",
      tahajjud: "prayer.isha",
    };
    return t(keyMap[timeTheme], langCode);
  };

  return (
    <View style={styles.root}>
      <AtmosphericSkyBackground sky={sky} variant="home" />

      <SafeAreaView style={styles.safeArea}>
        <ScrollView contentContainerStyle={styles.content}>
          {/* Title Header */}
          <View style={styles.titleHeader}>
            <Text style={[styles.titleText, { color: textColor }]}>
              {t("settings.navigation.title", langCode)}
            </Text>
            <TutorialHighlight
              isHighlighted={currentStep?.type === "closeSettings"}
              size={36}
              color={textColor}
            >
              <Pressable
                onPress={() => {
                  if (currentStep?.type === "closeSettings") {
                    onboarding.handleSettingsClosed();
                  }
                  router.back();
                }}
                style={[styles.closeButton, { backgroundColor: "rgba(255,255,255,0.18)" }]}
                accessibilityRole="button"
              >
                <X size={16} color={textColor} strokeWidth={2.5} />
              </Pressable>
            </TutorialHighlight>
          </View>

          {/* Mosque Section */}
          <SectionCaption>{t("settings.section.mosque.title", langCode)}</SectionCaption>
          {loading ? (
            <ActivityIndicator color={textColor} style={{ marginVertical: SPACING.md }} />
          ) : (
            <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
              <SettingsMenuPickerRow
                label={t("settings.country.picker", langCode)}
                displayValue={selectedCountryLabel}
                value={effectiveCountryKey}
                options={countries.map((c) => ({ label: c.label, value: c.key }))}
                onSelect={(key) => {
                  handleCountrySelect(key);
                }}
                textColor={textColor}
                invertSheet={invertSheet}
                sheetTitle={t("settings.country.picker", langCode)}
                testID="settings-country-picker"
              />
              <RowDivider />
              <SettingsMenuPickerRow
                label={t("settings.city.picker", langCode)}
                displayValue={selectedCityLabel}
                value={effectiveCityKey}
                options={cities.map((c) => ({ label: c.label, value: c.key }))}
                onSelect={(key) => {
                  handleCitySelect(key);
                }}
                textColor={textColor}
                invertSheet={invertSheet}
                sheetTitle={t("settings.city.picker", langCode)}
                testID="settings-city-picker"
              />
              <RowDivider />
              <SettingsMenuPickerRow
                label={t("settings.mosque.picker", langCode)}
                displayValue={selectedMosqueName}
                value={settings.selectedMosqueId ?? ""}
                options={mosquesInSelectedCity.map((m) => ({
                  label: formatMosqueLabel(m),
                  value: m.id,
                }))}
                onSelect={(id) => {
                  const m = mosquesInSelectedCity.find((x) => x.id === id);
                  if (m) handleMosqueSelect(m);
                }}
                textColor={textColor}
                invertSheet={invertSheet}
                sheetTitle={t("settings.section.mosque.title", langCode)}
                testID="settings-mosque-picker"
              />
              {closestMosque ? (
                <>
                  <RowDivider />
                  <View style={styles.closestMosqueContainer}>
                    <Text style={[styles.closestMosqueText, { color: textColor + "CC" }]}> 
                      {t("settings.closest_mosque.format", langCode).replace("%s", closestMosqueName ?? closestMosque.name)}
                    </Text>
                    <Pressable
                      onPress={() => handleMosqueSelect(closestMosque)}
                      style={({ pressed }) => [
                        styles.closestMosqueButton,
                        { backgroundColor: textColor + "26", borderColor: textColor + "33" },
                        pressed && { opacity: 0.75 },
                      ]}
                      accessibilityRole="button"
                      accessibilityLabel={t("settings.closest_mosque.select", langCode)}
                      testID="settings-select-closest-mosque"
                    >
                      <Text style={[styles.closestMosqueButtonText, { color: textColor }]}> 
                        {t("settings.closest_mosque.select", langCode)}
                      </Text>
                    </Pressable>
                  </View>
                </>
              ) : null}
            </View>
          )}

          {/* Display Section */}
          <SectionCaption>{t("settings.section.display.title", langCode)}</SectionCaption>
          <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
            <SettingsToggleRow
              title={t("settings.time.24h.title", langCode)}
              value={settings.uses24HourTime}
              onValueChange={handle24hToggle}
              textColor={textColor}
            />
            {supportsMultipleAsr ? (
              <>
                <View style={[styles.divider, { backgroundColor: textColor + "1A" }]} />
                <SettingsMenuPickerRow
                  label="Asr adhan time"
                  displayValue={settings.asrIqamahPreference === "second" ? "Second Asr (Mithl 2)" : "First Asr (Mithl 1)"}
                  value={settings.asrIqamahPreference}
                  options={[
                    { label: "First Asr (Mithl 1)", value: "first" as const },
                    { label: "Second Asr (Mithl 2)", value: "second" as const },
                  ]}
                  onSelect={handleAsrIqamahPreference}
                  textColor={textColor}
                  invertSheet={invertSheet}
                  sheetTitle="Asr adhan time"
                  testID="settings-asr-adhan-picker"
                />
              </>
            ) : null}
          </View>

          {/* Language Section */}
          <SectionCaption>{t("settings.section.language.title", langCode)}</SectionCaption>
          <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
            <SettingsMenuPickerRow
              label={t("settings.language.app", langCode)}
              displayValue={t(`settings.language.${settings.appLanguage}` as TranslationKey, langCode)}
              value={settings.appLanguage}
              options={APP_LANGUAGES.map((language) => ({
                label: t(`settings.language.${language.code}` as TranslationKey, langCode),
                value: language.code,
              }))}
              onSelect={(language) => settings.setAppLanguage(language as AppLanguage)}
              textColor={textColor}
              invertSheet={invertSheet}
              sheetTitle={t("settings.section.language.title", langCode)}
              testID="settings-language-picker"
            />
          </View>

          {/* Theme Section */}
          <SectionCaption>{t("settings.section.theme.title", langCode)}</SectionCaption>
          <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
            <SettingsMenuPickerRow
              label={t("settings.theme.mode", langCode)}
              displayValue={themeModeLabel(settings.themeMode)}
              value={settings.themeMode}
              options={(["dynamic", "fixed"] as ThemeMode[]).map((mode) => ({
                label: themeModeLabel(mode),
                value: mode,
              }))}
              onSelect={settings.setThemeMode}
              textColor={textColor}
              invertSheet={invertSheet}
              sheetTitle={t("settings.section.theme.title", langCode)}
              testID="settings-theme-mode-picker"
            />
            {settings.themeMode === "fixed" ? (
              <>
                <RowDivider />
                <SettingsMenuPickerRow
                  label={t("settings.theme.fixed_theme", langCode)}
                  displayValue={themeLabel(settings.fixedTheme)}
                  value={settings.fixedTheme}
                  options={SELECTABLE_PRAYER_THEMES.map((timeTheme) => ({
                    label: themeLabel(timeTheme),
                    value: timeTheme,
                  }))}
                  onSelect={settings.setFixedTheme}
                  textColor={textColor}
                  invertSheet={invertSheet}
                  sheetTitle={t("settings.theme.fixed_theme", langCode)}
                  testID="settings-fixed-theme-picker"
                />
              </>
            ) : null}
          </View>

          {/* Qibla Section */}
          <SectionCaption>{t("settings.section.qibla.title", langCode)}</SectionCaption>
          <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
            <SettingsToggleRow
              title={t("settings.qibla.enabled.title", langCode)}
              value={!settings.hideQiblaCompass}
              onValueChange={handleQiblaToggle}
              textColor={textColor}
            />
          </View>

          {/* Location Recovery Section */}
          {shouldShowLocationRecovery ? (
            <>
              <SectionCaption>{t("settings.section.location.title", langCode)}</SectionCaption>
              <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
                <View style={styles.locationRecoveryContainer}>
                  <Text style={[styles.locationRecoveryMessage, { color: textColor + "CC" }]}>
                    {t("settings.location.recovery.message", langCode)}
                  </Text>
                  <Pressable
                    onPress={handleLocationRecovery}
                    style={({ pressed }) => [
                      styles.locationRecoveryButton,
                      { backgroundColor: textColor + "40" },
                      pressed && { opacity: 0.8 },
                    ]}
                    accessibilityRole="button"
                    accessibilityLabel={
                      locationPermissionStatus === Location.PermissionStatus.UNDETERMINED
                        ? t("settings.location.allow", langCode)
                        : t("settings.location.open_settings", langCode)
                    }
                  >
                    <Text style={[styles.locationRecoveryButtonText, { color: "#FFFFFF" }]}>
                      {locationPermissionStatus === Location.PermissionStatus.UNDETERMINED
                        ? t("settings.location.allow", langCode)
                        : t("settings.location.open_settings", langCode)}
                    </Text>
                  </Pressable>
                </View>
              </View>
            </>
          ) : null}

          {/* Notifications Section */}
          <SectionCaption>{t("settings.notifications.title", langCode)}</SectionCaption>
          <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
            <SettingsToggleRow
              title={t("settings.notifications.master.title", langCode)}
              value={settings.notifications.masterEnabled}
              onValueChange={handleMasterToggle}
              textColor={textColor}
            />

            {settings.notifications.masterEnabled ? (
              <>
                <RowDivider />
                <NotificationPrayerToggleSection
                  title={t("notification.channel.adhan", langCode)}
                  expanded={adhanPrayerSettingsExpanded}
                  enabled={adhanNotificationsEnabled}
                  textColor={textColor}
                  onToggleExpanded={() => {
                    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
                    setAdhanPrayerSettingsExpanded((expanded) => !expanded);
                  }}
                  onValueChange={handleAdhanToggle}
                >
                  {NOTIFICATION_PRAYER_KEYS.map((prayer, idx) => (
                    <React.Fragment key={prayer}>
                      {idx > 0 && <RowDivider />}
                      <SettingsToggleRow
                        title={t(notificationPrayerLabelKey(prayer), langCode)}
                        value={Boolean(
                          (settings.notifications as unknown as Record<string, boolean>)[notificationField("adhan", prayer)]
                        )}
                        onValueChange={(v) => handleAdhanPrayerToggle(prayer, v)}
                        textColor={textColor}
                      />
                    </React.Fragment>
                  ))}
                </NotificationPrayerToggleSection>
                <RowDivider />
                <NotificationPrayerToggleSection
                  title={t("notification.channel.iqamah", langCode)}
                  expanded={iqamahPrayerSettingsExpanded}
                  enabled={iqamahNotificationsEnabled}
                  textColor={textColor}
                  onToggleExpanded={() => {
                    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
                    setIqamahPrayerSettingsExpanded((expanded) => !expanded);
                  }}
                  onValueChange={handleIqamahToggle}
                >
                  {NOTIFICATION_PRAYER_KEYS.map((prayer, idx) => (
                    <React.Fragment key={prayer}>
                      {idx > 0 && <RowDivider />}
                      <SettingsToggleRow
                        title={t(notificationPrayerLabelKey(prayer), langCode)}
                        value={Boolean(
                          (settings.notifications as unknown as Record<string, boolean>)[notificationField("iqamah", prayer)]
                        )}
                        onValueChange={(v) => handleIqamahPrayerToggle(prayer, v)}
                        textColor={textColor}
                      />
                    </React.Fragment>
                  ))}
                </NotificationPrayerToggleSection>
                <RowDivider />
                <SettingsMenuPickerRow
                  label={t("settings.reminder.before_adhan", langCode)}
                  displayValue={reminderDisplayLabel(settings.notifications.preAdhanReminderMinutes)}
                  value={settings.notifications.preAdhanReminderMinutes}
                  options={REMINDER_OPTIONS.map((opt) => ({
                    label: t(opt.labelKey, langCode),
                    value: opt.value,
                  }))}
                  onSelect={handleAdhanReminder}
                  textColor={textColor}
                  invertSheet={invertSheet}
                  sheetTitle={t("settings.reminder.before_adhan", langCode)}
                  testID="settings-reminder-adhan-picker"
                />
                <RowDivider />
                <SettingsMenuPickerRow
                  label={t("settings.reminder.before_iqamah", langCode)}
                  displayValue={reminderDisplayLabel(settings.notifications.preIqamahReminderMinutes)}
                  value={settings.notifications.preIqamahReminderMinutes}
                  options={REMINDER_OPTIONS.map((opt) => ({
                    label: t(opt.labelKey, langCode),
                    value: opt.value,
                  }))}
                  onSelect={handleIqamahReminder}
                  textColor={textColor}
                  invertSheet={invertSheet}
                  sheetTitle={t("settings.reminder.before_iqamah", langCode)}
                  testID="settings-reminder-iqamah-picker"
                />
              </>
            ) : null}
          </View>

          {/* Contact Section */}
          <SectionCaption>{t("settings.section.contact.title", langCode)}</SectionCaption>
          <View style={styles.contactSection}>
            <Pressable
              style={({ pressed }) => [
                styles.contactCard,
                { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                pressed && { opacity: 0.7 },
              ]}
              onPress={() => openSupportMail("feedback")}
              accessibilityRole="button"
            >
              <Text style={[styles.contactCardText, { color: textColor }]}>
                {t("settings.contact.feedback.title", langCode)}
              </Text>
            </Pressable>
            <Pressable
              style={({ pressed }) => [
                styles.contactCard,
                { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                pressed && { opacity: 0.7 },
              ]}
              onPress={() => openSupportMail("prayerTimes")}
              accessibilityRole="button"
            >
              <Text style={[styles.contactCardText, { color: textColor }]}>
                {t("settings.contact.prayer_times.title", langCode)}
              </Text>
            </Pressable>
            <Pressable
              style={({ pressed }) => [
                styles.contactCard,
                { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                pressed && { opacity: 0.7 },
              ]}
              onPress={() => openSupportMail("requestMasjid")}
              accessibilityRole="button"
            >
              <Text style={[styles.contactCardText, { color: textColor }]}>
                {t("settings.contact.request_masjid.title", langCode)}
              </Text>
            </Pressable>
          </View>

          {/* Development Section */}
          {__DEV__ ? (
            <>
              <SectionCaption>{t("settings.dev.title", langCode)}</SectionCaption>
              <View style={styles.contactSection}>
                {/* Test What\'s New */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactCard,
                    { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() =>
                    router.replace({ pathname: "/", params: { showWhatsNew: "1" } })
                  }
                  accessibilityRole="button"
                >
                  <Text style={[styles.contactCardText, { color: textColor }]}>
                    {"Test What's New"}
                  </Text>
                </Pressable>

                {/* Test Update Prompt */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactCard,
                    { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => {
                    DeviceEventEmitter.emit("masjidly:testUpdatePrompt");
                  }}
                  accessibilityRole="button"
                >
                  <Text style={[styles.contactCardText, { color: textColor }]}>
                    {"Test Update Prompt"}
                  </Text>
                </Pressable>

                {/* Reset tutorial */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactCard,
                    { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => {
                    useSettingsStore.getState().setHasCompletedOnboarding(false);
                    Alert.alert(
                      t("settings.dev.reset_tutorial.title", langCode),
                      t("settings.dev.reset_tutorial.message", langCode),
                      [{ text: t("action.ok", langCode) }]
                    );
                  }}
                  accessibilityRole="button"
                  accessibilityLabel={t("settings.dev.reset_tutorial", langCode)}
                >
                  <Text style={[styles.contactCardText, { color: textColor }]}>
                    {t("settings.dev.reset_tutorial", langCode)}
                  </Text>
                </Pressable>

                {/* Test notification: Adhan */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactCard,
                    { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("adhan")}
                  accessibilityRole="button"
                >
                  <View style={{ flexDirection: "row", alignItems: "center", flex: 1 }}>
                    <Text style={[styles.contactCardText, { color: textColor }]}>
                      {t("settings.dev.test_adhan", langCode)}
                    </Text>
                    <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                      {t("settings.dev.instant", langCode)}
                    </Text>
                  </View>
                </Pressable>

                {/* Test notification: Iqamah */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactCard,
                    { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("iqamah")}
                  accessibilityRole="button"
                >
                  <View style={{ flexDirection: "row", alignItems: "center", flex: 1 }}>
                    <Text style={[styles.contactCardText, { color: textColor }]}>
                      {t("settings.dev.test_iqamah", langCode)}
                    </Text>
                    <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                      {t("settings.dev.instant", langCode)}
                    </Text>
                  </View>
                </Pressable>

                {/* Test notification: Reminder */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactCard,
                    { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("reminder")}
                  accessibilityRole="button"
                >
                  <View style={{ flexDirection: "row", alignItems: "center", flex: 1 }}>
                    <Text style={[styles.contactCardText, { color: textColor }]}>
                      {t("settings.dev.test_reminder", langCode)}
                    </Text>
                    <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                      {t("settings.dev.instant", langCode)}
                    </Text>
                  </View>
                </Pressable>

                {/* Test notification: All Three */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactCard,
                    { backgroundColor: textColor + "14", borderColor: textColor + "22" },
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("all")}
                  accessibilityRole="button"
                >
                  <View style={{ flexDirection: "row", alignItems: "center", flex: 1 }}>
                    <Text style={[styles.contactCardText, { color: textColor }]}>
                      {t("settings.dev.test_all", langCode)}
                    </Text>
                    <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                      {t("settings.dev.three_instant", langCode)}
                    </Text>
                  </View>
                </Pressable>
              </View>
            </>
          ) : null}
        </ScrollView>
      </SafeAreaView>

      {/* Tutorial Overlay */}
      {currentStep?.type === "exploreSettings" || currentStep?.type === "closeSettings" ? (
        <TutorialOverlay
          screen="settings"
          mosques={[]}
          theme={theme}
          textColor={textColor}
          usesLightForeground={invertSheet}
          locale={langCode}
        />
      ) : null}
    </View>
  );
}

type NotificationPrayerToggleSectionProps = {
  title: string;
  expanded: boolean;
  enabled: boolean;
  textColor: string;
  onToggleExpanded: () => void;
  onValueChange: (value: boolean) => void;
  children: React.ReactNode;
};

const NotificationPrayerToggleSection: React.FC<NotificationPrayerToggleSectionProps> = React.memo(({
  title,
  expanded,
  enabled,
  textColor,
  onToggleExpanded,
  onValueChange,
  children,
}) => {
  return (
    <View>
      <View style={styles.notificationDisclosureHeader}>
        <Pressable
          style={styles.notificationDisclosureButton}
          onPress={onToggleExpanded}
          accessibilityRole="button"
          accessibilityLabel={title}
          accessibilityState={{ expanded }}
        >
          <View style={{ transform: [{ rotate: expanded ? "90deg" : "0deg" }] }}>
            <ChevronRight
              size={18}
              color={textColor}
              strokeWidth={2.5}
            />
          </View>
          <Text style={[styles.notificationDisclosureTitle, { color: textColor }]}>
            {title}
          </Text>
        </Pressable>
        <Switch
          value={enabled}
          onValueChange={onValueChange}
          trackColor={{ false: `${textColor}40`, true: "#47A6FF" }}
          thumbColor={enabled ? "#FFFFFF" : "#F4F3F4"}
          ios_backgroundColor={`${textColor}30`}
        />
      </View>
      {expanded ? <View style={styles.notificationDisclosureContent}>{children}</View> : null}
    </View>
  );
});

function distanceInMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const earthRadiusMeters = 6_371_000;
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const deltaLat = toRadians(lat2 - lat1);
  const deltaLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(deltaLng / 2) ** 2;
  return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  safeArea: { flex: 1 },
  content: {
    paddingHorizontal: 22,
    paddingBottom: 32,
  },
  titleHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingBottom: 4,
    marginTop: SPACING.md,
    marginBottom: SPACING.lg,
  },
  titleText: {
    fontSize: 34,
    fontFamily: "Comfortaa_700Bold",
    lineHeight: 42,
  },
  closeButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: "center",
    alignItems: "center",
  },
  sectionCaption: {
    fontSize: 13,
    fontFamily: "Comfortaa_600SemiBold",
    textTransform: "uppercase",
    letterSpacing: 0.4,
    marginTop: SPACING.lg,
    marginBottom: SPACING.sm,
  },
  listBlock: {
    borderRadius: 14,
    overflow: "hidden",
  },
  listItemText: {
    fontSize: FONT_SIZES.md,
    fontFamily: "Comfortaa_400Regular",
    flex: 1,
  },

  closestMosqueContainer: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    gap: 10,
  },
  closestMosqueText: {
    fontSize: 14,
    fontFamily: "Comfortaa_400Regular",
    lineHeight: 20,
    textAlign: "center",
  },
  closestMosqueButton: {
    minHeight: 42,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: SPACING.md,
    paddingVertical: 10,
  },
  closestMosqueButtonText: {
    fontSize: 14,
    fontFamily: "Comfortaa_600SemiBold",
  },
  divider: {
    height: 0.5,
    marginHorizontal: SPACING.md,
  },
  notificationDisclosureHeader: {
    minHeight: 44,
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
  },
  notificationDisclosureButton: {
    flex: 1,
    minHeight: 44,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingRight: SPACING.sm,
  },
  notificationDisclosureTitle: {
    flex: 1,
    flexShrink: 1,
    fontSize: FONT_SIZES.md,
    fontFamily: "Comfortaa_400Regular",
  },
  notificationDisclosureContent: {
    paddingLeft: 26,
  },
  locationRecoveryContainer: {
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    gap: 12,
  },
  locationRecoveryMessage: {
    fontSize: 15,
    fontFamily: "Comfortaa_400Regular",
    lineHeight: 20,
  },
  locationRecoveryButton: {
    borderRadius: 14,
    paddingVertical: 14,
    alignItems: "center",
  },
  locationRecoveryButtonText: {
    fontSize: 16,
    fontFamily: "Comfortaa_600SemiBold",
  },
  contactSection: {
    gap: 10,
  },
  contactCard: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 14,
    paddingHorizontal: 16,
    minHeight: 44,
    borderRadius: 14,
    borderWidth: 1,
  },
  contactCardText: {
    fontSize: 17,
    fontFamily: "Comfortaa_400Regular",
    flex: 1,
  },
  contactRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    minHeight: 44,
  },
  devRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    minHeight: 44,
  },
  devHint: {
    fontSize: 13,
    fontFamily: "Comfortaa_400Regular",
    textAlign: "right",
    marginLeft: 8,
  },
});
