import { getPermissionsAsync, requestPermissionsAsync } from "@/lib/notifications/expoNotificationApi";
import { useSettingsStore } from "@/store/settings";

export type NotificationPermissionIssue =
  | { kind: "bug_recovery" }
  | { kind: "os_denied" }
  | { kind: "os_not_determined" }
  | null;

/**
 * Check whether the user's notification setup has a problem that needs
 * attention. Returns `null` when everything is fine.
 *
 * Scenarios:
 * 1. **Bug recovery** – User completed the tutorial under the old bug where
 *    `masterEnabled` was never persisted, so they think notifications are on
 *    but nothing is scheduled.
 * 2. **OS denied** – `masterEnabled` is true in-app but the OS denied or
 *    revoked permission. The app keeps scheduling but notifications never fire.
 * 3. **OS not determined** – `masterEnabled` is true but the OS was never
 *    asked (edge case / test scenario).
 */
export async function checkNotificationPermissionIssue(): Promise<NotificationPermissionIssue> {
  const settings = useSettingsStore.getState();

  // ── Bug recovery: user went through tutorial, picked adhan/iqamah,
  //    but masterEnabled was never persisted (bug that is now fixed). ──
  if (
    settings.hasCompletedOnboarding &&
    !settings.notifications.masterEnabled &&
    (settings.notifications.adhanEnabled || settings.notifications.iqamahEnabled)
  ) {
    return { kind: "bug_recovery" };
  }

  // ── If master is off, nothing more to check ──
  if (!settings.notifications.masterEnabled) {
    return null;
  }

  // ── OS-level check ──
  try {
    const { status } = await getPermissionsAsync();
    if (status === "denied") {
      return { kind: "os_denied" };
    }
    if (status === "undetermined" || status === "undetermined" as string) {
      return { kind: "os_not_determined" };
    }
    return null;
  } catch {
    // Permissions API may not be available (Expo Go on Android etc.)
    return null;
  }
}

/**
 * Prompt the OS notification permission dialog.
 * Returns true if the user granted permission.
 */
export async function requestNotificationPermission(): Promise<boolean> {
  try {
    const { status } = await requestPermissionsAsync();
    return status === "granted";
  } catch {
    return false;
  }
}

/**
 * Fix the "bug recovery" scenario by persisting masterEnabled.
 */
export function fixNotificationMasterEnabled(): void {
  const state = useSettingsStore.getState();
  const masterEnabled =
    state.notifications.adhanEnabled ||
    state.notifications.iqamahEnabled ||
    state.notifications.preAdhanReminderMinutes != null ||
    state.notifications.preIqamahReminderMinutes != null;

  useSettingsStore.setState((s) => ({
    notifications: {
      ...s.notifications,
      masterEnabled,
    },
  }));
}
