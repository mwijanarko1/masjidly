import React from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  ImageSourcePropType,
} from "react-native";
import { Moon, Sun, CloudSun, MoonStar, Sunrise, Sunset } from "lucide-react-native";
import { COLORS, SPACING, FONT_SIZES } from "@/constants";
import { t } from "@/lib/i18n/translations";
import type { DailyPrayerTimes, DailyIqamahTimes } from "@/types/prayer";
import { formatTo12Hour } from "@/lib/prayer/prayerTimesEngine";

export type PrayerName = "Fajr" | "Sunrise" | "Dhuhr" | "Asr" | "Maghrib" | "Isha";

interface PrayerCarouselProps {
  prayers: PrayerName[];
  selectedPrayer: PrayerName;
  onSelectPrayer: (prayer: PrayerName) => void;
  prayerTimes: DailyPrayerTimes | null;
  iqamahTimes: DailyIqamahTimes | null;
  uses24HourTime: boolean;
  languageCode: "en" | "ar" | "ur";
}

const prayerImages: Record<PrayerName, ImageSourcePropType> = {
  Fajr: require("@/assets/prayers/fajr.png"),
  Sunrise: require("@/assets/prayers/fajr.png"),
  Dhuhr: require("@/assets/prayers/dhuhr.png"),
  Asr: require("@/assets/prayers/asr.png"),
  Maghrib: require("@/assets/prayers/maghrib.png"),
  Isha: require("@/assets/prayers/isha.png"),
};

function prayerIcon(name: PrayerName, color: string, size: number) {
  switch (name) {
    case "Fajr":
      return <Moon size={size} color={color} />;
    case "Sunrise":
      return <Sunrise size={size} color={color} />;
    case "Dhuhr":
      return <CloudSun size={size} color={color} />;
    case "Asr":
      return <Sun size={size} color={color} />;
    case "Maghrib":
      return <Sunset size={size} color={color} />;
    case "Isha":
      return <MoonStar size={size} color={color} />;
  }
}

function prayerTimeKey(name: PrayerName): keyof DailyPrayerTimes {
  switch (name) {
    case "Fajr":
      return "fajr";
    case "Sunrise":
      return "sunrise";
    case "Dhuhr":
      return "dhuhr";
    case "Asr":
      return "asr";
    case "Maghrib":
      return "maghrib";
    case "Isha":
      return "isha";
  }
}

function translatePrayerName(name: PrayerName, lang: "en" | "ar" | "ur"): string {
  const keyMap: Record<PrayerName, Parameters<typeof t>[0]> = {
    Fajr: "prayer.fajr",
    Sunrise: "prayer.sunrise",
    Dhuhr: "prayer.dhuhr",
    Asr: "prayer.asr",
    Maghrib: "prayer.maghrib",
    Isha: "prayer.isha",
  };
  return t(keyMap[name], lang);
}

function formatTime(time: string, uses24h: boolean): string {
  if (uses24h) return time;
  return formatTo12Hour(time);
}

export const PrayerCarousel: React.FC<PrayerCarouselProps> = ({
  prayers,
  selectedPrayer,
  onSelectPrayer,
  prayerTimes,
  uses24HourTime,
  languageCode,
}) => {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.container}
    >
      {prayers.map((prayer) => {
        const isSelected = prayer === selectedPrayer;
        const time = prayerTimes ? prayerTimes[prayerTimeKey(prayer)] : "";
        return (
          <Pressable
            key={prayer}
            onPress={() => onSelectPrayer(prayer)}
            style={[styles.card, isSelected && styles.cardSelected]}
            accessibilityRole="button"
            accessibilityLabel={translatePrayerName(prayer, languageCode)}
            accessibilityState={{ selected: isSelected }}
          >
            <View style={styles.iconWrapper}>
              {prayerIcon(
                prayer,
                isSelected ? COLORS.background : COLORS.accent,
                24
              )}
            </View>
            <Text
              style={[
                styles.name,
                isSelected && styles.textSelected,
              ]}
            >
              {translatePrayerName(prayer, languageCode)}
            </Text>
            {time ? (
              <Text
                style={[
                  styles.time,
                  isSelected && styles.textSelected,
                ]}
              >
                {formatTime(time, uses24HourTime)}
              </Text>
            ) : null}
          </Pressable>
        );
      })}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: SPACING.md,
    gap: SPACING.sm,
  },
  card: {
    width: 80,
    height: 110,
    borderRadius: 24,
    backgroundColor: COLORS.background,
    justifyContent: "center",
    alignItems: "center",
    marginRight: SPACING.sm,
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  cardSelected: {
    backgroundColor: COLORS.accent,
  },
  iconWrapper: {
    marginBottom: SPACING.xs,
  },
  name: {
    fontSize: FONT_SIZES.xs,
    fontWeight: "600",
    color: COLORS.primary,
    textAlign: "center",
  },
  time: {
    fontSize: FONT_SIZES.xs,
    color: COLORS.secondary,
    marginTop: 2,
  },
  textSelected: {
    color: COLORS.background,
  },
});
