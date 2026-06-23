import React, { useEffect } from "react";
import { BackHandler, StyleSheet, View } from "react-native";
import { useAppOverlayStore } from "@/store/appOverlay";
import { SettingsScreen } from "@/app/settings";
import { TimetableScreen } from "@/app/timetable";

export default function AppOverlays() {
  const overlay = useAppOverlayStore((s) => s.overlay);
  const close = useAppOverlayStore((s) => s.close);

  useEffect(() => {
    if (!overlay) return;
    const subscription = BackHandler.addEventListener("hardwareBackPress", () => {
      close();
      return true;
    });
    return () => subscription.remove();
  }, [overlay, close]);

  if (!overlay) return null;

  return (
    <View style={styles.overlay} pointerEvents="box-none">
      {overlay.type === "settings" ? (
        <SettingsScreen onClose={close} theme={overlay.params.theme} />
      ) : (
        <TimetableScreen
          onClose={close}
          theme={overlay.params.theme}
          mosqueName={overlay.params.mosqueName}
          mosqueSlug={overlay.params.mosqueSlug}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 100,
    elevation: 100,
  },
});
