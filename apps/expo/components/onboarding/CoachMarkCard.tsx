import React, { useEffect, useRef, useMemo } from "react";
import {
  View,
  Text,
  StyleSheet,
  Animated,
  type ViewStyle,
  type TextStyle,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { SPACING, FONT_SIZES } from "@/constants";
import type { TimeTheme } from "@/lib/design/themes";
import { ACCENT } from "@/lib/design/themes";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type CoachMarkVariant =
  | "belowTopChrome"
  | "aboveShortcutRow"
  | "belowQiblaIcon"
  | "belowQiblaIconLower"
  | "floatingBottom";

interface CoachMarkCardProps {
  title: string;
  message: string;
  variant: CoachMarkVariant;
  primaryButtonTitle?: string;
  onPrimaryButton?: () => void;
  secondaryButtonTitle?: string;
  onSecondaryButton?: () => void;
  accessibilityIdentifier?: string;
  secondaryAccessibilityIdentifier?: string;
  theme: TimeTheme;
  textColor: string;
  usesLightForeground: boolean;
  /** When true (default), the dimming backdrop blocks taps on UI behind the coach mark.
   *  Set to false to let users interact with elements behind the card (e.g. tapping the
   *  Qibla circle during countdown onboarding). The Continue button remains tappable. */
  blocksBackgroundInteractions?: boolean;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function glassBgColor(textColor: string, usesLightForeground: boolean): string {
  if (usesLightForeground) {
    // Dark themes: dark solid
    return "rgb(10, 10, 30)";
  }
  // Light themes: white solid
  return "rgb(255, 255, 255)";
}

function glassBorderColor(textColor: string, usesLightForeground: boolean): string {
  if (usesLightForeground) {
    return "rgba(255, 255, 255, 0.15)";
  }
  return "rgba(240, 240, 240, 0.6)";
}

function messageColor(textColor: string): string {
  // ~82% opacity like the iOS version
  return textColor + "D1";
}

// ---------------------------------------------------------------------------
// Highlight (pulsing ring) component
// ---------------------------------------------------------------------------

interface TutorialHighlightProps {
  isHighlighted: boolean;
  size?: number;
  width?: number;
  height?: number;
  color?: string;
  style?: ViewStyle;
  children: React.ReactNode;
}

export function TutorialHighlight({
  isHighlighted,
  size = 44,
  width,
  height,
  color = "#FFFFFF",
  style,
  children,
}: TutorialHighlightProps) {
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const ringOpacity = useRef(new Animated.Value(isHighlighted ? 0.3 : 0)).current;

  useEffect(() => {
    if (isHighlighted) {
      ringOpacity.setValue(0.3);
      Animated.loop(
        Animated.sequence([
          Animated.parallel([
            Animated.spring(pulseAnim, {
              toValue: 1.08,
              friction: 6,
              tension: 80,
              useNativeDriver: true,
            }),
            Animated.timing(ringOpacity, {
              toValue: 0.0,
              duration: 1200,
              useNativeDriver: true,
            }),
          ]),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 400,
            useNativeDriver: true,
          }),
          Animated.timing(ringOpacity, {
            toValue: 0.3,
            duration: 200,
            useNativeDriver: true,
          }),
        ])
      ).start();
    } else {
      ringOpacity.setValue(0);
      pulseAnim.setValue(1);
    }

    return () => {
      pulseAnim.setValue(1);
    };
  }, [isHighlighted, pulseAnim, ringOpacity]);

  const ringWidth = (width ?? size) + 12;
  const ringHeight = (height ?? size) + 12;

  return (
    <View
      style={[
        style,
        {
          width: ringWidth,
          height: ringHeight,
          justifyContent: "center",
          alignItems: "center",
        },
      ]}
    >
      {isHighlighted ? (
        <Animated.View
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            width: ringWidth,
            height: ringHeight,
            borderRadius: Math.min(ringWidth, ringHeight) / 2,
            borderWidth: 1.5,
            borderColor: color,
            opacity: ringOpacity,
            shadowColor: color,
            shadowOffset: { width: 0, height: 0 },
            shadowOpacity: 0.3,
            shadowRadius: 8,
            elevation: 5,
          }}
          pointerEvents="none"
        />
      ) : null}
      <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
        {children}
      </Animated.View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Glass card content
// ---------------------------------------------------------------------------

