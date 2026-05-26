import React, { useEffect, useState, useCallback, useMemo } from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  ActivityIndicator,
  Linking,
  Platform,
  Alert,
  DeviceEventEmitter,
} from "react-native";
import { useRouter, useLocalSearchParams } from "expo-router";
import * as Location from "expo-location";
import { SafeAreaView } from "react-native-safe-area-context";
import { X } from "lucide-react-native";
import { AtmosphericSkyBackground } from "@/components/ui/AtmosphericSkyBackground";
import { TutorialHighlight } from "@/components/onboarding/CoachMarkCard";
import { TutorialOverlay } from "@/components/onboarding/TutorialOverlay";
import { useOnboardingStore } from "@/store/onboarding";
import { SettingsMenuPickerRow } from "@/components/ui/SettingsMenuPickerRow";
import { SPACING, FONT_SIZES } from "@/constants";
import { SettingsToggleRow } from "@/components/ui/SettingsToggleRow";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import { visibleMosques, cityOptions, mosquesInCity, cityGroupingKey } from "@/lib/prayer/mosqueDefaults";
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
import type { Mosque } from "@/types/prayer";
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

async function rescheduleNotifications(
  settings: ReturnType<typeof useSettingsStore.getState>
): Promise<void> {
  try {
    if (!settings.notifications.masterEnabled) {
      await cancelAllPrayerNotifications();
      return;
    }
    const mosques = await prayerRepository.listMosques();
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
    });
  } catch {
    // Notification native modules may not be available (Android Expo Go); fail silently.
  }
}

