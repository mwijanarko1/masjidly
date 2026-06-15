import React, { useCallback, useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  type ViewStyle,
  type TextStyle,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { ACCENT } from "@/lib/design/themes";
import type { Mosque } from "@/types/prayer";
import {
  cityGroupingKey,
  cityOptions,
  mosquesInCity,
  countryGroupingKey,
  countryOptions,
  mosquesInCountry,
} from "@/lib/prayer/mosqueDefaults";
import { SettingsMenuPickerRow } from "@/components/ui/SettingsMenuPickerRow";
import { t } from "@/lib/i18n/translations";
import type { AppLanguage } from "@/store/settings";
import { SPACING } from "@/constants";

const ONBOARDING_PICKER_LABEL_WIDTH = 72;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface MosqueSelectionCardProps {
  mosques: Mosque[];
  selectedMosqueId: string;
  onSelect: (id: string) => void;
  onContinue: () => void;
  isContinuing?: boolean;
  textColor: string;
  usesLightForeground: boolean;
  locale: AppLanguage;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function MosqueSelectionCard({
  mosques,
  selectedMosqueId,
  onSelect,
  onContinue,
  isContinuing = false,
  textColor,
  usesLightForeground,
  locale,
}: MosqueSelectionCardProps) {
  const countries = useMemo(() => countryOptions(mosques), [mosques]);
  /** Local country filter during onboarding (not persisted until Continue). */
  const [countryKeyOverride, setCountryKeyOverride] = useState<string | undefined>(
    undefined
  );

  /** Local city filter during onboarding (not persisted until Continue). */
  const [cityKeyOverride, setCityKeyOverride] = useState<string | undefined>(
    undefined
  );

  const resolvedCountryKey = useMemo(() => {
    if (countryKeyOverride !== undefined) return countryKeyOverride;
    const m = mosques.find((x) => x.id === selectedMosqueId);
    if (m) return countryGroupingKey(m);
    return countries[0]?.key ?? "";
  }, [countryKeyOverride, mosques, selectedMosqueId, countries]);

  const cities = useMemo(
    () => cityOptions(mosques, resolvedCountryKey),
    [mosques, resolvedCountryKey]
  );

  const resolvedCityKey = useMemo(() => {
    if (cityKeyOverride !== undefined) return cityKeyOverride;
    const m = mosques.find((x) => x.id === selectedMosqueId);
    if (m) return cityGroupingKey(m);
    return cities[0]?.key ?? "";
  }, [cityKeyOverride, mosques, selectedMosqueId, cities]);

  const mosquesInSelectedCity = useMemo(() => {
    const countryMosques = mosquesInCountry(resolvedCountryKey, mosques);
    if (!resolvedCityKey) return countryMosques;
    return mosquesInCity(resolvedCityKey, countryMosques);
  }, [mosques, resolvedCountryKey, resolvedCityKey]);

  const selectedCountryLabel =
    countries.find((c) => c.key === resolvedCountryKey)?.label ??
    t("settings.reminder.none", locale);

  const selectedCityLabel =
    cities.find((c) => c.key === resolvedCityKey)?.label ??
    t("settings.reminder.none", locale);

  const selectedMosqueName =
    mosques.find((m) => m.id === selectedMosqueId)?.name ??
    t("settings.reminder.none", locale);

  const handleCountrySelect = useCallback(
    (key: string) => {
      setCountryKeyOverride(key);
      // Reset city override when country changes
      setCityKeyOverride(undefined);
      const list = mosquesInCountry(key, mosques);
      if (!list.some((m) => m.id === selectedMosqueId) && list[0]) {
        onSelect(list[0].id);
      }
    },
    [mosques, selectedMosqueId, onSelect]
  );

  const handleCitySelect = useCallback(
    (key: string) => {
      setCityKeyOverride(key);
      const countryMosques = mosquesInCountry(resolvedCountryKey, mosques);
      const list = mosquesInCity(key, countryMosques);
      if (!list.some((m) => m.id === selectedMosqueId) && list[0]) {
        onSelect(list[0].id);
      }
    },
    [mosques, selectedMosqueId, resolvedCountryKey, onSelect]
  );

  const handleMosqueSelect = useCallback(
    (id: string) => {
      const m = mosques.find((x) => x.id === id);
      if (m) {
        setCountryKeyOverride(countryGroupingKey(m));
        setCityKeyOverride(cityGroupingKey(m));
      }
      onSelect(id);
    },
    [mosques, onSelect]
  );

  const RowDivider = () => (
    <View
      style={[styles.divider, { backgroundColor: textColor + "2E" }]}
    />
  );

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="auto">
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

      <View style={styles.centerContainer} pointerEvents="box-none">
        <View
          style={[
            styles.glassCard,
            {
              backgroundColor: usesLightForeground
                ? "rgb(10, 10, 30)"
                : "rgb(255, 255, 255)",
              borderColor: usesLightForeground
                ? "rgba(255, 255, 255, 0.15)"
                : "rgba(240, 240, 240, 0.6)",
              shadowColor: usesLightForeground
                ? "rgba(0,0,0,0.25)"
                : "rgba(0,0,0,0.10)",
            },
          ]}
        >
          <View style={{ alignItems: "center", marginBottom: 14 }}>
            <Text style={[styles.title, { color: textColor }]}>
              {t("onboarding.mosque.title", locale)}
            </Text>
            <Text style={[styles.message, { color: textColor + "CC" }]}>
              {t("onboarding.mosque.message", locale)}
            </Text>
          </View>

          <View
            style={[
              styles.listBlock,
              { backgroundColor: textColor + "0D" },
            ]}
          >
            <SettingsMenuPickerRow
              label={t("settings.country.picker", locale)}
              displayValue={selectedCountryLabel}
              value={resolvedCountryKey}
              options={countries.map((c) => ({ label: c.label, value: c.key }))}
              onSelect={handleCountrySelect}
              textColor={textColor}
              invertSheet={usesLightForeground}
              sheetTitle={t("settings.country.picker", locale)}
              testID="Onboarding.CountryPicker"
              labelWidth={ONBOARDING_PICKER_LABEL_WIDTH}
            />
            <RowDivider />
            <SettingsMenuPickerRow
              label={t("settings.city.picker", locale)}
              displayValue={selectedCityLabel}
              value={resolvedCityKey}
              options={cities.map((c) => ({ label: c.label, value: c.key }))}
              onSelect={handleCitySelect}
              textColor={textColor}
              invertSheet={usesLightForeground}
              sheetTitle={t("settings.city.picker", locale)}
              testID="Onboarding.CityPicker"
              labelWidth={ONBOARDING_PICKER_LABEL_WIDTH}
            />
            <RowDivider />
            <SettingsMenuPickerRow
              label={t("settings.mosque.picker", locale)}
              displayValue={selectedMosqueName}
              value={selectedMosqueId}
              options={mosquesInSelectedCity.map((m) => ({
                label: m.name,
                value: m.id,
              }))}
              onSelect={handleMosqueSelect}
              textColor={textColor}
              invertSheet={usesLightForeground}
              sheetTitle={t("settings.section.mosque.title", locale)}
              testID="Onboarding.MosquePicker"
              labelWidth={ONBOARDING_PICKER_LABEL_WIDTH}
            />
          </View>

          <Pressable
            style={[
              styles.continueButton,
              { opacity: selectedMosqueId && !isContinuing ? 1 : 0.45 },
            ]}
            onPress={onContinue}
            disabled={!selectedMosqueId || isContinuing}
            accessibilityRole="button"
            accessibilityLabel={t("onboarding.continue", locale)}
            accessibilityIdentifier="Onboarding.MosqueContinue"
          >
            <Text style={styles.continueButtonText}>
              {t("onboarding.continue", locale)}
            </Text>
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
    maxWidth: 380,
    borderRadius: 24,
    padding: 24,
    borderWidth: 1,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.24,
    shadowRadius: 30,
    elevation: 10,
  } as ViewStyle,
  title: {
    fontSize: 23,
    fontFamily: "Comfortaa_600SemiBold",
    letterSpacing: -0.5,
    textAlign: "center",
    marginBottom: 10,
  } as TextStyle,
  message: {
    fontSize: 16,
    fontFamily: "Comfortaa_400Regular",
    lineHeight: 22,
    textAlign: "center",
  } as TextStyle,
  listBlock: {
    borderRadius: 14,
    overflow: "hidden",
    marginBottom: 20,
  } as ViewStyle,
  divider: {
    height: 0.5,
    marginHorizontal: SPACING.md,
  } as ViewStyle,
  continueButton: {
    backgroundColor: ACCENT,
    paddingVertical: 16,
    borderRadius: 100,
    alignItems: "center",
    shadowColor: ACCENT,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 15,
    elevation: 6,
  } as ViewStyle,
  continueButtonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontFamily: "Comfortaa_600SemiBold",
  } as TextStyle,
});
