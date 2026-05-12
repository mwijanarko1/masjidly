import React, { useEffect, useState } from "react";
import {
  View, Text, StyleSheet, Pressable, ScrollView, ActivityIndicator,
  Switch,
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
} from "@/lib/notifications/prayerNotifications";
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

  const handlePrayerToggle = (
    prayer: keyof import("@/store/settings").NotificationSettings,
    v: boolean
  ) => {
    settings.setNotificationPrayer(prayer, v);
    rescheduleNotifications(useSettingsStore.getState());
  };

  const REMINDER_OPTIONS: { labelKey: TranslationKey; value: number | null }[] = [
    { labelKey: "settings.reminder.none", value: null },
    { labelKey: "settings.reminder.5min", value: 5 },
    { labelKey: "settings.reminder.10min", value: 10 },
    { labelKey: "settings.reminder.15min", value: 15 },
    { labelKey: "settings.reminder.30min", value: 30 },
  ];

  const prayerToggles: {
    key: Exclude<keyof import("@/store/settings").NotificationSettings, "masterEnabled" | "adhanEnabled" | "iqamahEnabled" | "preAdhanReminderMinutes" | "preIqamahReminderMinutes">;
    labelKey: TranslationKey;
  }[] = [
    { key: "fajr", labelKey: "settings.notification.fajr" },
    { key: "dhuhrJummah", labelKey: "settings.notification.dhuhr_jummah" },
    { key: "asr", labelKey: "settings.notification.asr" },
    { key: "maghrib", labelKey: "settings.notification.maghrib" },
    { key: "isha", labelKey: "settings.notification.isha" },
  ];

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
                {prayerToggles.map(({ key, labelKey }, index) => (
                  <View key={key}>
                    <RowDivider />
                    <SettingsToggleRow
                      title={t(labelKey, langCode)}
                      value={settings.notifications[key] as boolean}
                      onValueChange={(v) => handlePrayerToggle(key, v)}
                      textColor={textColor}
                    />
                  </View>
                ))}
              </>
            ) : null}
          </View>

          {__DEV__ ? (
            <>
              <SectionCaption>Development</SectionCaption>
              <View style={[styles.listBlock, { backgroundColor: textColor + "0D" }]}>
                <Pressable
                  style={styles.listItem}
                  onPress={() => {
                    useSettingsStore.getState().setHasCompletedOnboarding(false);
                    const { Alert } = require("react-native");
                    Alert.alert(
                      "Tutorial reset",
                      "Onboarding flags have been reset. Close and reopen the app to restart the tutorial.",
                      [{ text: "OK" }]
                    );
                  }}
                  accessibilityRole="button"
                  accessibilityLabel="Reset tutorial"
                >
                  <Text style={[styles.listItemText, { color: textColor, fontFamily: "Comfortaa_400Regular" }]}>
                    Reset tutorial
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
  listItem: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    minHeight: 44,
  },
  listItemText: {
    fontSize: FONT_SIZES.md,
    flex: 1,
  },
  divider: {
    height: 0.5,
    marginHorizontal: SPACING.md,
  },
});