export default function SettingsScreen() {
  const router = useRouter();
  const { theme: themeParam } = useLocalSearchParams<{ theme?: string }>();
  const settings = useSettingsStore();
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
  const langCode = useAppLanguage();

  useEffect(() => {
    prayerRepository.listMosques().then((all) => {
      setMosques(visibleMosques(all));
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  const cities = useMemo(() => cityOptions(mosques), [mosques]);

  const effectiveCityKey = useMemo(() => {
    const stored = settings.selectedCityGroupingKey;
    if (stored && mosquesInCity(stored, mosques).length > 0) {
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
  ]);

  const mosquesInSelectedCity = useMemo(
    () => (effectiveCityKey ? mosquesInCity(effectiveCityKey, mosques) : mosques),
    [mosques, effectiveCityKey]
  );

  const handleMosqueSelect = (mosque: Mosque) => {
    settings.setSelectedMosque(mosque.id, mosque.slug, cityGroupingKey(mosque));
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleCitySelect = (key: string) => {
    settings.setSelectedCityGroupingKey(key);
    const inCity = mosquesInCity(key, mosques);
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
    settings.setAdhanEnabled(v);
    const state = useSettingsStore.getState();
    if (v && !state.notifications.masterEnabled) {
      settings.setNotificationMaster(true);
    }
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handleIqamahToggle = (v: boolean) => {
    settings.setIqamahEnabled(v);
    const state = useSettingsStore.getState();
    if (v && !state.notifications.masterEnabled) {
      settings.setNotificationMaster(true);
    }
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

  const REMINDER_OPTIONS: { labelKey: TranslationKey; value: number | null }[] = [
    { labelKey: "settings.reminder.none", value: null },
    { labelKey: "settings.reminder.5min", value: 5 },
    { labelKey: "settings.reminder.10min", value: 10 },
    { labelKey: "settings.reminder.15min", value: 15 },
    { labelKey: "settings.reminder.30min", value: 30 },
  ];

  // ── Contact mailto ──
  const openSupportMail = useCallback(
    (category: "feedback" | "prayerTimes") => {
      const mosqueName =
        mosques.find((m) => m.id === settings.selectedMosqueId)?.name ?? null;
      const subject =
        category === "feedback"
          ? t("settings.email.feedback.subject", langCode)
          : t("settings.email.prayer_times.subject", langCode);
      const bodyLines: string[] = [];
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

  const selectedCityLabel =
    cities.find((c) => c.key === effectiveCityKey)?.label ??
    t("settings.reminder.none", langCode);

  const selectedMosqueName =
    (() => {
      const mosque = mosques.find((m) => m.id === settings.selectedMosqueId);
      return mosque ? formatMosqueLabel(mosque) : t("settings.reminder.none", langCode);
    })();

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
                <SettingsToggleRow
                  title={t("notification.channel.adhan", langCode)}
                  value={settings.notifications.adhanEnabled}
                  onValueChange={handleAdhanToggle}
                  textColor={textColor}
                />
                <RowDivider />
                <SettingsToggleRow
                  title={t("notification.channel.iqamah", langCode)}
                  value={settings.notifications.iqamahEnabled}
                  onValueChange={handleIqamahToggle}
                  textColor={textColor}
                />
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
          <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
            <Pressable
              style={({ pressed }) => [
                styles.contactRow,
                pressed && { opacity: 0.7 },
              ]}
              onPress={() => openSupportMail("feedback")}
              accessibilityRole="button"
            >
              <Text style={[styles.listItemText, { color: textColor }]}>
                {t("settings.contact.feedback.title", langCode)}
              </Text>
            </Pressable>
            <RowDivider />
            <Pressable
              style={({ pressed }) => [
                styles.contactRow,
                pressed && { opacity: 0.7 },
              ]}
              onPress={() => openSupportMail("prayerTimes")}
              accessibilityRole="button"
            >
              <Text style={[styles.listItemText, { color: textColor }]}>
                {t("settings.contact.prayer_times.title", langCode)}
              </Text>
            </Pressable>
          </View>

          {/* Legal Section */}
          <SectionCaption>{t("settings.section.legal.title", langCode)}</SectionCaption>
          <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
            <Pressable
              style={({ pressed }) => [
                styles.contactRow,
                pressed && { opacity: 0.7 },
              ]}
              onPress={() => router.push("/masjidly/terms")}
              accessibilityRole="button"
            >
              <Text style={[styles.listItemText, { color: textColor }]}>
                {t("settings.legal.terms", langCode)}
              </Text>
            </Pressable>
            <RowDivider />
            <Pressable
              style={({ pressed }) => [
                styles.contactRow,
                pressed && { opacity: 0.7 },
              ]}
              onPress={() => router.push("/masjidly/privacy")}
              accessibilityRole="button"
            >
              <Text style={[styles.listItemText, { color: textColor }]}>
                {t("settings.legal.privacy", langCode)}
              </Text>
            </Pressable>
          </View>

          {/* Development Section */}
          {__DEV__ ? (
            <>
              <SectionCaption>{t("settings.dev.title", langCode)}</SectionCaption>
              <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
                {/* Test What\'s New */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactRow,
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() =>
                    router.replace({ pathname: "/", params: { showWhatsNew: "1" } })
                  }
                  accessibilityRole="button"
                >
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    {"Test What's New"}
                  </Text>
                </Pressable>

                <RowDivider />

                {/* Test Update Prompt */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactRow,
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => {
                    DeviceEventEmitter.emit("masjidly:testUpdatePrompt");
                  }}
                  accessibilityRole="button"
                >
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    {"Test Update Prompt"}
                  </Text>
                </Pressable>

                <RowDivider />
                {/* Reset tutorial */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactRow,
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
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    {t("settings.dev.reset_tutorial", langCode)}
                  </Text>
                </Pressable>

                {/* Test notification: Adhan */}
                <RowDivider />
                <Pressable
                  style={({ pressed }) => [
                    styles.devRow,
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("adhan")}
                  accessibilityRole="button"
                >
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    {t("settings.dev.test_adhan", langCode)}
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    {t("settings.dev.instant", langCode)}
                  </Text>
                </Pressable>

                {/* Test notification: Iqamah */}
                <RowDivider />
                <Pressable
                  style={({ pressed }) => [
                    styles.devRow,
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("iqamah")}
                  accessibilityRole="button"
                >
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    {t("settings.dev.test_iqamah", langCode)}
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    {t("settings.dev.instant", langCode)}
                  </Text>
                </Pressable>

                {/* Test notification: Reminder */}
                <RowDivider />
                <Pressable
                  style={({ pressed }) => [
                    styles.devRow,
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("reminder")}
                  accessibilityRole="button"
                >
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    {t("settings.dev.test_reminder", langCode)}
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    {t("settings.dev.instant", langCode)}
                  </Text>
                </Pressable>

                {/* Test notification: All Three */}
                <RowDivider />
                <Pressable
                  style={({ pressed }) => [
                    styles.devRow,
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => fireTestNotification("all")}
                  accessibilityRole="button"
                >
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    {t("settings.dev.test_all", langCode)}
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    {t("settings.dev.three_instant", langCode)}
                  </Text>
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
  divider: {
    height: 0.5,
    marginHorizontal: SPACING.md,
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
