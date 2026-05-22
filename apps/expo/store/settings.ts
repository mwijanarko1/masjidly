import AsyncStorage from "@react-native-async-storage/async-storage";
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

export type AppLanguage = "en" | "ar" | "ur" | "id";
export type ThemeMode = "dynamic" | "fixed";
export type TimeTheme = "fajr" | "sunrise" | "dhuhr" | "asr" | "maghrib" | "isha" | "tahajjud";

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
  /** When set, filters mosque pickers to this city; optional for backward compatibility. */
  selectedCityGroupingKey?: string;
  uses24HourTime: boolean;
  hideQiblaCompass: boolean;
  hasCompletedOnboarding: boolean;
  appLanguage: AppLanguage;
  themeMode: ThemeMode;
  fixedTheme: TimeTheme;
  notifications: NotificationSettings;
  setSelectedMosque: (id: string, slug: string, cityGroupingKey?: string) => void;
  setSelectedCityGroupingKey: (key: string | undefined) => void;
  setUses24HourTime: (v: boolean) => void;
  setHideQiblaCompass: (v: boolean) => void;
  setHasCompletedOnboarding: (v: boolean) => void;
  setAppLanguage: (v: AppLanguage) => void;
  setThemeMode: (v: ThemeMode) => void;
  setFixedTheme: (v: TimeTheme) => void;
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
  | "setSelectedCityGroupingKey"
  | "setUses24HourTime"
  | "setHideQiblaCompass"
  | "setHasCompletedOnboarding"
  | "setAppLanguage"
  | "setThemeMode"
  | "setFixedTheme"
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
  selectedCityGroupingKey: undefined,
  uses24HourTime: false,
  hideQiblaCompass: false,
  hasCompletedOnboarding: false,
  appLanguage: "en",
  themeMode: "dynamic",
  fixedTheme: "fajr",
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

function normalizeAppLanguage(value: unknown): AppLanguage {
  return value === "ar" || value === "ur" || value === "id" || value === "en" ? value : "en";
}

function normalizeThemeMode(value: unknown): ThemeMode {
  return value === "fixed" ? "fixed" : "dynamic";
}

function normalizeFixedTheme(value: unknown): TimeTheme {
  return value === "fajr" ||
    value === "sunrise" ||
    value === "dhuhr" ||
    value === "asr" ||
    value === "maghrib" ||
    value === "isha"
    ? value
    : "fajr";
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      ...initialState,
      setSelectedMosque: (id, slug, cityKey) =>
        set({
          selectedMosqueId: id,
          selectedMosqueSlug: slug,
          ...(cityKey !== undefined ? { selectedCityGroupingKey: cityKey } : {}),
        }),
      setSelectedCityGroupingKey: (key) => set({ selectedCityGroupingKey: key }),
      setUses24HourTime: (v) => set({ uses24HourTime: v }),
      setHideQiblaCompass: (v) => set({ hideQiblaCompass: v }),
      setHasCompletedOnboarding: (v) => set({ hasCompletedOnboarding: v }),
      setAppLanguage: (v) => set({ appLanguage: v }),
      setThemeMode: (v) => set({ themeMode: v }),
      setFixedTheme: (v) => set({ fixedTheme: normalizeFixedTheme(v) }),
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
      version: 7,
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
              appLanguage: normalizeAppLanguage((v1.state as { appLanguage?: string }).appLanguage),
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

        return {
          ...shell,
          state: {
            ...shell.state,
            appLanguage: normalizeAppLanguage(shell.state.appLanguage),
            themeMode: normalizeThemeMode(shell.state.themeMode),
            fixedTheme: normalizeFixedTheme(shell.state.fixedTheme),
          },
        };
      },
    }
  )
);
