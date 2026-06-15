import React, { useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  Switch,
  ActivityIndicator,
  ScrollView,
  type ViewStyle,
  type TextStyle,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { ChevronDown, ChevronRight } from "lucide-react-native";
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
  onAdhanPrayerChange: (prayer: PrayerKey, value: boolean) => void;
  onIqamahPrayerChange: (prayer: PrayerKey, value: boolean) => void;
  onFinish: () => void;
  textColor: string;
  usesLightForeground: boolean;
  locale: AppLanguage;
}

type PrayerKey = "fajr" | "dhuhrJummah" | "asr" | "maghrib" | "isha";

const PRAYER_KEYS: PrayerKey[] = ["fajr", "dhuhrJummah", "asr", "maghrib", "isha"];

const PRAYER_TRANSLATION_KEYS: Record<PrayerKey, TranslationKey> = {
  fajr: "settings.notification.fajr",
  dhuhrJummah: "settings.notification.dhuhr_jummah",
  asr: "settings.notification.asr",
  maghrib: "settings.notification.maghrib",
  isha: "settings.notification.isha",
};

const REMINDER_OPTIONS: { labelKey: TranslationKey; value: number | null }[] = [
  { labelKey: "settings.reminder.none", value: null },
  { labelKey: "settings.reminder.5min", value: 5 },
  { labelKey: "settings.reminder.10min", value: 10 },
  { labelKey: "settings.reminder.15min", value: 15 },
  { labelKey: "settings.reminder.30min", value: 30 },
];

// ---------------------------------------------------------------------------
// Collapsible Section
// ---------------------------------------------------------------------------

