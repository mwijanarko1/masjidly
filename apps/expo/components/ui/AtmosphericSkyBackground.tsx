import React, { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet } from "react-native";
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
function SkyLayers({ sky, variant, diagonalBase }: Required<Props>) {
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

export const AtmosphericSkyBackground = React.memo(function AtmosphericSkyBackground({
  sky,
  variant = "home",
  diagonalBase = false,
}: Props) {
  const [currentSky, setCurrentSky] = useState(sky);
  const [previousSky, setPreviousSky] = useState<SkyTheme | null>(null);
  const fade = useRef(new Animated.Value(1)).current;
  const animation = useRef<Animated.CompositeAnimation | null>(null);

  useEffect(() => {
    if (sky === currentSky) return;
    animation.current?.stop();
    setPreviousSky(currentSky);
    setCurrentSky(sky);
    fade.setValue(0);
    animation.current = Animated.timing(fade, {
      toValue: 1,
      duration: 500,
      useNativeDriver: true,
    });
    animation.current.start(({ finished }) => {
      if (finished) setPreviousSky(null);
    });
  }, [sky, currentSky, fade]);

  return (
    <>
      {previousSky ? (
        <Animated.View
          style={[
            StyleSheet.absoluteFill,
            { opacity: fade.interpolate({ inputRange: [0, 1], outputRange: [1, 0] }) },
          ]}
        >
          <SkyLayers sky={previousSky} variant={variant} diagonalBase={diagonalBase} />
        </Animated.View>
      ) : null}

      <Animated.View
        style={[StyleSheet.absoluteFill, { opacity: previousSky ? fade : 1 }]}
      >
        <SkyLayers sky={currentSky} variant={variant} diagonalBase={diagonalBase} />
      </Animated.View>
    </>
  );
});
