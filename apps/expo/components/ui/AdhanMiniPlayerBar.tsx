import React, { useEffect, useState, useCallback } from "react";
import { View, Text, StyleSheet, Pressable } from "react-native";
import { X, Play, Pause } from "lucide-react-native";
import { LinearGradient } from "expo-linear-gradient";
import { AdhanPlayer, togglePlayPause, stopAdhan } from "@/lib/audio/AdhanSoundPlayer";

interface Props {
  textColor: string;
}

function formatTime(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, "0")}`;
}

export const AdhanMiniPlayerBar: React.FC<Props> = ({ textColor }) => {
  const [, forceUpdate] = useState(0);

  useEffect(() => {
    const unsub = AdhanPlayer.subscribe(() => forceUpdate((n) => n + 1));
    return unsub;
  }, []);

  const fraction = AdhanPlayer.playbackFraction;
  const currentTime = AdhanPlayer.currentTime;
  const duration = AdhanPlayer.duration;
  const isPlaying = AdhanPlayer.isPlaying;
  const remaining = Math.max(0, duration - currentTime);

  if (!AdhanPlayer.showsMiniPlayer) return null;

  return (
    <View style={styles.wrapper}>
      <LinearGradient
        colors={[textColor + "14", textColor + "08"]}
        start={{ x: 0, y: 0 }}
        end={{ x: 0, y: 1 }}
        style={styles.card}
      >
        {/* Progress track */}
        <View style={styles.progressTrack}>
          <View style={[styles.progressTrackBg, { backgroundColor: textColor + "2E" }]}>
            <LinearGradient
              colors={["#47A6FF", "#7C5CFC"]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
              style={[
                styles.progressFill,
                { width: `${Math.min(100, Math.max(0, fraction * 100))}%` as any },
              ]}
            />
          </View>
        </View>

        {/* Controls row */}
        <View style={styles.controlsRow}>
          <View style={styles.infoColumn}>
            <Text
              style={[styles.title, { color: textColor }]}
              numberOfLines={1}
            >
              Adhan
            </Text>
            <Text
              style={[styles.timeLabel, { color: textColor + "D1" }]}
              numberOfLines={1}
            >
              {formatTime(currentTime)} / {formatTime(duration)} ·{" "}
              {formatTime(remaining)} left
            </Text>
          </View>

          {/* Play/Pause button */}
          <Pressable
            onPress={togglePlayPause}
            style={({ pressed }) => [styles.playButton, pressed && { opacity: 0.8 }]}
            accessibilityRole="button"
            accessibilityLabel={isPlaying ? "Pause adhan" : "Play adhan"}
          >
            <LinearGradient
              colors={["#47A6FF", "#7C5CFC"]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
              style={styles.playButtonGradient}
            >
              {isPlaying ? (
                <Pause size={17} color="#FFFFFF" strokeWidth={2.5} />
              ) : (
                <Play size={17} color="#FFFFFF" strokeWidth={2.5} fill="#FFFFFF" />
              )}
            </LinearGradient>
          </Pressable>

          {/* Dismiss button */}
          <Pressable
            onPress={stopAdhan}
            style={({ pressed }) => [styles.dismissButton, pressed && { opacity: 0.6 }]}
            accessibilityRole="button"
            accessibilityLabel="Stop adhan"
          >
            <X size={14} color={textColor + "8C"} strokeWidth={2} />
          </Pressable>
        </View>
      </LinearGradient>
    </View>
  );
};

const styles = StyleSheet.create({
  wrapper: {
    paddingHorizontal: 24,
    paddingBottom: 12,
  },
  card: {
    borderRadius: 16,
    padding: 24,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "rgba(255,255,255,0.22)",
    // Frosted look
    overflow: "hidden",
  },
  progressTrack: {
    marginBottom: 10,
  },
  progressTrackBg: {
    height: 4,
    borderRadius: 2,
    overflow: "hidden",
  },
  progressFill: {
    height: 4,
    borderRadius: 2,
  },
  controlsRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 16,
  },
  infoColumn: {
    flex: 1,
    gap: 4,
  },
  title: {
    fontSize: 19,
    fontFamily: "Comfortaa_600SemiBold",
    letterSpacing: -0.2,
  },
  timeLabel: {
    fontSize: 14,
    fontFamily: "Comfortaa_400Regular",
    letterSpacing: 0.4,
  },
  playButton: {
    shadowColor: "#47A6FF",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 15,
    elevation: 8,
  },
  playButtonGradient: {
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: "center",
    alignItems: "center",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.25)",
  },
  dismissButton: {
    width: 40,
    height: 44,
    justifyContent: "center",
    alignItems: "center",
  },
});
