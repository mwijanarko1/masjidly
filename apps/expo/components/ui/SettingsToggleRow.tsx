import React from "react";
import { View, Text, StyleSheet, Switch, Pressable } from "react-native";
import { COLORS, SPACING, FONT_SIZES } from "@/constants";

export interface SettingsToggleRowProps {
  title: string;
  subtitle?: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
}

export const SettingsToggleRow: React.FC<SettingsToggleRowProps> = ({
  title,
  subtitle,
  value,
  onValueChange,
  disabled = false,
}) => {
  return (
    <Pressable
      style={styles.container}
      onPress={() => onValueChange(!value)}
      disabled={disabled}
      accessibilityLabel={title}
      accessibilityState={{ checked: value, disabled }}
    >
      <View style={styles.textContainer}>
        <Text style={[styles.title, disabled && styles.disabledText]}>{title}</Text>
        {subtitle ? (
          <Text style={[styles.subtitle, disabled && styles.disabledText]}>{subtitle}</Text>
        ) : null}
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        disabled={disabled}
        trackColor={{ false: `${COLORS.secondary}40`, true: COLORS.accent }}
        thumbColor={COLORS.background}
        ios_backgroundColor={`${COLORS.secondary}40`}
      />
    </Pressable>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    backgroundColor: `${COLORS.background}80`,
    borderRadius: 12,
    marginBottom: SPACING.xs,
  },
  textContainer: {
    flex: 1,
    marginRight: SPACING.sm,
  },
  title: {
    fontSize: FONT_SIZES.md,
    color: COLORS.primary,
    fontWeight: "500",
  },
  subtitle: {
    fontSize: FONT_SIZES.sm,
    color: COLORS.secondary,
    marginTop: 2,
  },
  disabledText: {
    opacity: 0.5,
  },
});
