import React, { useState } from "react";
import {
  Modal,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { LinearGradient } from "expo-linear-gradient";
import { Bell, BellOff, ShieldAlert } from "lucide-react-native";
import { getSkyTheme, getTextColor, ACCENT } from "@/lib/design/themes";
import { getFontScale } from "@/lib/i18n/language";
import { t, type TranslationKey } from "@/lib/i18n/translations";
import type { TimeTheme } from "@/lib/design/themes";
import type { AppLanguage } from "@/store/settings";
import type { NotificationPermissionIssue } from "@/lib/notifications/notificationPermissionCheck";

interface NotificationRecoveryModalProps {
  visible: boolean;
  theme: TimeTheme;
  language: AppLanguage;
  issue: NotificationPermissionIssue;
  onEnable: () => Promise<void>;
  onDismiss: () => void;
}

function issueCopy(issue: NotificationPermissionIssue, lan: AppLanguage) {
  if (issue?.kind === "bug_recovery") {
    return {
      icon: "bug_recovery" as const,
      title: t("notification.recovery.bug.title" as TranslationKey, lan),
      message: t("notification.recovery.bug.message" as TranslationKey, lan),
      actionLabel: t("notification.recovery.bug.action" as TranslationKey, lan),
    };
  }
  // os_denied / os_not_determined
  return {
    icon: "os_denied" as const,
    title: t("notification.recovery.denied.title" as TranslationKey, lan),
    message: t("notification.recovery.denied.message" as TranslationKey, lan),
    actionLabel: t("notification.recovery.denied.action" as TranslationKey, lan),
  };
}

export function NotificationRecoveryModal({
  visible,
  theme,
  language,
  issue,
  onEnable,
  onDismiss,
}: NotificationRecoveryModalProps) {
  const [isSaving, setIsSaving] = useState(false);
  if (!issue) return null;

  const sky = getSkyTheme(theme);
  const textColor = getTextColor(theme);
  const usesLightForeground = textColor === "#FFFFFF";
  const fontScale = getFontScale(language);
  const copy = issueCopy(issue, language);

  const handleEnable = async () => {
    setIsSaving(true);
    try {
      await onEnable();
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onDismiss}>
      <View style={styles.overlay}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onDismiss}>
          <LinearGradient colors={sky.baseColors.map((c) => `${c}DD`)} style={StyleSheet.absoluteFill} />
          <View style={styles.dim} />
        </Pressable>

        <View
          style={[
            styles.cardWrap,
            {
              backgroundColor: usesLightForeground
                ? "rgb(10, 10, 30)"
                : "rgb(255, 255, 255)",
            },
          ]}
        >
          <View
            style={[
              styles.cardBorder,
              {
                borderColor: usesLightForeground
                  ? "rgba(255,255,255,0.15)"
                  : "rgba(0,0,0,0.12)",
              },
            ]}
          >
            <View style={styles.cardInner}>
              {/* Icon */}
              <View style={styles.iconRow}>
                <View style={[styles.iconCircle, { backgroundColor: `${textColor}1A` }]}>
                  {copy.icon === "bug_recovery" ? (
                    <BellOff size={28} color={ACCENT} strokeWidth={1.7} />
                  ) : (
                    <ShieldAlert size={28} color="#FF9500" strokeWidth={1.7} />
                  )}
                </View>
              </View>

              {/* Title */}
              <Text
                style={[
                  styles.title,
                  { color: textColor, fontSize: 22 * fontScale },
                ]}
              >
                {copy.title}
              </Text>

              {/* Message */}
              <Text
                style={[
                  styles.message,
                  { color: `${textColor}B8`, fontSize: 15 * fontScale },
                ]}
              >
                {copy.message}
              </Text>

              {/* Action Buttons */}
              <View style={styles.buttonRow}>
                <Pressable
                  style={[
                    styles.secondaryButton,
                    {
                      borderColor: usesLightForeground
                        ? "rgba(255,255,255,0.25)"
                        : "rgba(0,0,0,0.15)",
                    },
                  ]}
                  onPress={onDismiss}
                  disabled={isSaving}
                  accessibilityRole="button"
                >
                  <Text
                    style={[
                      styles.secondaryText,
                      { color: textColor, fontSize: 15 * fontScale },
                    ]}
                  >
                    {t("action.not_now" as TranslationKey, language)}
                  </Text>
                </Pressable>

                <Pressable
                  style={styles.primaryButton}
                  onPress={handleEnable}
                  disabled={isSaving}
                  accessibilityRole="button"
                >
                  <LinearGradient
                    colors={["#5FC3FF", "#2E8DFF"]}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.primaryGradient}
                  >
                    <Bell size={16} color="#FFFFFF" strokeWidth={2} />
                    <Text style={styles.primaryText}>
                      {isSaving
                        ? t("action.loading" as TranslationKey, language)
                        : copy.actionLabel}
                    </Text>
                  </LinearGradient>
                </Pressable>
              </View>
            </View>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 24,
  },
  dim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0,0,0,0.38)",
  },
  cardWrap: {
    width: "100%",
    maxWidth: 340,
    borderRadius: 34,
    overflow: "hidden",
  },
  cardBorder: {
    borderRadius: 34,
    borderWidth: 1,
  },
  cardInner: {
    padding: 28,
    gap: 20,
    alignItems: "center",
  },
  iconRow: {
    alignItems: "center",
    paddingTop: 6,
  },
  iconCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: "center",
    justifyContent: "center",
  },
  title: {
    fontFamily: "Comfortaa_600SemiBold",
    textAlign: "center",
  },
  message: {
    fontFamily: "Comfortaa_400Regular",
    textAlign: "center",
    lineHeight: 22,
    paddingHorizontal: 4,
  },
  buttonRow: {
    flexDirection: "row",
    gap: 12,
    paddingTop: 4,
    width: "100%",
  },
  secondaryButton: {
    flex: 1,
    minHeight: 48,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    // borderColor set dynamically inline
  },
  secondaryText: {
    fontFamily: "Comfortaa_600SemiBold",
  },
  primaryButton: {
    flex: 1.5,
    minHeight: 48,
    borderRadius: 999,
    overflow: "hidden",
  },
  primaryGradient: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingHorizontal: 16,
  },
  primaryText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontFamily: "Comfortaa_600SemiBold",
  },
});
