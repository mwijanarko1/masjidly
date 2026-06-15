import * as Haptics from "expo-haptics";
import {
  Pressable as RNPressable,
  TouchableOpacity as RNTouchableOpacity,
  type GestureResponderEvent,
  type PressableProps,
  type TouchableOpacityProps,
} from "react-native";

function triggerSelectionHaptic() {
  void Haptics.selectionAsync().catch(() => {
    // Haptics are best-effort; ignore unsupported devices/platform failures.
  });
}

function handleHapticInteraction(
  event: GestureResponderEvent,
  handler?: (event: GestureResponderEvent) => void,
) {
  triggerSelectionHaptic();
  handler?.(event);
}

export function HapticPressable({ onPress, onLongPress, ...props }: PressableProps) {
  return (
    <RNPressable
      {...props}
      onPress={onPress ? (event) => handleHapticInteraction(event, onPress) : undefined}
      onLongPress={onLongPress ? (event) => handleHapticInteraction(event, onLongPress) : undefined}
    />
  );
}

export function HapticTouchableOpacity({ onPress, onLongPress, ...props }: TouchableOpacityProps) {
  return (
    <RNTouchableOpacity
      {...props}
      onPress={onPress ? (event) => handleHapticInteraction(event, onPress) : undefined}
      onLongPress={onLongPress ? (event) => handleHapticInteraction(event, onLongPress) : undefined}
    />
  );
}

export { triggerSelectionHaptic };
