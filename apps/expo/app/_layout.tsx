import { Stack } from "expo-router";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { useEffect, useState } from "react";
import { DeviceEventEmitter } from "react-native";
import { useFonts } from "expo-font";
import {
  Comfortaa_300Light,
  Comfortaa_400Regular,
  Comfortaa_500Medium,
  Comfortaa_600SemiBold,
} from "@expo-google-fonts/comfortaa";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { MasjidlyConvexProvider } from "@/lib/convex/client";
import UpdatePromptModal from "@/components/updates/UpdatePromptModal";
import { useRouter } from "expo-router";
import { playAdhan } from "@/lib/audio/AdhanSoundPlayer";
import { useAppLanguage } from "@/lib/i18n/language";
import { t } from "@/lib/i18n/translations";

// ─────────────────────────────────────────────────────────────────────────────
// Notification categories & action identifiers
// ─────────────────────────────────────────────────────────────────────────────

const CATEGORY = {
  adhan: "masjidly.category.adhan",
  iqamah: "masjidly.category.iqamah",
  reminder: "masjidly.category.reminder",
} as const;

const ACTION = {
  viewTimes: "masjidly.action.view_times",
  snoozeReminder: "masjidly.action.snooze_reminder",
  viewMosque: "masjidly.action.view_mosque",
  openTimetable: "masjidly.action.open_timetable",
  dismiss: "masjidly.action.dismiss",
} as const;

/**
 * Register notification categories with action buttons.
 */
function useNotificationCategories() {
  const appLanguage = useAppLanguage();
  useEffect(() => {
    import("expo-notifications/build/setNotificationCategoryAsync")
      .then(({ setNotificationCategoryAsync }) =>
        Promise.all([
          setNotificationCategoryAsync(CATEGORY.adhan, [
            { identifier: ACTION.viewTimes, buttonTitle: t("notification.action.view_times", appLanguage), options: { opensAppToForeground: true } },
            { identifier: ACTION.snoozeReminder, buttonTitle: t("notification.action.snooze_reminder", appLanguage), options: {} },
          ]),
          setNotificationCategoryAsync(CATEGORY.iqamah, [
            { identifier: ACTION.viewMosque, buttonTitle: t("notification.action.view_mosque", appLanguage), options: { opensAppToForeground: true } },
            { identifier: ACTION.openTimetable, buttonTitle: t("notification.action.open_timetable", appLanguage), options: { opensAppToForeground: true } },
          ]),
          setNotificationCategoryAsync(CATEGORY.reminder, [
            { identifier: ACTION.openTimetable, buttonTitle: t("notification.action.open_timetable", appLanguage), options: { opensAppToForeground: true } },
            { identifier: ACTION.dismiss, buttonTitle: t("notification.action.dismiss", appLanguage), options: { destructive: true } },
          ]),
        ])
      )
      .catch(() => {
        // Notification categories unavailable in this environment
      });
  }, [appLanguage]);
}

/**
 * Present foreground notifications as banners with sound.
 */
function useNotificationHandler() {
  useEffect(() => {
    // Configure audio for adhan playback
    import("expo-audio").then((EA) => {
      EA.setAudioModeAsync({
        playsInSilentMode: true,
        shouldPlayInBackground: true,
        interruptionMode: "duckOthers",
      }).catch(() => {});
    }).catch(() => {});

    import("expo-notifications/build/NotificationsHandler")
      .then(({ setNotificationHandler }) => {
        setNotificationHandler({
          handleNotification: async () => ({
            shouldShowAlert: true,
            shouldPlaySound: true,
            shouldSetBadge: false,
          }),
        });
      })
      .catch(() => {
        // setNotificationHandler unavailable in this environment
      });
  }, []);
}

/**
 * Handle notification taps + action button presses.
 *
 * - Default tap on adhan notification → navigates to home
 * - View Times → navigates to home
 * - Open Timetable → navigates to timetable
 * - View Mosque → navigates to settings
 * - Snooze → re-schedules the same notification in 10 minutes
 * - Dismiss → no-op
 */
function useNotificationResponseListener() {
  const router = useRouter();
  useEffect(() => {
    let subscription: { remove: () => void } | null = null;

    import("expo-notifications/build/NotificationsEmitter")
      .then((NotificationsEmitter) => {
        subscription =
          NotificationsEmitter.addNotificationResponseReceivedListener(
          async (response: any) => {
            const { actionIdentifier } = response;
            const notification = response.notification;
            const data = notification.request.content.data ?? {};
            const kind: string | undefined = data.kind;

            // ── Dismiss ──
            if (actionIdentifier === ACTION.dismiss || actionIdentifier === "__DISMISS__") {
              return;
            }

            // ── Snooze ──
            if (actionIdentifier === ACTION.snoozeReminder) {
              try {
                const { scheduleNotificationAsync, SchedulableTriggerInputTypes } =
                  await import("@/lib/notifications/expoNotificationApi");
                const base = notification.request.content;
                const id = `masjidly.snooze.${Date.now()}.${Math.random().toString(36).slice(2)}`;
                await scheduleNotificationAsync({
                  identifier: id,
                  content: {
                    title: base.title ?? "",
                    body: base.body ?? "",
                    sound: base.sound ?? true,
                    data: base.data ?? {},
                  },
                  trigger: {
                    type: SchedulableTriggerInputTypes.TIME_INTERVAL,
                    seconds: 600,
                  },
                });
              } catch {
                // Snooze failed silently
              }
              return;
            }

            // ── Open Timetable ──
            if (actionIdentifier === ACTION.openTimetable || actionIdentifier === "__default__" && kind === "reminder") {
              router.replace("/timetable");
              return;
            }

            // ── View Mosque ──
            if (actionIdentifier === ACTION.viewMosque) {
              router.replace("/settings");
              return;
            }

            // ── Default: adhan/iqamah tap or "View Times" → home ──
            if (kind === "adhan") {
              await playAdhan(1);
            }
            router.replace("/");
          }
        );
      })
      .catch(() => {
        // NotificationsEmitter unavailable in this environment
      });

    return () => {
      subscription?.remove();
    };
  }, [router]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Root Layout
// ─────────────────────────────────────────────────────────────────────────────

export default function RootLayout() {
  useNotificationCategories();
  useNotificationHandler();
  useNotificationResponseListener();
  const [showTestUpdatePrompt, setShowTestUpdatePrompt] = useState(false);

  // Listen for test update prompt from settings dev section
  useEffect(() => {
    const sub = DeviceEventEmitter.addListener("masjidly:testUpdatePrompt", () => {
      setShowTestUpdatePrompt(true);
    });
    return () => sub.remove();
  }, []);

  useFonts({
    Comfortaa_300Light,
    Comfortaa_400Regular,
    Comfortaa_500Medium,
    Comfortaa_600SemiBold,
  });

  return (
    <ErrorBoundary>
      <SafeAreaProvider>
        <MasjidlyConvexProvider>
          <UpdatePromptModal
            autoCheck
            visible={showTestUpdatePrompt}
            onClose={() => setShowTestUpdatePrompt(false)}
          />
          <Stack>
            <Stack.Screen name="index" options={{ headerShown: false }} />
            <Stack.Screen
              name="timetable"
              options={{ presentation: "modal", headerShown: false }}
            />
            <Stack.Screen
              name="settings"
              options={{ presentation: "modal", headerShown: false }}
            />
          </Stack>
        </MasjidlyConvexProvider>
      </SafeAreaProvider>
    </ErrorBoundary>
  );
}
