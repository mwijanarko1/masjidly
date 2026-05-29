import React from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Switch,
  ActivityIndicator,
  type ViewStyle,
  type TextStyle,
} from "react-native";
import { ACCENT } from "@/lib/design/themes";
import type { NotificationDraft } from "@/store/onboarding";
import type { AppLanguage } from "@/store/settings";
import { t, type TranslationKey } from "@/lib/i18n/translations";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface NotificationSetupCardProps {
  draft: NotificationDraft;
  isSaving: boolean;
  onAdhanChange: (v: boolean) => void;
  onIqamahChange: (v: boolean) => void;
  onAdhanReminderChange: (v: number | null) => void;
  onIqamahReminderChange: (v: number | null) => void;
  onFinish: () => void;
  textColor: string;
  usesLightForeground: boolean;
  locale: AppLanguage;
}

const REMINDER_OPTIONS: { labelKey: TranslationKey; value: number | null }[] = [
  { labelKey: "settings.reminder.none", value: null },
  { labelKey: "settings.reminder.5min", value: 5 },
  { labelKey: "settings.reminder.10min", value: 10 },
  { labelKey: "settings.reminder.15min", value: 15 },
  { labelKey: "settings.reminder.30min", value: 30 },
];

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function NotificationSetupCard({
  draft,
  isSaving,
  onAdhanChange,
  onIqamahChange,
  onAdhanReminderChange,
  onIqamahReminderChange,
  onFinish,
  textColor,
  usesLightForeground,
  locale,
}: NotificationSetupCardProps) {
  const reminderOptions = REMINDER_OPTIONS;

  const glassBg = usesLightForeground
    ? "rgb(10, 10, 30)"
    : "rgb(255, 255, 255)";
  const glassBorder = usesLightForeground
    ? "rgba(255, 255, 255, 0.15)"
    : "rgba(240, 240, 240, 0.6)";

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="auto">
      {/* Dimming backdrop */}
      <View
        style={[
          StyleSheet.absoluteFill,
          {
            backgroundColor: usesLightForeground
              ? "rgba(0, 0, 0, 0.24)"
              : "rgba(0, 0, 0, 0.13)",
          },
        ]}
      />

      {/* Scrollable center content */}
      <View style={styles.centerContainer} pointerEvents="box-none">
        <View
          style={[
            styles.glassCard,
            {
              backgroundColor: glassBg,
              borderColor: glassBorder,
              shadowColor: usesLightForeground
                ? "rgba(0,0,0,0.25)"
                : "rgba(0,0,0,0.10)",
            },
          ]}
        >
          {/* Title */}
          <View style={{ marginBottom: 16 }}>
            <Text style={[styles.title, { color: textColor }]}>
              {t("onboarding.notifications.title", locale)}
            </Text>
            <Text style={[styles.subtitle, { color: textColor + "CC" }]}>
              {t("onboarding.notifications.subtitle", locale)}
            </Text>
          </View>

          {/* Toggles */}
          <View style={styles.toggleRow}>
            <Text style={[styles.toggleLabel, { color: textColor }]}>
              {t("notification.channel.adhan", locale)}
            </Text>
            <Switch
              value={draft.adhanEnabled}
              onValueChange={onAdhanChange}
              trackColor={{ false: textColor + "33", true: ACCENT + "66" }}
              thumbColor={draft.adhanEnabled ? ACCENT : textColor + "80"}
              accessibilityLabel={
                t("onboarding.notifications.toggle_adhan", locale)
              }
              accessibilityIdentifier="Onboarding.AdhanToggle"
            />
          </View>

          <View style={[styles.divider, { backgroundColor: textColor + "1F" }]} />

          <View style={styles.toggleRow}>
            <Text style={[styles.toggleLabel, { color: textColor }]}>
              {t("notification.channel.iqamah", locale)}
            </Text>
            <Switch
              value={draft.iqamahEnabled}
              onValueChange={onIqamahChange}
              trackColor={{ false: textColor + "33", true: ACCENT + "66" }}
              thumbColor={draft.iqamahEnabled ? ACCENT : textColor + "80"}
              accessibilityLabel={
                t("onboarding.notifications.toggle_iqamah", locale)
              }
              accessibilityIdentifier="Onboarding.IqamahToggle"
            />
          </View>

          <View style={[styles.divider, { backgroundColor: textColor + "1F" }]} />

          {/* Reminder section header */}
          <Text
            style={[
              styles.reminderSectionTitle,
              { color: textColor + "99" },
            ]}
          >
            {t("onboarding.notifications.reminders", locale)}
          </Text>

          {/* Pre-Adhan reminder */}
          <Text style={[styles.reminderLabel, { color: textColor }]}>
            {t("settings.reminder.before_adhan", locale)}
          </Text>
          <View style={styles.pillRow}>
            {reminderOptions.map((opt) => {
              const selected = opt.value === draft.preAdhanReminderMinutes;
              const pillBg = selected
                ? ACCENT
                : usesLightForeground
                ? "rgba(255,255,255,0.12)"
                : "rgba(0,0,0,0.08)";
              return (
                <Pressable
                  key={String(opt.value)}
                  style={[styles.pill, { backgroundColor: pillBg }]}
                  onPress={() => onAdhanReminderChange(opt.value)}
                  accessibilityRole="button"
                  accessibilityLabel={t(opt.labelKey, locale)}
                  accessibilityIdentifier="Onboarding.AdhanReminderPicker"
                >
                  <Text
                    style={[
                      styles.pillText,
                      { color: selected ? "#FFFFFF" : textColor },
                    ]}
                  >
                    {t(opt.labelKey, locale)}
                  </Text>
                </Pressable>
              );
            })}
          </View>

          {/* Pre-Iqamah reminder */}
          <View style={{ height: 12 }} />
          <Text style={[styles.reminderLabel, { color: textColor }]}>
            {t("settings.reminder.before_iqamah", locale)}
          </Text>
          <View style={styles.pillRow}>
            {reminderOptions.map((opt) => {
              const selected = opt.value === draft.preIqamahReminderMinutes;
              const pillBg = selected
                ? ACCENT
                : usesLightForeground
                ? "rgba(255,255,255,0.12)"
                : "rgba(0,0,0,0.08)";
              return (
                <Pressable
                  key={String(opt.value)}
                  style={[styles.pill, { backgroundColor: pillBg }]}
                  onPress={() => onIqamahReminderChange(opt.value)}
                  accessibilityRole="button"
                  accessibilityLabel={t(opt.labelKey, locale)}
                  accessibilityIdentifier="Onboarding.IqamahReminderPicker"
                >
                  <Text
                    style={[
                      styles.pillText,
                      { color: selected ? "#FFFFFF" : textColor },
                    ]}
                  >
                    {t(opt.labelKey, locale)}
                  </Text>
                </Pressable>
              );
            })}
          </View>

          {/* Finish button */}
          <View style={{ height: 20 }} />
          <Pressable
            style={[styles.finishButton, { opacity: isSaving ? 0.7 : 1 }]}
            onPress={onFinish}
            disabled={isSaving}
            accessibilityRole="button"
            accessibilityLabel={
              t("action.finish", locale)
            }
            accessibilityIdentifier="Onboarding.NotificationFinish"
          >
            {isSaving ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.finishButtonText}>
                {t("action.finish", locale)}
              </Text>
            )}
          </Pressable>
        </View>
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  centerContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 24,
  } as ViewStyle,
  glassCard: {
    width: "100%",
    maxWidth: 400,
    borderRadius: 24,
    padding: 24,
    borderWidth: 1,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.24,
    shadowRadius: 30,
    elevation: 10,
    maxHeight: "85%",
  } as ViewStyle,
  title: {
    fontSize: 23,
    fontFamily: "Comfortaa_600SemiBold",
    letterSpacing: -0.5,
    marginBottom: 8,
  } as TextStyle,
  subtitle: {
    fontSize: 16,
    fontFamily: "Comfortaa_400Regular",
    lineHeight: 22,
  } as TextStyle,
  toggleRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 8,
  } as ViewStyle,
  toggleLabel: {
    fontSize: 18,
    fontFamily: "Comfortaa_500Medium",
  } as TextStyle,
  divider: {
    height: StyleSheet.hairlineWidth,
    marginVertical: 8,
  } as ViewStyle,
  reminderSectionTitle: {
    fontSize: 13,
    fontFamily: "Comfortaa_600SemiBold",
    textTransform: "uppercase",
    letterSpacing: 0.5,
    marginTop: 8,
    marginBottom: 12,
  } as TextStyle,
  reminderLabel: {
    fontSize: 16,
    fontFamily: "Comfortaa_400Regular",
    marginBottom: 8,
  } as TextStyle,
  pillRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 6,
  } as ViewStyle,
  pill: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
  } as ViewStyle,
  pillText: {
    fontSize: 14,
    fontFamily: "Comfortaa_500Medium",
  } as TextStyle,
  finishButton: {
    backgroundColor: ACCENT,
    paddingVertical: 16,
    borderRadius: 100,
    alignItems: "center",
    minHeight: 52,
    justifyContent: "center",
    shadowColor: ACCENT,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 15,
    elevation: 6,
  } as ViewStyle,
  finishButtonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontFamily: "Comfortaa_600SemiBold",
  } as TextStyle,
});
