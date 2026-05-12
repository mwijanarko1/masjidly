import React from "react";
import { StyleSheet } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import type { SkyTheme } from "@/lib/design/themes";
import {
  densifyGradientStops,
  horizonGlowLinearGradient,
} from "@/lib/design/gradientColors";

type Variant = "home" | "simple";

type Props = {
  sky: SkyTheme;
  /** `home`: base + horizon glow + light wash (matches iOS Home). `simple`: densified base only. */
  variant?: Variant;
  /** iOS Timetable uses topLeading → bottomTrailing */
  diagonalBase?: boolean;
};

function asGradientTuple(colors: string[]): [string, string, ...string[]] {
  const [a, b, ...rest] = colors;
  return [a, b, ...rest] as [string, string, ...string[]];
}

function asLocationsTuple(
  locations: number[]
): [number, number, ...number[]] {
  const [a, b, ...rest] = locations;
  return [a, b, ...rest] as [number, number, ...number[]];
}

/**
 * Atmospheric sky stack aligned with iOS `HomeView.backgroundLayer`: densified vertical (or diagonal)
 * base gradient, soft horizon glow, subtle top wash.
 */
export function AtmosphericSkyBackground({
  sky,
  variant = "home",
  diagonalBase = false,
}: Props) {
  const base = densifyGradientStops(sky.baseColors, 2);
  const glowBaseAlpha = sky.glowBaseAlpha ?? 1;
  const horizon =
    variant === "home" && sky.glowColor
      ? horizonGlowLinearGradient(sky.glowColor, glowBaseAlpha)
      : null;

  return (
    <>
      <LinearGradient
        colors={asGradientTuple(base.colors)}
        locations={asLocationsTuple(base.locations)}
        dither
        start={diagonalBase ? { x: 0, y: 0 } : { x: 0, y: 0 }}
        end={diagonalBase ? { x: 1, y: 1 } : { x: 0, y: 1 }}
        style={StyleSheet.absoluteFill}
      />

      {horizon ? (
        <LinearGradient
          colors={asGradientTuple(horizon.colors)}
          locations={asLocationsTuple(horizon.locations)}
          dither
          start={{ x: 0.5, y: 1 }}
          end={{ x: 0.5, y: 0.18 }}
          style={StyleSheet.absoluteFill}
          pointerEvents="none"
        />
      ) : null}

      {variant === "home" ? (
        <LinearGradient
          colors={[
            "rgba(255,255,255,0.07)",
            "rgba(255,255,255,0.03)",
            "rgba(255,255,255,0.01)",
            "transparent",
          ]}
          locations={[0, 0.22, 0.48, 1]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={StyleSheet.absoluteFill}
          pointerEvents="none"
        />
      ) : null}
    </>
  );
}
