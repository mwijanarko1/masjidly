import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { SPACING } from "@/constants";
import { formatPrayerClockForDisplay } from "@/lib/prayer/prayerTimesEngine";

import { getFontScale, type AppLanguage } from "@/lib/i18n/language";

export interface PrayerRowProps {
  name: string;
  adhan: string;
  iqamah: string;
  isNext?: boolean;
  isPast?: boolean;
  uses24HourTime: boolean;
  locale: string;
  textColor: string;
}

function formatTime(time: string, uses24h: boolean, locale: string): string {
  if (!time || time === "-" || time === "\u2014") return "-";
  return formatPrayerClockForDisplay(time, uses24h, locale);
}

export const PrayerRow: React.FC<PrayerRowProps> = React.memo(({
  name,
  adhan,
  iqamah,
  isNext = false,
  isPast = false,
  uses24HourTime,
  locale,
  textColor,
}) => {
  const opacity = isPast ? 0.35 : 1.0;
  const nameWeight = isNext ? "600" : "400";
  const iqamahWeight = isNext ? "700" : "500";
  const fontScale = getFontScale(locale as AppLanguage);

  // Shared row font size — uniform for all rows/dates; time column accommodates this size.
  const ROW_FONT_SIZE = 18;

  return (
    <View
      style={[
        styles.row,
        isNext && {
          backgroundColor: textColor + "14", // ~0.08 opacity
        },
      ]}
    >
      <Text
        style={[
          styles.cell,
          styles.nameCell,
          {
            color: textColor + Math.round(opacity * 255).toString(16).padStart(2, "0"),
            fontFamily: isNext ? "Comfortaa_600SemiBold" : "Comfortaa_400Regular",
            fontSize: ROW_FONT_SIZE * fontScale,
          },
        ]}
        numberOfLines={1}
      >
        {name}
      </Text>
      <Text
        style={[
          styles.cell,
          styles.timeCell,
          {
            color: textColor + Math.round(opacity * 0.75 * 255).toString(16).padStart(2, "0"),
            fontFamily: isNext ? "Comfortaa_600SemiBold" : "Comfortaa_400Regular",
            fontSize: ROW_FONT_SIZE * fontScale,
          },
        ]}
        numberOfLines={1}
        {...(!isNext && { adjustsFontSizeToFit: true as const, minimumFontScale: 0.78 })}
      >
        {formatTime(adhan, uses24HourTime, locale)}
      </Text>
      <Text
        style={[
          styles.cell,
          styles.timeCell,
          {
            color: textColor + Math.round(opacity * 255).toString(16).padStart(2, "0"),
            fontFamily: iqamahWeight === "700" ? "Comfortaa_700Bold" : "Comfortaa_500Medium",
            fontSize: ROW_FONT_SIZE * fontScale,
          },
        ]}
        numberOfLines={1}
        {...(!isNext && { adjustsFontSizeToFit: true as const, minimumFontScale: 0.78 })}
      >
        {formatTime(iqamah, uses24HourTime, locale)}
      </Text>
    </View>
  );
});


const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderRadius: 16,
  },
  cell: {
    fontSize: 18,
  },
  nameCell: {
    flex: 1,
  },
  timeCell: {
    width: 105,
    maxWidth: 105,
    textAlign: "right",
    fontVariant: ["tabular-nums"],
  },
});
