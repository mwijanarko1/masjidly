import { create } from "zustand";
import { useSettingsStore } from "@/store/settings";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import {
  cancelAllPrayerNotifications,
  requestNotificationAuthorizationIfNeeded,
  rescheduleUpcomingPrayerNotifications,
} from "@/lib/notifications/prayerNotifications";
import { resolveSelectedMosque, cityGroupingKey } from "@/lib/prayer/mosqueDefaults";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type OnboardingStep =
  | { type: "chooseMosque" }
  | { type: "prayerShortcut"; index: number }
  | { type: "qiblaCountdown" }
  | { type: "qibla" }
  | { type: "openTimetable" }
  | { type: "exploreTimetable" }
  | { type: "closeTimetable" }
  | { type: "openSettings" }
  | { type: "exploreSettings" }
  | { type: "closeSettings" }
  | { type: "notifications" };

export interface NotificationDraft {
  adhanEnabled: boolean;
  iqamahEnabled: boolean;
  preAdhanReminderMinutes: number | null;
  preIqamahReminderMinutes: number | null;
}

interface MosqueStub {
  id: string;
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

interface OnboardingState {
  currentStep: OnboardingStep | null;
  selectedMosqueId: string;
  notificationDraft: NotificationDraft;
  isCompletingNotifications: boolean;

