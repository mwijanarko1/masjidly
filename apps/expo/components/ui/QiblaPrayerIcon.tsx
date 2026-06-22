import React, { useMemo } from "react";
import { View, Text, Animated } from "react-native";
import Svg, { Circle, Path } from "react-native-svg";
import { PrayerSunPhaseIcon } from "./PrayerSunPhaseIcon";
import type { TimeTheme } from "@/lib/design/themes";
import { getIconColor } from "@/lib/design/themes";

export interface QiblaPrayerIconProps {
  theme: TimeTheme;
  rotationDegrees?: number | null;
  /**
   * Animated.Value driven by useQiblaDirection.
   * When provided, the pointer uses native-driver animation (matching iOS smoothness).
   */
  animatedRotation?: Animated.Value;
  size?: number;
  showCountdown?: boolean;
  countdownLabel?: string;
  countdownTime?: string;
  /** Elapsed fraction 0–1 for the countdown progress ring only. */
  countdownProgress?: number;
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
  return (
    <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <Path
        d={`M ${size / 2} 0 L ${size} ${size} L 0 ${size} Z`}
        fill={color}
      />
    </Svg>
  );
};

export const QiblaPrayerIcon: React.FC<QiblaPrayerIconProps> = React.memo(({
  theme,
  rotationDegrees,
  animatedRotation,
  size = 120,
  showCountdown = false,
  countdownLabel = "",
  countdownTime = "",
  countdownProgress = 0,
}) => {
  const color = getIconColor(theme);
  const scale = size / FRAME_SIZE;
  const offset = getQiblaRingContentOffset(theme);

  const rotateInterpolation = useMemo(() => {
    if (!animatedRotation) return null;
    // 1:1 degree mapping — stable for unbounded continuous rotation values.
    return animatedRotation.interpolate({
      inputRange: [0, 1],
      outputRange: ["0deg", "1deg"],
      extrapolate: "extend",
    });
  }, [animatedRotation]);

  const prog = Math.min(1, Math.max(0, countdownProgress));
  const ringPx = 112 * scale;
  const strokeW = 2 * scale;
  const r = ringPx / 2 - strokeW / 2;
  const circumference = 2 * Math.PI * r;
  const dashOffset = circumference * (1 - prog);

  const outerOpacity = showCountdown ? "6A" : "3D";
  const outerBorderW = showCountdown ? 1.15 : 1;

  const pointerDeg = rotationDegrees ?? 0;
  const hasQiblaPointer = animatedRotation != null || rotationDegrees != null;
  const showPointer = hasQiblaPointer;

  return (
    <View
      style={{
        width: size,
        height: size,
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      {showCountdown ? (
        <Svg
          width={ringPx}
          height={ringPx}
          style={{ position: "absolute" }}
          pointerEvents="none"
        >
          <Circle
            cx={ringPx / 2}
            cy={ringPx / 2}
            r={r}
            stroke={color + "61"}
            strokeWidth={strokeW}
            fill="none"
            strokeDasharray={`${circumference} ${circumference}`}
            strokeDashoffset={dashOffset}
            strokeLinecap="round"
            transform={`rotate(-90 ${ringPx / 2} ${ringPx / 2})`}
          />
        </Svg>
      ) : null}

      <View
        style={{
          position: "absolute",
          width: 112 * scale,
          height: 112 * scale,
          borderRadius: (112 * scale) / 2,
          borderWidth: outerBorderW,
          borderColor: color + outerOpacity,
        }}
      />
      <View
        style={{
          position: "absolute",
          width: 106 * scale,
          height: 106 * scale,
          borderRadius: (106 * scale) / 2,
          borderWidth: 0.8,
          borderColor: color + "14",
        }}
      />

      {showCountdown ? (
        <View
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            justifyContent: "center",
            alignItems: "center",
          }}
          pointerEvents="none"
        >
          <View style={{ alignItems: "center", width: 78 * scale, paddingHorizontal: 4 }}>
            <Text
              style={{
                width: "100%",
                fontSize: 9 * scale,
                fontWeight: "600",
                letterSpacing: 1.4,
                color: color + "85",
                textTransform: "uppercase",
                textAlign: "center",
              }}
              numberOfLines={1}
              adjustsFontSizeToFit
              minimumFontScale={0.7}
            >
              {countdownLabel}
            </Text>
            <Text
              style={{
                width: "100%",
                marginTop: 2 * scale,
                fontSize: 20 * scale,
                fontWeight: "500",
                fontVariant: ["tabular-nums"],
                color: color + "EB",
                textAlign: "center",
              }}
              numberOfLines={1}
              adjustsFontSizeToFit
              minimumFontScale={0.55}
            >
              {countdownTime}
            </Text>
          </View>
        </View>
      ) : (
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
      )}

      {showPointer ? (
        <Animated.View
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            justifyContent: "flex-start",
            alignItems: "center",
            transform: [{ rotate: rotateInterpolation ?? `${pointerDeg}deg` }],
          }}
        >
          <View style={{ marginTop: -10 * scale }}>
            <QiblaPointerTriangle color={color} size={12 * scale} />
          </View>
        </Animated.View>
      ) : null}
    </View>
  );
});
