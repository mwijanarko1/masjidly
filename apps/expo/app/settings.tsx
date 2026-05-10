import React, { useEffect, useState } from "react";
import {
  View, Text, StyleSheet, Pressable, ScrollView, ActivityIndicator, Alert,
} from "react-native";
import { useRouter } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { X, Check } from "lucide-react-native";
import { LinearGradient } from "expo-linear-gradient";
import { COLORS, SPACING, FONT_SIZES } from "@/constants";
import { SettingsToggleRow } from "@/components/ui/SettingsToggleRow";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import { visibleMosques } from "@/lib/prayer/mosqueDefaults";
import { useSettingsStore, type SettingsState } from "@/store/settings";
import { t } from "@/lib/i18n/translations";
import { resolvedLanguageCode } from "@/lib/i18n/language";
import { getLocales } from "expo-localization";
import type { Mosque } from "@/types/prayer";

const LANGUAGES: { value: SettingsState["appLanguage"]; label: string }[] = [
  { value: "system", label: "System" },
  { value: "english", label: "English" },
  { value: "arabic", label: "Arabic" },
  { value: "urdu", label: "Urdu" },
];

function rescheduleNotificationsCallback() {
  if (__DEV__) console.log("[Settings] Rescheduling notifications...");
}

function handleTestTutorialDev() {
  Alert.alert(
    "Test tutorial",
    "Tutorial flow is not wired yet. Use this entry point while developing.",
    [{ text: "OK" }]
  );
}

