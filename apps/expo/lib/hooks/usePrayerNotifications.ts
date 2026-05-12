import { useEffect } from "react";
import { useSettingsStore } from "@/store/settings";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
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

  useEffect(() => {
    let cancelled = false;

    async function run() {
      if (!notifications.masterEnabled) {
        await cancelAllPrayerNotifications();
        return;
      }

      try {
        const mosques = await prayerRepository.listMosques();
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
  ]);
}
