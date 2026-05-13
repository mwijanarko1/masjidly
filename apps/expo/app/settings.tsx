import React, { useEffect, useState, useCallback } from "react";
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
} from "react-native";
import { useRouter, useLocalSearchParams } from "expo-router";
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
import { visibleMosques } from "@/lib/prayer/mosqueDefaults";
import { useSettingsStore } from "@/store/settings";
import { t, type TranslationKey } from "@/lib/i18n/translations";
import { resolvedLanguageCode } from "@/lib/i18n/language";
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
    const locale = resolvedLanguageCode();
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
  const theme = themeForPrayer(themeParam ?? "Fajr");
  const sky = getSkyTheme(theme);
  const textColor = getTextColor(theme);
  const invertSheet = getUsesLightForeground(theme);

  const settings = useSettingsStore();

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
  const langCode = resolvedLanguageCode();

  useEffect(() => {
    prayerRepository.listMosques().then((all) => {
      setMosques(visibleMosques(all));
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  const handleMosqueSelect = (mosque: Mosque) => {
    settings.setSelectedMosque(mosque.id, mosque.slug);
    rescheduleNotifications(useSettingsStore.getState());
  };

  const handle24hToggle = (v: boolean) => {
    settings.setUses24HourTime(v);
  };

  const handleQiblaToggle = (v: boolean) => {
    settings.setHideQiblaCompass(!v);
    // On iOS, enabling qibla when location is notDetermined triggers a permission request
    if (v && Platform.OS === "ios") {
      // On iOS, the system handles this; on Android, we don't have a direct equivalent
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
          ? "Masjidly Feedback"
          : "Masjidly Prayer Time Issue";
      const bodyLines: string[] = [];
      bodyLines.push("");
      bodyLines.push("---");
      bodyLines.push(`App: Masjidly`);
      bodyLines.push(`Mosque: ${mosqueName ?? "Not selected"}`);
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
  const qiblaIsHidden = settings.hideQiblaCompass;

  const handleLocationRecovery = useCallback(() => {
    if (Platform.OS === "ios") {
      Linking.openURL("app-settings:");
    } else {
      Linking.openSettings();
    }
  }, []);

  // ── Test notifications (dev) ──
  const fireTestNotification = useCallback(
    async (type: "adhan" | "iqamah" | "reminder" | "all") => {
      try {
        const granted = await requestNotificationAuthorizationIfNeeded();
        if (!granted) {
          Alert.alert(
            "Notifications not enabled",
            "Please enable notifications in your device settings to use test notifications."
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
          "Maghrib Adhan",
          "Tap to hear adhan.",
          "adhan",
          { kind: "adhan", prayer: "maghrib", mosqueSlug: slug }
        );
      }
      if (type === "iqamah" || type === "all") {
        await scheduleOne(
          "Maghrib Iqamah",
          "Iqamah for Maghrib is now.",
          "iqamah",
          { kind: "iqamah", prayer: "maghrib", mosqueSlug: slug }
        );
      }
      if (type === "reminder" || type === "all") {
        await scheduleOne(
          "Maghrib soon",
          "Adhan in 10 min.",
          "reminder",
          { kind: "reminder", prayer: "maghrib", mosqueSlug: slug }
        );
      }
      } catch (e) {
        Alert.alert(
          "Test notification failed",
          e instanceof Error ? e.message : "An unknown error occurred"
        );
      }
    },
    [settings.selectedMosqueSlug]
  );

  const SectionCaption: React.FC<{ children: React.ReactNode }> = ({ children }) => (
    <Text style={[styles.sectionCaption, { color: textColor + "85" }]}>
      {children}
    </Text>
  );

  const RowDivider = () => (
    <View style={[styles.divider, { backgroundColor: textColor + "2E" }]} />
  );

  const selectedMosqueName =
    mosques.find((m) => m.id === settings.selectedMosqueId)?.name
    ?? t("settings.reminder.none", langCode);

  const reminderDisplayLabel = (minutes: number | null) => {
    const opt = REMINDER_OPTIONS.find((o) => o.value === minutes);
    return opt ? t(opt.labelKey, langCode) : t("settings.reminder.none", langCode);
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
                label={t("settings.mosque.picker", langCode)}
                displayValue={selectedMosqueName}
                value={settings.selectedMosqueId ?? ""}
                options={mosques.map((m) => ({ label: m.name, value: m.id }))}
                onSelect={(id) => {
                  const m = mosques.find((x) => x.id === id);
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

          {/* Location Recovery Section (shown when qibla is hidden) */}
          {qiblaIsHidden ? (
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
                    accessibilityLabel={t("settings.location.open_settings", langCode)}
                  >
                    <Text style={[styles.locationRecoveryButtonText, { color: "#FFFFFF" }]}>
                      {t("settings.location.open_settings", langCode)}
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

          {/* Development Section */}
          {__DEV__ ? (
            <>
              <SectionCaption>Development</SectionCaption>
              <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
                {/* Reset tutorial */}
                <Pressable
                  style={({ pressed }) => [
                    styles.contactRow,
                    pressed && { opacity: 0.7 },
                  ]}
                  onPress={() => {
                    useSettingsStore.getState().setHasCompletedOnboarding(false);
                    Alert.alert(
                      "Tutorial reset",
                      "Onboarding flags have been reset. Close and reopen the app to restart the tutorial.",
                      [{ text: "OK" }]
                    );
                  }}
                  accessibilityRole="button"
                  accessibilityLabel="Reset tutorial"
                >
                  <Text style={[styles.listItemText, { color: textColor }]}>
                    Reset tutorial
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
                    Test Adhan
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    Instant
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
                    Test Iqamah
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    Instant
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
                    Test Reminder
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    Instant
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
                    Test All Three
                  </Text>
                  <Text style={[styles.devHint, { color: textColor + "8C" }]}>
                    3× instant
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
