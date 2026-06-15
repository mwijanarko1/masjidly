import React from "react";
import {
  View,
  Text,
  StyleSheet,
  Switch,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { SPACING, FONT_SIZES } from "@/constants";

export interface SettingsToggleRowProps {
  title: string;
  subtitle?: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
  textColor: string;
}

export const SettingsToggleRow: React.FC<SettingsToggleRowProps> = React.memo(({
  title,
  subtitle,
  value,
  onValueChange,
  disabled = false,
  textColor,
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
        <Text
          style={[
            styles.title,
            disabled && styles.disabledText,
            { color: textColor, fontFamily: "Comfortaa_400Regular" },
          ]}
        >
          {title}
        </Text>
        {subtitle ? (
          <Text
            style={[
              styles.subtitle,
              disabled && styles.disabledText,
              { color: textColor + "8C", fontFamily: "Comfortaa_400Regular" },
            ]}
          >
            {subtitle}
          </Text>
        ) : null}
      </View>
      <Switch
        value={value}
        onValueChange={onValueChange}
        disabled={disabled}
        trackColor={{ false: `${textColor}40`, true: "#47A6FF" }}
        thumbColor={value ? "#FFFFFF" : "#F4F3F4"}
        ios_backgroundColor={`${textColor}30`}
      />
    </Pressable>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    minHeight: 44,
  },
  textContainer: {
    flex: 1,
    flexShrink: 1,
    marginRight: SPACING.sm,
  },
  title: {
    fontSize: FONT_SIZES.md,
    flexShrink: 1,
  },
  subtitle: {
    fontSize: FONT_SIZES.sm,
    marginTop: 2,
  },
  disabledText: {
    opacity: 0.5,
  },
});
