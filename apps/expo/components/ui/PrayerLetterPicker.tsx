import React from "react";
import {
  View,
  Text,
  StyleSheet,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { useAppLanguage, getFontScale } from "@/lib/i18n/language";
import { t, type TranslationKey } from "@/lib/i18n/translations";
import { TutorialHighlight } from "@/components/onboarding/CoachMarkCard";
import type { TimeTheme } from "@/lib/design/themes";
import { getTextColor } from "@/lib/design/themes";

export type PrayerName = "Fajr" | "Sunrise" | "Dhuhr" | "Jummah" | "Asr" | "Maghrib" | "Isha";


interface PrayerLetterPickerProps {
  prayers: PrayerName[];
  selectedPrayer: PrayerName;
  onSelectPrayer: (prayer: PrayerName) => void;
  theme: TimeTheme;
  /** When true, wraps the full shortcut row in a pulsing tutorial highlight. */
  highlightAllPrayers?: boolean;
}

const PRAYER_KEYS: Record<PrayerName, TranslationKey> = {
  Fajr: "prayer.fajr",
  Sunrise: "prayer.sunrise",
  Dhuhr: "prayer.dhuhr",
  Jummah: "prayer.jummah",
  Asr: "prayer.asr",
  Maghrib: "prayer.maghrib",
  Isha: "prayer.isha",
};

export const PrayerLetterPicker: React.FC<PrayerLetterPickerProps> = React.memo(({
  prayers,
  selectedPrayer,
  onSelectPrayer,
  theme,
  highlightAllPrayers,
}) => {
  const textColor = getTextColor(theme);
  const langCode = useAppLanguage();
  const fontScale = getFontScale(langCode);

  const getPrayerLetter = (prayer: PrayerName): string => {
    const key = PRAYER_KEYS[prayer];
    const localized = t(key, langCode);
    if (!localized) return prayer[0];

    let clean = localized;
    if (clean.startsWith("ال")) {
      clean = clean.substring(2);
    }
    return clean.charAt(0) || prayer[0];
  };

  return (
    <View style={styles.container}>
      <TutorialHighlight
        isHighlighted={highlightAllPrayers === true}
        width={228}
        height={52}
        color={textColor}
      >
        <View style={styles.row}>
          {prayers.map((prayer) => {
            const isSelected = prayer === selectedPrayer;
            return (
              <Pressable
                key={prayer}
                onPress={() => onSelectPrayer(prayer)}
                style={styles.button}
                accessibilityRole="button"
                accessibilityState={{ selected: isSelected }}
                accessibilityLabel={prayer}
              >
                <Text
                  style={[
                    styles.letter,
                    {
                      color: textColor + (isSelected ? "FF" : "61"),
                      fontFamily: isSelected
                        ? "Comfortaa_600SemiBold"
                        : "Comfortaa_400Regular",
                      fontSize: 20 * fontScale,
                    },
                  ]}
                >
                  {getPrayerLetter(prayer)}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </TutorialHighlight>
    </View>
  );
});


const styles = StyleSheet.create({
  container: {
    width: "100%",
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 20,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 14,
  },
  button: {
    minWidth: 28,
    minHeight: 36,
    justifyContent: "center",
    alignItems: "center",
  },
  letter: {
    fontSize: 20,
  },
});
