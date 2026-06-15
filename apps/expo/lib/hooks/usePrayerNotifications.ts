import { useEffect } from "react";
import { useSettingsStore } from "@/store/settings";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import { prayerTimesCache } from "@/lib/prayer/prayerTimesCache";
import { resolveSelectedMosque } from "@/lib/prayer/mosqueDefaults";
import { resolvedLanguageCode } from "@/lib/i18n/language";
import {
  cancelAllPrayerNotifications,
  rescheduleUpcomingPrayerNotifications,
} from "@/lib/notifications/prayerNotifications";

export function usePrayerNotifications(): void {
  const notifications = useSettingsStore((s) => s.notifications);
  const selectedMosqueId = useSettingsStore((s) => s.selectedMosqueId);
  const selectedMosqueSlug = useSettingsStore((s) => s.selectedMosqueSlug);
  const appLanguage = useSettingsStore((s) => s.appLanguage);
  const asrIqamahPreference = useSettingsStore((s) => s.asrIqamahPreference);

  useEffect(() => {
    let cancelled = false;

    async function run() {
      if (!notifications.masterEnabled) {
        await cancelAllPrayerNotifications();
        return;
      }

      try {
        const mosques = await prayerRepository.listMosques().then(async (all) => {
          await prayerTimesCache.saveMosques(all);
          return all;
        }).catch(async () => (await prayerTimesCache.loadMosques()) ?? []);
        if (cancelled) return;

        const mosque = resolveSelectedMosque(
          mosques,
          selectedMosqueId,
          selectedMosqueSlug
        );
        if (!mosque) return;

        const locale = resolvedLanguageCode();
        await rescheduleUpcomingPrayerNotifications({
          mosque,
          settings: notifications,
          locale,
          asrIqamahPreference,
        });
      } catch {
        // Silently ignore errors to avoid crashing the app
      }
    }

    run();

    return () => {
      cancelled = true;
    };
  }, [
    notifications.masterEnabled,
    notifications.adhanEnabled,
    notifications.iqamahEnabled,
    notifications.preAdhanReminderMinutes,
    notifications.preIqamahReminderMinutes,
    notifications.fajr,
    notifications.dhuhrJummah,
    notifications.asr,
    notifications.maghrib,
    notifications.isha,
    selectedMosqueId,
    selectedMosqueSlug,
    appLanguage,
    asrIqamahPreference,
  ]);
}
