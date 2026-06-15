import { useState, useEffect, useCallback } from "react";
import {
  Modal,
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
} from "react-native";
import { HapticTouchableOpacity as TouchableOpacity } from "@/components/ui/HapticPressable";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import {
  checkForUpdate,
  openUpdateUrl,
  type UpdateInfo,
  type MasjidlyRelease,
} from "@/lib/updates/updateChecker";
import { useAppLanguage } from "@/lib/i18n/language";

const TEST_RELEASE: MasjidlyRelease = {
  android: {
    version: "9.9.9",
    versionCode: 999,
    url: "https://www.sheffieldmasjids.com/masjidly/Masjidly-1.1.2.apk",
    sha256: "",
    minVersionCode: 1,
  },
  ios: {
    version: "9.9.9",
    build: 999,
    appStoreUrl: "https://apps.apple.com/gb/app/masjidly-masjid-prayer-times/id6767841833",
  },
  pub_date: new Date().toISOString(),
  notes: {
    en: "New update available",
    ar: "تحديث جديد متاح",
    ur: "نیا اپ ڈیٹ دستیاب ہے",
    id: "Pembaruan baru tersedia",
  },
};

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

  const visible = Boolean(externalVisible || internalVisible);
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

  useEffect(() => {
    if (!externalVisible) return;

    let cancelled = false;
    checkForUpdate().then((info) => {
      if (cancelled) return;
      setUpdateInfo({
        updateAvailable: true,
        release: info.release ?? TEST_RELEASE,
        error: info.error,
      });
    });

    return () => {
      cancelled = true;
    };
  }, [externalVisible]);

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
                  {language === "ar"
                  ? "تحميل"
                  : language === "ur"
                    ? "ڈاؤن لوڈ کریں"
                    : language === "id"
                      ? "Unduh"
                      : "Download"}
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
