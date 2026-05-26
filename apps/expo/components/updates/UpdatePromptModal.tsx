import { useState, useEffect, useCallback } from "react";
import {
  Modal,
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Platform,
  SafeAreaView,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import {
  checkForUpdate,
  openUpdateUrl,
  type UpdateInfo,
  type MasjidlyRelease,
} from "@/lib/updates/updateChecker";
import { useAppLanguage } from "@/lib/i18n/language";

interface UpdatePromptModalProps {
  /** If true, checks for update on mount and shows prompt if available */
  autoCheck?: boolean;
  /** If true, always show the modal (for testing) */
  visible?: boolean;
  onClose?: () => void;
}

export default function UpdatePromptModal({
  autoCheck = true,
  visible: externalVisible,
  onClose,
}: UpdatePromptModalProps) {
  const [internalVisible, setInternalVisible] = useState(false);
  const [updateInfo, setUpdateInfo] = useState<UpdateInfo | null>(null);
  const [checking, setChecking] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const language = useAppLanguage();

  const visible = externalVisible ?? internalVisible;

  const check = useCallback(async () => {
    setChecking(true);
    const info = await checkForUpdate();
    setUpdateInfo(info);
    setChecking(false);

    if (info.updateAvailable) {
      setInternalVisible(true);
    }
  }, []);

  useEffect(() => {
    if (autoCheck) {
      // Small delay to not block the initial render
      const timer = setTimeout(() => check(), 2000);
      return () => clearTimeout(timer);
    }
  }, [autoCheck, check]);

  const handleUpdate = async () => {
    if (updateInfo?.release) {
      setDownloading(true);
      await openUpdateUrl(updateInfo.release);
      setDownloading(false);
    }
  };

  const handleLater = () => {
    setInternalVisible(false);
    onClose?.();
  };

  if (!visible || !updateInfo?.release) return null;

  const { release } = updateInfo;
  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={handleLater}
    >
      <SafeAreaView style={styles.overlay}>
        <View style={styles.dialog}>
          {/* Icon */}
          <View style={styles.iconContainer}>
            <Ionicons name="cloud-download-outline" size={40} color="#1a6b3c" />
          </View>

          {/* Title */}
          <Text style={styles.title}>
            {language === "ar"
              ? "تحديث متوفر"
              : language === "ur"
                ? "اپ ڈیٹ دستیاب ہے"
                : language === "id"
                  ? "Pembaruan Tersedia"
                  : "Update Available"}
          </Text>

          {/* Body */}
          <Text style={styles.bodyText}>
            {language === "ar"
              ? "نسخة أحدث من مسجدلي جاهزة للتثبيت."
              : language === "ur"
                ? "مسجدلی کا نیا ورژن انسٹال کرنے کے لیے تیار ہے۔"
                : language === "id"
                  ? "Versi baru Masjidly siap dipasang."
                  : "A newer version of Masjidly is ready."}
          </Text>

          {/* Buttons */}
          <View style={styles.buttons}>
            <TouchableOpacity
              style={[styles.button, styles.secondaryButton]}
              onPress={handleLater}
              disabled={downloading}
            >
              <Text style={[styles.buttonText, styles.secondaryButtonText]}>
                {language === "ar"
                  ? "لاحقاً"
                  : language === "ur"
                    ? "بعد میں"
                    : language === "id"
                      ? "Nanti"
                      : "Later"}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.button, styles.primaryButton]}
              onPress={handleUpdate}
              disabled={downloading}
            >
              {downloading ? (
                <ActivityIndicator color="#fff" size="small" />
              ) : (
                <Text style={[styles.buttonText, styles.primaryButtonText]}>
                  {isAndroid
                    ? language === "ar"
                      ? "تحميل"
                      : language === "ur"
                        ? "ڈاؤن لوڈ کریں"
                        : language === "id"
                          ? "Unduh"
                          : "Download"
                    : language === "ar"
                      ? "فتح المتجر"
                      : language === "ur"
                        ? "اسٹور کھولیں"
                        : language === "id"
                          ? "Buka App Store"
                          : "Open App Store"}
                </Text>
              )}
            </TouchableOpacity>
          </View>

          {/* Checking indicator */}
          {checking && (
            <View style={styles.checkingRow}>
              <ActivityIndicator size="small" color="#999" />
              <Text style={styles.checkingText}>
                {language === "ar"
                  ? "جارٍ التحقق من التحديثات..."
                  : language === "ur"
                    ? "اپ ڈیٹس کی جانچ ہو رہی ہے..."
                    : language === "id"
                      ? "Memeriksa pembaruan..."
                      : "Checking for updates..."}
              </Text>
            </View>
          )}
        </View>
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.5)",
    justifyContent: "center",
    alignItems: "center",
    padding: 24,
  },
  dialog: {
    backgroundColor: "#fff",
    borderRadius: 20,
    padding: 28,
    width: "100%",
    maxWidth: 340,
    alignItems: "center",
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 8,
  },
  iconContainer: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: "#e8f5e9",
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: "700",
    color: "#1a1a1a",
    marginBottom: 4,
    textAlign: "center",
  },
  bodyText: {
    fontSize: 15,
    color: "#555",
    textAlign: "center",
    lineHeight: 22,
    marginBottom: 24,
  },
  buttons: {
    flexDirection: "row",
    gap: 12,
    width: "100%",
  },
  button: {
    flex: 1,
    height: 48,
    borderRadius: 12,
    justifyContent: "center",
    alignItems: "center",
  },
  primaryButton: {
    backgroundColor: "#1a6b3c",
  },
  secondaryButton: {
    backgroundColor: "#f0f0f0",
  },
  buttonText: {
    fontSize: 15,
    fontWeight: "600",
  },
  primaryButtonText: {
    color: "#fff",
  },
  secondaryButtonText: {
    color: "#666",
  },
  checkingRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    marginTop: 16,
  },
  checkingText: {
    fontSize: 13,
    color: "#999",
  },
});
