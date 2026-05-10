import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { COLORS, SPACING, FONT_SIZES } from "@/constants";
import { formatTo12Hour } from "@/lib/prayer/prayerTimesEngine";

export interface PrayerRowProps {
  name: string;
  adhan: string;
  iqamah: string;
  highlighted?: boolean;
  uses24HourTime: boolean;
}

function formatTime(time: string, uses24h: boolean): string {
  if (!time || time === "-" || time === "\u2014") return "\u2014";
  if (uses24h) return time;
  return formatTo12Hour(time);
}

export const PrayerRow: React.FC<PrayerRowProps> = ({
  name,
  adhan,
  iqamah,
  highlighted = false,
  uses24HourTime,
}) => {
  return (
    <View style={[styles.row, highlighted && styles.rowHighlighted]}>
      <Text style={[styles.cell, styles.nameCell]} numberOfLines={1}>
        {name}
      </Text>
      <Text style={[styles.cell, styles.timeCell]} numberOfLines={1}>
        {formatTime(adhan, uses24HourTime)}
      </Text>
      <Text style={[styles.cell, styles.timeCell]} numberOfLines={1}>
        {formatTime(iqamah, uses24HourTime)}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: 12,
  },
  rowHighlighted: {
    backgroundColor: `${COLORS.accent}15`,
  },
  cell: {
    fontSize: FONT_SIZES.md,
    color: COLORS.primary,
  },
  nameCell: {
    flex: 1,
    fontWeight: "600",
  },
  timeCell: {
    width: 80,
    textAlign: "center",
    color: COLORS.secondary,
  },
});
