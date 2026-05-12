import React from "react";
import { View } from "react-native";
import Svg, { Circle, Path } from "react-native-svg";
import { PrayerSunPhaseIcon } from "./PrayerSunPhaseIcon";
import type { TimeTheme } from "@/lib/design/themes";
import { getIconColor } from "@/lib/design/themes";

interface QiblaPrayerIconProps {
  theme: TimeTheme;
  rotationDegrees?: number | null;
  size?: number;
}

const FRAME_SIZE = 120;

function getQiblaRingContentOffset(theme: TimeTheme): { x: number; y: number } {
  const baseY = -6;
  const down5Percent = FRAME_SIZE * 0.05;
  switch (theme) {
    case "fajr":
    case "dhuhr":
    case "asr":
    case "isha":
      return { x: 0, y: baseY + down5Percent };
    case "sunrise":
    case "maghrib":
    case "tahajjud":
      return { x: 0, y: baseY };
    default:
      return { x: 0, y: baseY };
  }
}

const QiblaPointerTriangle: React.FC<{ color: string; size: number }> = ({
  color,
  size,
}) => {
  // Triangle pointing outward from the circle center (tip at top of SVG).
  // Positioned so the base sits on the outer ring, tip extends outward — iOS style.
  return (
    <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <Path
        d={`M ${size / 2} 0 L ${size} ${size} L 0 ${size} Z`}
        fill={color}
      />
    </Svg>
  );
};

export const QiblaPrayerIcon: React.FC<QiblaPrayerIconProps> = ({
  theme,
  rotationDegrees,
  size = 120,
}) => {
  const color = getIconColor(theme);
  const scale = size / FRAME_SIZE;
  const offset = getQiblaRingContentOffset(theme);

  return (
    <View
      style={{
        width: size,
        height: size,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      {/* Outer ring */}
      <View
        style={{
          position: "absolute",
          width: 112 * scale,
          height: 112 * scale,
          borderRadius: (112 * scale) / 2,
          borderWidth: 1,
          borderColor: color + "3D", // ~0.24 opacity
        }}
      />
      {/* Inner ring */}
      <View
        style={{
          position: "absolute",
          width: 106 * scale,
          height: 106 * scale,
          borderRadius: (106 * scale) / 2,
          borderWidth: 0.8,
          borderColor: color + "14", // ~0.08 opacity
        }}
      />
      {/* Sun phase icon with offset */}
      <View
        style={{
          transform: [
            { translateX: offset.x * scale },
            { translateY: offset.y * scale },
          ],
        }}
      >
        <PrayerSunPhaseIcon theme={theme} size={100 * scale} />
      </View>
      {/* Qibla pointer — sits outside the compass ring, tip extends outward (iOS style) */}
      {rotationDegrees != null && (
        <View
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            justifyContent: "flex-start",
            alignItems: "center",
            transform: [{ rotate: `${rotationDegrees}deg` }],
          }}
        >
          {/* Ring edge at y=4 (=(FRAME_SIZE−ringSize)/2). Triangle 12px tall, tip at top.
              Base on ring y=4, tip extends outward to y=−8. */}
          <View style={{ marginTop: -8 * scale }}>
            <QiblaPointerTriangle color={color} size={12 * scale} />
          </View>
        </View>
      )}
    </View>
  );
};