function GlassCard({
  title,
  message,
  primaryButtonTitle,
  onPrimaryButton,
  secondaryButtonTitle,
  onSecondaryButton,
  accessibilityIdentifier,
  secondaryAccessibilityIdentifier,
  textColor,
  usesLightForeground,
}: {
  title: string;
  message: string;
  primaryButtonTitle?: string;
  onPrimaryButton?: () => void;
  secondaryButtonTitle?: string;
  onSecondaryButton?: () => void;
  accessibilityIdentifier?: string;
  secondaryAccessibilityIdentifier?: string;
  textColor: string;
  usesLightForeground: boolean;
}) {
  return (
    <View
      style={[
        styles.glassCard,
        {
          backgroundColor: glassBgColor(textColor, usesLightForeground),
          borderColor: glassBorderColor(textColor, usesLightForeground),
          shadowColor: usesLightForeground ? "rgba(0,0,0,0.25)" : "rgba(0,0,0,0.10)",
        },
      ]}
    >
      <Text style={[styles.cardTitle, { color: textColor }]}>{title}</Text>
      <Text style={[styles.cardMessage, { color: messageColor(textColor) }]}>
        {message}
      </Text>

      {primaryButtonTitle && onPrimaryButton ? (
        <Pressable
          style={styles.primaryButton}
          onPress={onPrimaryButton}
          accessibilityRole="button"
          accessibilityLabel={primaryButtonTitle}
          accessibilityIdentifier={accessibilityIdentifier ?? "Onboarding.CoachContinue"}
        >
          <Text style={styles.primaryButtonText}>{primaryButtonTitle}</Text>
        </Pressable>
      ) : null}

      {secondaryButtonTitle && onSecondaryButton ? (
        <Pressable
          style={styles.secondaryButton}
          onPress={onSecondaryButton}
          accessibilityRole="button"
          accessibilityLabel={secondaryButtonTitle}
          accessibilityIdentifier={secondaryAccessibilityIdentifier ?? "Onboarding.CoachSecondary"}
        >
          <Text style={[styles.secondaryButtonText, { color: textColor }]}>{secondaryButtonTitle}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

export function CoachMarkCard({
  title,
  message,
  variant,
  primaryButtonTitle,
  onPrimaryButton,
  secondaryButtonTitle,
  onSecondaryButton,
  accessibilityIdentifier,
  secondaryAccessibilityIdentifier,
  theme,
  textColor,
  usesLightForeground,
  blocksBackgroundInteractions = true,
}: CoachMarkCardProps) {
  const hasButton = !!(primaryButtonTitle && onPrimaryButton);
  // Dimming backdrop only for non-floating variants with a primary button
  const showDimming = variant !== "floatingBottom" && hasButton;

  const glassContent = (
    <GlassCard
      title={title}
      message={message}
      primaryButtonTitle={primaryButtonTitle}
      onPrimaryButton={onPrimaryButton}
      secondaryButtonTitle={secondaryButtonTitle}
      onSecondaryButton={onSecondaryButton}
      accessibilityIdentifier={accessibilityIdentifier}
      secondaryAccessibilityIdentifier={secondaryAccessibilityIdentifier}
      textColor={textColor}
      usesLightForeground={usesLightForeground}
    />
  );

  if (variant === "floatingBottom") {
    return (
      <View style={StyleSheet.absoluteFill} pointerEvents="box-none">
        <View style={styles.floatingBottomContainer} pointerEvents="box-none">
          <View style={{ paddingHorizontal: 24, paddingBottom: 12 + 8 /* safeArea */ }}>
            {glassContent}
          </View>
        </View>
      </View>
    );
  }

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents={hasButton && blocksBackgroundInteractions ? "auto" : "box-none"}>
      {/* Dimming backdrop */}
      {showDimming ? (
        <View
          style={[
            StyleSheet.absoluteFill,
            {
              backgroundColor: usesLightForeground
                ? "rgba(0, 0, 0, 0.12)"
                : "rgba(0, 0, 0, 0.08)",
            },
          ]}
          pointerEvents={blocksBackgroundInteractions ? "auto" : "none"}
        />
      ) : null}

      {/* Positioned card */}
      <View
        style={[
          StyleSheet.absoluteFill,
          variant === "belowTopChrome" && styles.belowTopChromeContainer,
          variant === "aboveShortcutRow" && styles.aboveShortcutRowContainer,
          variant === "belowQiblaIcon" && styles.belowQiblaIconContainer,
          variant === "belowQiblaIconLower" && styles.belowQiblaIconLowerContainer,
        ]}
        pointerEvents="box-none"
      >
        <View style={{ paddingHorizontal: 24, maxWidth: 380, alignSelf: "center", width: "100%" }}>
          {glassContent}
        </View>
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  glassCard: {
    borderRadius: 24,
    padding: 24,
    borderWidth: 1,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.24,
    shadowRadius: 30,
    elevation: 10,
  } as ViewStyle,
  cardTitle: {
    fontSize: 19,
    fontFamily: "Comfortaa_600SemiBold",
    letterSpacing: -0.2,
    marginBottom: 10,
  } as TextStyle,
  cardMessage: {
    fontSize: 16,
    fontFamily: "Comfortaa_400Regular",
    lineHeight: 22,
    marginBottom: 10,
  } as TextStyle,
  primaryButton: {
    backgroundColor: ACCENT,
    paddingVertical: 16,
    borderRadius: 100,
    alignItems: "center",
    marginTop: 6,
    shadowColor: ACCENT,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 15,
    elevation: 6,
  } as ViewStyle,
  primaryButtonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontFamily: "Comfortaa_600SemiBold",
  } as TextStyle,
  secondaryButton: {
    alignItems: "center",
    marginTop: 14,
    paddingVertical: 10,
  } as ViewStyle,
  secondaryButtonText: {
    fontSize: 15,
    fontFamily: "Comfortaa_600SemiBold",
    opacity: 0.72,
  } as TextStyle,

  // Position containers
  floatingBottomContainer: {
    flex: 1,
    justifyContent: "flex-end",
  },
  belowTopChromeContainer: {
    justifyContent: "flex-start",
    paddingTop: 56 + 12 + 52, // safeArea + header + offset
  },
  aboveShortcutRowContainer: {
    justifyContent: "flex-end",
    paddingBottom: 190,
  },
  belowQiblaIconContainer: {
    justifyContent: "flex-start",
    paddingTop: 56 + 240, // safeArea + qibla icon (120) + paddingTop(40) + topRow(~52) + gap
  },
  belowQiblaIconLowerContainer: {
    justifyContent: "flex-start",
    paddingTop: 56 + 320, // lower than belowQiblaIcon to keep hero circle visible
  },
});