export default function SettingsScreen() {
  const router = useRouter();
  const settings = useSettingsStore();
  const systemLocale = getLocales()[0].languageTag;
  const languageCode = resolvedLanguageCode(settings.appLanguage, systemLocale);

  const [mosques, setMosques] = useState<Mosque[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    prayerRepository.listMosques().then((all) => {
      setMosques(visibleMosques(all));
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  const handleMosqueSelect = (mosque: Mosque) => {
    settings.setSelectedMosque(mosque.id, mosque.slug);
  };

  const handleLanguageChange = (lang: SettingsState["appLanguage"]) => {
    settings.setAppLanguage(lang);
  };

  const handle24hToggle = (v: boolean) => {
    settings.setUses24HourTime(v);
  };

  const handleMasterToggle = (v: boolean) => {
    settings.setNotificationMaster(v);
    rescheduleNotificationsCallback();
  };

  const handlePrayerToggle = (
    prayer: keyof Omit<SettingsState["notifications"], "masterEnabled">,
    v: boolean
  ) => {
    settings.setNotificationPrayer(prayer, v);
    rescheduleNotificationsCallback();
  };

  const showRtlNote = settings.appLanguage === "arabic" || settings.appLanguage === "urdu";

  return (
    <LinearGradient colors={[COLORS.background, COLORS.backgroundSecondary]} style={styles.gradient}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <Pressable onPress={() => router.back()} accessibilityRole="button">
            <X size={24} color={COLORS.primary} />
          </Pressable>
          <Text style={styles.headerTitle}>{t("settings.navigation.title", languageCode)}</Text>
          <View style={{ width: 24 }} />
        </View>

        <ScrollView contentContainerStyle={styles.content}>
          {/* Mosque Section */}
          <Text style={styles.sectionTitle}>{t("settings.section.mosque.title", languageCode)}</Text>
          <Text style={styles.sectionSubtitle}>{t("settings.section.mosque.subtitle", languageCode)}</Text>
          {loading ? <ActivityIndicator color={COLORS.accent} /> : (
            <View style={styles.list}>
              {mosques.map((mosque) => {
                const selected = mosque.id === settings.selectedMosqueId;
                return (
                  <Pressable key={mosque.id} style={[styles.listItem, selected && styles.listItemSelected]}
                    onPress={() => handleMosqueSelect(mosque)} accessibilityRole="radio" accessibilityState={{ checked: selected }}>
                    <Text style={[styles.listItemText, selected && styles.listItemTextSelected]} numberOfLines={1}>
                      {mosque.name}
                    </Text>
                    {selected ? <Check size={18} color={COLORS.accent} /> : null}
                  </Pressable>
                );
              })}
            </View>
          )}

          {/* Language Section */}
          <Text style={styles.sectionTitle}>{t("settings.language.title", languageCode)}</Text>
          <View style={styles.list}>
            {LANGUAGES.map((lang) => {
              const selected = settings.appLanguage === lang.value;
              return (
                <Pressable key={lang.value} style={[styles.listItem, selected && styles.listItemSelected]}
                  onPress={() => handleLanguageChange(lang.value)} accessibilityRole="radio" accessibilityState={{ checked: selected }}>
                  <Text style={[styles.listItemText, selected && styles.listItemTextSelected]}>{lang.label}</Text>
                  {selected ? <Check size={18} color={COLORS.accent} /> : null}
                </Pressable>
              );
            })}
          </View>
          {showRtlNote ? (
            <Text style={styles.rtlNote}>App restart may be needed for full RTL layout.</Text>
          ) : null}

          {/* Display Section */}
          <Text style={styles.sectionTitle}>{t("settings.section.display.title", languageCode)}</Text>
          <SettingsToggleRow
            title={t("settings.time.24h.title", languageCode)}
            value={settings.uses24HourTime}
            onValueChange={handle24hToggle}
          />

          {/* Notifications Section */}
          <Text style={styles.sectionTitle}>{t("settings.notifications.title", languageCode)}</Text>
          <SettingsToggleRow
            title={t("settings.notifications.master.title", languageCode)}
            value={settings.notifications.masterEnabled}
            onValueChange={handleMasterToggle}
          />
          {settings.notifications.masterEnabled ? (
            <View style={styles.subList}>
              <SettingsToggleRow
                title={t("settings.notification.fajr", languageCode)}
                value={settings.notifications.fajr}
                onValueChange={(v) => handlePrayerToggle("fajr", v)}
              />
              <SettingsToggleRow
                title={t("settings.notification.dhuhr_jummah", languageCode)}
                value={settings.notifications.dhuhrJummah}
                onValueChange={(v) => handlePrayerToggle("dhuhrJummah", v)}
              />
              <SettingsToggleRow
                title={t("settings.notification.asr", languageCode)}
                value={settings.notifications.asr}
                onValueChange={(v) => handlePrayerToggle("asr", v)}
              />
              <SettingsToggleRow
                title={t("settings.notification.maghrib", languageCode)}
                value={settings.notifications.maghrib}
                onValueChange={(v) => handlePrayerToggle("maghrib", v)}
              />
              <SettingsToggleRow
                title={t("settings.notification.isha", languageCode)}
                value={settings.notifications.isha}
                onValueChange={(v) => handlePrayerToggle("isha", v)}
              />
            </View>
          ) : null}

          {__DEV__ ? (
            <>
              <Text style={styles.sectionTitle}>Development</Text>
              <Pressable
                style={styles.listItem}
                onPress={handleTestTutorialDev}
                accessibilityRole="button"
                accessibilityLabel="Test tutorial"
              >
                <Text style={styles.listItemText}>Test tutorial</Text>
              </Pressable>
            </>
          ) : null}
        </ScrollView>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  gradient: { flex: 1 },
  safeArea: { flex: 1 },
  header: {
    flexDirection: "row", alignItems: "center", justifyContent: "space-between",
    paddingHorizontal: SPACING.md, paddingVertical: SPACING.sm,
  },
  headerTitle: {
    fontSize: FONT_SIZES.lg, fontWeight: "600", color: COLORS.primary,
    flex: 1, textAlign: "center", marginHorizontal: SPACING.sm,
  },
  content: { paddingHorizontal: SPACING.md, paddingBottom: SPACING.xl },
  sectionTitle: {
    fontSize: FONT_SIZES.md, fontWeight: "700", color: COLORS.primary,
    marginTop: SPACING.lg, marginBottom: SPACING.xs, textTransform: "uppercase",
  },
  sectionSubtitle: {
    fontSize: FONT_SIZES.sm, color: COLORS.secondary, marginBottom: SPACING.sm,
  },
  list: { gap: SPACING.xs },
  listItem: {
    flexDirection: "row", alignItems: "center", justifyContent: "space-between",
    paddingVertical: SPACING.sm, paddingHorizontal: SPACING.md,
    backgroundColor: `${COLORS.background}80`, borderRadius: 12,
  },
  listItemSelected: { backgroundColor: `${COLORS.accent}15` },
  listItemText: { fontSize: FONT_SIZES.md, color: COLORS.primary, flex: 1 },
  listItemTextSelected: { fontWeight: "600" },
  rtlNote: {
    fontSize: FONT_SIZES.sm, color: COLORS.secondary, marginTop: SPACING.sm, fontStyle: "italic",
  },
  subList: { paddingLeft: SPACING.md, gap: SPACING.xs },
});