  startIfNeeded: (mosques: MosqueStub[]) => void;
  selectMosque: (mosqueId: string) => Promise<void>;
  handlePrayerShortcutTap: (index: number) => void;
  completeQiblaCountdown: () => void;
  completeQiblaOnboardingAllowingLocationRequest: () => void;
  completeQiblaOnboardingDeferringLocation: () => void;
  acknowledgeQiblaIntro: () => void;
  handleTimetableOpened: () => void;
  acknowledgeTimetableExplore: () => void;
  handleTimetableClosed: () => void;
  handleSettingsOpened: () => void;
  acknowledgeSettingsExplore: () => void;
  handleSettingsClosed: () => void;
  completeNotificationSetup: () => Promise<void>;
  restartTutorial: () => void;
}

function defaultDraftFromSettings(): NotificationDraft {
  const s = useSettingsStore.getState().notifications;
  return {
    adhanEnabled: s.adhanEnabled,
    iqamahEnabled: s.iqamahEnabled,
    preAdhanReminderMinutes: s.preAdhanReminderMinutes,
    preIqamahReminderMinutes: s.preIqamahReminderMinutes,
  };
}

export const useOnboardingStore = create<OnboardingState>()((set, get) => ({
  currentStep: null,
  selectedMosqueId: "",
  notificationDraft: defaultDraftFromSettings(),
  isCompletingNotifications: false,

  startIfNeeded: (mosques) => {
    const settings = useSettingsStore.getState();
    if (settings.hasCompletedOnboarding) {
      set({ currentStep: null });
      return;
    }
    if (mosques.length === 0) {
      set({ currentStep: null });
      return;
    }

    let selectedId = get().selectedMosqueId;
    if (!selectedId) {
      selectedId = settings.selectedMosqueId ?? mosques[0]?.id ?? "";
    }

    set({
      selectedMosqueId: selectedId,
      notificationDraft: defaultDraftFromSettings(),
      currentStep: { type: "chooseMosque" },
    });
  },

  selectMosque: async (mosqueId) => {
    set({ selectedMosqueId: mosqueId });

    const settings = useSettingsStore.getState();
    const allMosques = await prayerRepository.listMosques();
    const mosque = allMosques.find((m) => m.id === mosqueId);
    if (mosque) {
      settings.setSelectedMosque(mosque.id, mosque.slug, cityGroupingKey(mosque));
    }

    set({ currentStep: { type: "prayerShortcut", index: 0 } });
  },

  handlePrayerShortcutTap: (index) => {
    const step = get().currentStep;
    if (
      !step ||
      step.type !== "prayerShortcut" ||
      step.index !== 0 ||
      index < 0 ||
      index > 5
    ) return;

    set({ currentStep: { type: "qiblaCountdown" } });
  },

  completeQiblaCountdown: () => {
    const step = get().currentStep;
    if (!step || step.type !== "qiblaCountdown") return;
    set({ currentStep: { type: "qibla" } });
  },

  completeQiblaOnboardingAllowingLocationRequest: () => {
    const step = get().currentStep;
    if (!step || step.type !== "qibla") return;
    useSettingsStore.getState().setHideQiblaCompass(false);
    set({ currentStep: { type: "openTimetable" } });
  },

  completeQiblaOnboardingDeferringLocation: () => {
    const step = get().currentStep;
    if (!step || step.type !== "qibla") return;
    useSettingsStore.getState().setHideQiblaCompass(true);
    set({ currentStep: { type: "openTimetable" } });
  },

  acknowledgeQiblaIntro: () => {
    get().completeQiblaOnboardingAllowingLocationRequest();
  },

  handleTimetableOpened: () => {
    const step = get().currentStep;
    if (!step || step.type !== "openTimetable") return;
    set({ currentStep: { type: "exploreTimetable" } });
  },

  acknowledgeTimetableExplore: () => {
    const step = get().currentStep;
    if (!step || step.type !== "exploreTimetable") return;
    set({ currentStep: { type: "closeTimetable" } });
  },

  handleTimetableClosed: () => {
    const step = get().currentStep;
    if (!step || step.type !== "closeTimetable") return;
    set({ currentStep: { type: "openSettings" } });
  },

  handleSettingsOpened: () => {
    const step = get().currentStep;
    if (!step || step.type !== "openSettings") return;
    set({ currentStep: { type: "exploreSettings" } });
  },

  acknowledgeSettingsExplore: () => {
    const step = get().currentStep;
    if (!step || step.type !== "exploreSettings") return;
    set({ currentStep: { type: "closeSettings" } });
  },

  handleSettingsClosed: () => {
    const step = get().currentStep;
    if (!step || step.type !== "closeSettings") return;
    set({ currentStep: { type: "notifications" } });
  },

  completeNotificationSetup: async () => {
    const step = get().currentStep;
    if (!step || step.type !== "notifications" || get().isCompletingNotifications) return;

    set({ isCompletingNotifications: true });
    try {
      const draft = get().notificationDraft;
      const settings = useSettingsStore.getState();

      const masterEnabled =
        draft.adhanEnabled ||
        draft.iqamahEnabled ||
        draft.preAdhanReminderMinutes != null ||
        draft.preIqamahReminderMinutes != null;

      // Persist the full notification choice atomically, matching native iOS.
      // Without masterEnabled, Expo rescheduling exits early and the OS never
      // receives any pending prayer notifications from the tutorial flow.
      useSettingsStore.setState((state) => ({
        notifications: {
          ...state.notifications,
          masterEnabled,
          adhanEnabled: draft.adhanEnabled,
          iqamahEnabled: draft.iqamahEnabled,
          preAdhanReminderMinutes: draft.preAdhanReminderMinutes,
          preIqamahReminderMinutes: draft.preIqamahReminderMinutes,
        },
      }));

      const nextNotifications = useSettingsStore.getState().notifications;

      if (masterEnabled) {
        await requestNotificationAuthorizationIfNeeded();

        const allMosques = await prayerRepository.listMosques();
        const mosque = resolveSelectedMosque(
          allMosques,
          settings.selectedMosqueId,
          settings.selectedMosqueSlug
        );

        if (mosque) {
          await rescheduleUpcomingPrayerNotifications({
            mosque,
            settings: nextNotifications,
            locale: "en",
          });
        }
      } else {
        await cancelAllPrayerNotifications();
      }

      useSettingsStore.getState().setHasCompletedOnboarding(true);
      set({ currentStep: null, isCompletingNotifications: false });
    } catch {
      set({ isCompletingNotifications: false });
    }
  },

  restartTutorial: () => {
    useSettingsStore.getState().setHasCompletedOnboarding(false);
    const s = useSettingsStore.getState();
    set({
      notificationDraft: {
        adhanEnabled: s.notifications.adhanEnabled,
        iqamahEnabled: s.notifications.iqamahEnabled,
        preAdhanReminderMinutes: s.notifications.preAdhanReminderMinutes,
        preIqamahReminderMinutes: s.notifications.preIqamahReminderMinutes,
      },
      currentStep: { type: "chooseMosque" },
    });
  },
}));
