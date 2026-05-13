import AsyncStorage from "@react-native-async-storage/async-storage";
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

export interface NotificationSettings {
  masterEnabled: boolean;
  adhanEnabled: boolean;
  iqamahEnabled: boolean;
  preAdhanReminderMinutes: number | null;
  preIqamahReminderMinutes: number | null;
  fajr: boolean;
  dhuhrJummah: boolean;
  asr: boolean;
  maghrib: boolean;
  isha: boolean;
}

export interface SettingsState {
  selectedMosqueId?: string;
  selectedMosqueSlug?: string;
  uses24HourTime: boolean;
  hideQiblaCompass: boolean;
  hasCompletedOnboarding: boolean;
  notifications: NotificationSettings;
  setSelectedMosque: (id: string, slug: string) => void;
  setUses24HourTime: (v: boolean) => void;
  setHideQiblaCompass: (v: boolean) => void;
  setHasCompletedOnboarding: (v: boolean) => void;
  setNotificationMaster: (v: boolean) => void;
  setAdhanEnabled: (v: boolean) => void;
  setIqamahEnabled: (v: boolean) => void;
  setPreAdhanReminderMinutes: (v: number | null) => void;
  setPreIqamahReminderMinutes: (v: number | null) => void;
  setNotificationPrayer: (
    prayer: keyof Omit<NotificationSettings, "masterEnabled" | "adhanEnabled" | "iqamahEnabled" | "preAdhanReminderMinutes" | "preIqamahReminderMinutes">,
    enabled: boolean
  ) => void;
  resetSettings: () => void;
}

const defaultNotifications: NotificationSettings = {
  masterEnabled: false,
  adhanEnabled: true,
  iqamahEnabled: true,
  preAdhanReminderMinutes: null,
  preIqamahReminderMinutes: null,
  fajr: true,
  dhuhrJummah: true,
  asr: true,
  maghrib: true,
  isha: true,
};

const initialState: Omit<
  SettingsState,
  | "setSelectedMosque"
  | "setUses24HourTime"
  | "setHideQiblaCompass"
  | "setHasCompletedOnboarding"
  | "setNotificationMaster"
  | "setAdhanEnabled"
  | "setIqamahEnabled"
  | "setPreAdhanReminderMinutes"
  | "setPreIqamahReminderMinutes"
  | "setNotificationPrayer"
  | "resetSettings"
> = {
  selectedMosqueId: undefined,
  selectedMosqueSlug: undefined,
  uses24HourTime: false,
  hideQiblaCompass: false,
  hasCompletedOnboarding: false,
  notifications: defaultNotifications,
};

type PersistedV1 = {
  state: {
    appLanguage?: string;
    notifications: { masterEnabled: boolean };
  };
};

type PersistedV2 = {
  state: {
    appLanguage?: string;
    notifications: {
      masterEnabled: boolean;
      fajr: boolean;
      dhuhrJummah: boolean;
      asr: boolean;
      maghrib: boolean;
      isha: boolean;
    };
  };
};

type PersistedV3 = {
  state: {
    appLanguage?: string;
    hasCompletedOnboarding: boolean;
    notifications: NotificationSettings;
  };
};

function stripAppLanguage<T extends Record<string, unknown>>(state: T): Omit<T, "appLanguage"> {
  const { appLanguage: _removed, ...rest } = state;
  return rest;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      ...initialState,
      setSelectedMosque: (id, slug) =>
        set({ selectedMosqueId: id, selectedMosqueSlug: slug }),
      setUses24HourTime: (v) => set({ uses24HourTime: v }),
      setHideQiblaCompass: (v) => set({ hideQiblaCompass: v }),
      setHasCompletedOnboarding: (v) => set({ hasCompletedOnboarding: v }),
      setNotificationMaster: (v) =>
        set((state) => ({
          notifications: { ...state.notifications, masterEnabled: v },
        })),
      setAdhanEnabled: (v) =>
        set((state) => ({
          notifications: { ...state.notifications, adhanEnabled: v },
        })),
      setIqamahEnabled: (v) =>
        set((state) => ({
          notifications: { ...state.notifications, iqamahEnabled: v },
        })),
      setPreAdhanReminderMinutes: (v) =>
        set((state) => ({
          notifications: { ...state.notifications, preAdhanReminderMinutes: v },
        })),
      setPreIqamahReminderMinutes: (v) =>
        set((state) => ({
          notifications: { ...state.notifications, preIqamahReminderMinutes: v },
        })),
      setNotificationPrayer: (prayer, enabled) =>
        set((state) => ({
          notifications: { ...state.notifications, [prayer]: enabled },
        })),
      resetSettings: () => set({ ...initialState }),
    }),
    {
      name: "masjidly-settings",
      storage: createJSONStorage(() => AsyncStorage),
      version: 4,
      migrate: (persisted: unknown, version: number): unknown => {
        if (!persisted || typeof persisted !== "object" || !("state" in persisted)) {
          return persisted;
        }
        let shell = persisted as { state: Record<string, unknown> };

        if (version <= 1) {
          const v1 = persisted as PersistedV1;
          const migrated: PersistedV3 = {
            ...v1,
            state: {
              ...v1.state,
              appLanguage: (v1.state as { appLanguage?: string }).appLanguage ?? "system",
              hasCompletedOnboarding: false,
              notifications: {
                masterEnabled: v1.state.notifications?.masterEnabled ?? false,
                adhanEnabled: true,
                iqamahEnabled: true,
                preAdhanReminderMinutes: null,
                preIqamahReminderMinutes: null,
                fajr: true,
                dhuhrJummah: true,
                asr: true,
                maghrib: true,
                isha: true,
              },
            },
          };
          shell = migrated;
        } else if (version === 2) {
          const v2 = persisted as PersistedV2;
          const migrated: PersistedV3 = {
            ...v2,
            state: {
              ...v2.state,
              hasCompletedOnboarding: false,
              notifications: {
                ...v2.state.notifications,
                adhanEnabled: true,
                iqamahEnabled: true,
                preAdhanReminderMinutes: null,
                preIqamahReminderMinutes: null,
              },
            },
          };
          shell = migrated;
        }

        if (version < 4) {
          return { ...shell, state: stripAppLanguage(shell.state) };
        }

        if ("appLanguage" in shell.state) {
          return { ...shell, state: stripAppLanguage(shell.state) };
        }

        return persisted;
      },
    }
  )
);