function CollapsibleSection({
  title,
  expanded,
  onToggle,
  children,
  textColor,
}: {
  title: string;
  expanded: boolean;
  onToggle: () => void;
  children: React.ReactNode;
  textColor: string;
}) {
  return (
    <View>
      <Pressable
        style={styles.sectionHeader}
        onPress={onToggle}
        accessibilityRole="button"
      >
        <View style={styles.sectionHeaderRow}>
          <View style={styles.chevronContainer}>
            {expanded ? (
              <ChevronDown size={18} color={textColor} strokeWidth={2.5} />
            ) : (
              <ChevronRight size={18} color={textColor} strokeWidth={2.5} />
            )}
          </View>
          <Text style={[styles.sectionHeaderText, { color: textColor }]}>
            {title}
          </Text>
        </View>
      </Pressable>
      {expanded && <View style={styles.sectionContent}>{children}</View>}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

// Helper: map PrayerKey to adhan/iqamah field name in Draft
type DraftPrayerField = keyof Pick<NotificationDraft, "adhanFajr" | "adhanDhuhrJummah" | "adhanAsr" | "adhanMaghrib" | "adhanIsha" | "iqamahFajr" | "iqamahDhuhrJummah" | "iqamahAsr" | "iqamahMaghrib" | "iqamahIsha">;

const ADHAN_PREFIX = "adhan" as const;
const IQAMAH_PREFIX = "iqamah" as const;

function prayerDraftField(prefix: typeof ADHAN_PREFIX | typeof IQAMAH_PREFIX, prayer: PrayerKey): DraftPrayerField {
  return `${prefix}${prayer.charAt(0).toUpperCase()}${prayer.slice(1)}` as DraftPrayerField;
}

export function NotificationSetupCard({
  draft,
  isSaving,
  onAdhanChange,
  onIqamahChange,
  onAdhanReminderChange,
  onIqamahReminderChange,
  onAdhanPrayerChange,
  onIqamahPrayerChange,
  onFinish,
  textColor,
  usesLightForeground,
  locale,
}: NotificationSetupCardProps) {
  const [adhanExpanded, setAdhanExpanded] = useState(true);
  const [iqamahExpanded, setIqamahExpanded] = useState(true);

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
          {/* Scroll wrapper */}
          <ScrollView
            style={styles.scrollContent}
            contentContainerStyle={styles.scrollContentInner}
            bounces={false}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
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

            {/* Adhan collapsible section */}
            <CollapsibleSection
              title={t("onboarding.notifications.prayers_adhan", locale)}
              expanded={adhanExpanded}
              onToggle={() => setAdhanExpanded(!adhanExpanded)}
              textColor={textColor}
            >
              {PRAYER_KEYS.map((prayer, idx) => (
                <React.Fragment key={prayer}>
                  {idx > 0 && (
                    <View style={[styles.divider, { backgroundColor: textColor + "1F" }]} />
                  )}
                  <View style={styles.toggleRow}>
                    <Text style={[styles.toggleLabel, { color: textColor }]}>
                      {t(PRAYER_TRANSLATION_KEYS[prayer], locale)}
                    </Text>
                    <View style={styles.switchWrap}>
                      <Switch
                        value={draft[prayerDraftField(ADHAN_PREFIX, prayer)]}
                        onValueChange={(v) => onAdhanPrayerChange(prayer, v)}
                        trackColor={{ false: textColor + "33", true: ACCENT + "66" }}
                        thumbColor={draft[prayerDraftField(ADHAN_PREFIX, prayer)] ? ACCENT : textColor + "80"}
                        accessibilityLabel={`Toggle adhan ${prayer}`}
                      />
                    </View>
                  </View>
                </React.Fragment>
              ))}
            </CollapsibleSection>

            <View style={[styles.divider, { backgroundColor: textColor + "1F" }]} />

            {/* Iqamah collapsible section */}
            <CollapsibleSection
              title={t("onboarding.notifications.prayers_iqamah", locale)}
              expanded={iqamahExpanded}
              onToggle={() => setIqamahExpanded(!iqamahExpanded)}
              textColor={textColor}
            >
              {PRAYER_KEYS.map((prayer, idx) => (
                <React.Fragment key={prayer}>
                  {idx > 0 && (
                    <View style={[styles.divider, { backgroundColor: textColor + "1F" }]} />
                  )}
                  <View style={styles.toggleRow}>
                    <Text style={[styles.toggleLabel, { color: textColor }]}>
                      {t(PRAYER_TRANSLATION_KEYS[prayer], locale)}
                    </Text>
                    <View style={styles.switchWrap}>
                      <Switch
                        value={draft[prayerDraftField(IQAMAH_PREFIX, prayer)]}
                        onValueChange={(v) => onIqamahPrayerChange(prayer, v)}
                        trackColor={{ false: textColor + "33", true: ACCENT + "66" }}
                        thumbColor={draft[prayerDraftField(IQAMAH_PREFIX, prayer)] ? ACCENT : textColor + "80"}
                        accessibilityLabel={`Toggle iqamah ${prayer}`}
                      />
                    </View>
                  </View>
                </React.Fragment>
              ))}
            </CollapsibleSection>

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
          </ScrollView>
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
    maxHeight: 540,
  } as ViewStyle,
  scrollContent: {
    maxHeight: 540 - 48, // card maxHeight minus vertical padding
  } as ViewStyle,
  scrollContentInner: {
    paddingBottom: 4,
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
  sectionHeader: {
    paddingVertical: 10,
  } as ViewStyle,
  sectionHeaderRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  } as ViewStyle,
  chevronContainer: {
    width: 20,
    height: 20,
    alignItems: "center",
    justifyContent: "center",
  } as ViewStyle,
  sectionHeaderText: {
    fontSize: 18,
    fontFamily: "Comfortaa_600SemiBold",
  } as TextStyle,
  sectionContent: {
    paddingLeft: 4,
  } as ViewStyle,
  toggleRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    minHeight: 50,
    paddingVertical: 8,
    paddingRight: 2,
    gap: 12,
  } as ViewStyle,
  toggleLabel: {
    flex: 1,
    fontSize: 16,
    fontFamily: "Comfortaa_500Medium",
  } as TextStyle,
  switchWrap: {
    flexShrink: 0,
    paddingVertical: 2,
    paddingHorizontal: 2,
    alignItems: "center",
    justifyContent: "center",
  } as ViewStyle,
  divider: {
    height: StyleSheet.hairlineWidth,
    marginVertical: 6,
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
