import React, { useCallback, useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  Modal,
  Platform,
  FlatList,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { SafeAreaView } from "react-native-safe-area-context";
import { ChevronDown, Check } from "lucide-react-native";
import { SPACING, FONT_SIZES } from "@/constants";

export type MenuOption<T> = { label: string; value: T; accessory?: React.ReactNode };

function optionKey<T>(value: T): string {
  if (value === null || value === undefined) return "none";
  return String(value);
}

function sameValue<T>(a: T, b: T): boolean {
  return a === b;
}

type Props<T> = {
  label: string;
  displayValue: string;
  value: T;
  options: MenuOption<T>[];
  onSelect: (value: T) => void;
  textColor: string;
  /** Optional small visual shown before the selected value (e.g. gradient swatch). */
  valueAccessory?: React.ReactNode;
  /** Dark timetable-style chrome (light text on sky): use dark grouped sheet like iOS in dark mode. */
  invertSheet?: boolean;
  sheetTitle?: string;
  testID?: string;
  /** Optional fixed label width for stacked picker groups, keeping values/chevrons aligned row-to-row. */
  labelWidth?: number;
};

/**
 * iOS-style settings row: label + current value + chevron; opens a sheet to pick an option (Swift `PickerStyle(.menu)` parity).
 */
export function SettingsMenuPickerRow<T>({
  label,
  displayValue,
  value,
  options,
  onSelect,
  textColor,
  valueAccessory,
  invertSheet = false,
  sheetTitle,
  testID,
  labelWidth,
}: Props<T>) {
  const [open, setOpen] = useState(false);
  const title = sheetTitle ?? label;
  const sheetBg = invertSheet ? "#1C1C1E" : "#F2F2F7";
  const sheetPrimary = invertSheet ? "#FFFFFF" : "#000000";
  const sheetRowBg = invertSheet ? "#2C2C2E" : "#FFFFFF";
  const sheetBorder = invertSheet ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.12)";

  const onPick = useCallback(
    (v: T) => {
      onSelect(v);
      setOpen(false);
    },
    [onSelect]
  );

  const rowA11y = useMemo(
    () => `${label}, ${displayValue}. Opens list to change.`,
    [label, displayValue]
  );

  return (
    <>
      <Pressable
        testID={testID}
        accessibilityRole="button"
        accessibilityLabel={rowA11y}
        onPress={() => setOpen(true)}
        style={({ pressed }) => [
          styles.row,
          pressed && { opacity: 0.85 },
        ]}
      >
        <Text
          style={[
            styles.label,
            { color: textColor, fontFamily: "Comfortaa_400Regular" },
            labelWidth !== undefined && { width: labelWidth, flexShrink: 0 },
          ]}
          numberOfLines={1}
        >
          {label}
        </Text>
        <View style={styles.valueWrap}>
          {valueAccessory}
          <Text
            style={[styles.value, { color: textColor, fontFamily: "Comfortaa_400Regular" }]}
            numberOfLines={1}
          >
            {displayValue}
          </Text>
          <ChevronDown size={18} color={textColor} strokeWidth={2} />
        </View>
      </Pressable>

      <Modal
        visible={open}
        animationType="slide"
        presentationStyle={Platform.OS === "ios" ? "pageSheet" : "fullScreen"}
        onRequestClose={() => setOpen(false)}
      >
        <SafeAreaView style={[styles.sheetRoot, { backgroundColor: sheetBg }]}>
          <View style={[styles.sheetHeader, { borderBottomColor: sheetBorder }]}>
            <Text
              style={[styles.sheetTitle, { color: sheetPrimary }]}
              numberOfLines={1}
            >
              {title}
            </Text>
            <Pressable
              onPress={() => setOpen(false)}
              accessibilityRole="button"
              accessibilityLabel="Done"
              hitSlop={12}
            >
              <Text style={styles.doneText}>Done</Text>
            </Pressable>
          </View>
          <FlatList
            data={options}
            keyExtractor={(item) => optionKey(item.value)}
            keyboardShouldPersistTaps="handled"
            style={styles.listScroll}
            contentContainerStyle={styles.listContent}
            renderItem={({ item }) => {
              const selected = sameValue(item.value, value);
              return (
                <Pressable
                  onPress={() => onPick(item.value)}
                  style={({ pressed }) => [
                    styles.optionRow,
                    { backgroundColor: sheetRowBg },
                    pressed && { opacity: 0.88 },
                  ]}
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                >
                  {item.accessory ? (
                    <View style={styles.optionAccessory}>{item.accessory}</View>
                  ) : null}
                  <Text
                    style={[
                      styles.optionLabel,
                      {
                        color: sheetPrimary,
                        fontFamily: selected ? "Comfortaa_600SemiBold" : "Comfortaa_400Regular",
                      },
                    ]}
                    numberOfLines={2}
                  >
                    {item.label}
                  </Text>
                  {selected ? <Check size={20} color="#47A6FF" strokeWidth={2.5} /> : null}
                </Pressable>
              );
            }}
          />
        </SafeAreaView>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    minHeight: 44,
    gap: 12,
  },
  label: {
    fontSize: FONT_SIZES.md,
    flexShrink: 1,
    marginRight: 4,
  },
  valueWrap: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "flex-end",
    gap: 6,
  },
  value: {
    fontSize: FONT_SIZES.md,
    textAlign: "right",
    flexShrink: 1,
  },
  sheetRoot: {
    flex: 1,
  },
  sheetHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  sheetTitle: {
    fontSize: 17,
    fontFamily: "Comfortaa_600SemiBold",
    flex: 1,
    marginRight: SPACING.sm,
  },
  doneText: {
    fontSize: 17,
    fontFamily: "Comfortaa_600SemiBold",
    color: "#47A6FF",
  },
  listContent: {
    paddingVertical: SPACING.sm,
  },
  listScroll: {
    flex: 1,
  },
  optionRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 14,
    paddingHorizontal: SPACING.md,
    marginHorizontal: SPACING.md,
    marginVertical: 4,
    borderRadius: 12,
    backgroundColor: "#FFFFFF",
  },
  optionAccessory: {
    marginRight: 10,
  },
  optionLabel: {
    fontSize: 17,
    flex: 1,
    marginRight: SPACING.sm,
  },
});
