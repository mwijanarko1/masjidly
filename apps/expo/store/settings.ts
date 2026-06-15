import AsyncStorage from "@react-native-async-storage/async-storage";
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import type { AsrIqamahPreference } from "@/types/prayer";

export type AppLanguage = "en" | "ar" | "ur" | "id";
export type ThemeMode = "dynamic" | "fixed";
export type TimeTheme = "fajr" | "sunrise" | "dhuhr" | "asr" | "maghrib" | "isha" | "tahajjud";

export interface NotificationSettings {
  masterEnabled: boolean;
  adhanEnabled: boolean;
  iqamahEnabled: boolean;
  preAdhanReminderMinutes: number | null;
  preIqamahReminderMinutes: number | null;
  /** @deprecated Use adhanFajr / iqamahFajr instead */
  fajr: boolean;
  /** @deprecated Use adhanDhuhrJummah / iqamahDhuhrJummah instead */
  dhuhrJummah: boolean;
  /** @deprecated Use adhanAsr / iqamahAsr instead */
  asr: boolean;
  /** @deprecated Use adhanMaghrib / iqamahMaghrib instead */
  maghrib: boolean;
  /** @deprecated Use adhanIsha / iqamahIsha instead */
  isha: boolean;
  // Per-type per-prayer flags
  adhanFajr: boolean;
  adhanDhuhrJummah: boolean;
  adhanAsr: boolean;
  adhanMaghrib: boolean;
  adhanIsha: boolean;
  iqamahFajr: boolean;
  iqamahDhuhrJummah: boolean;
  iqamahAsr: boolean;
  iqamahMaghrib: boolean;
  iqamahIsha: boolean;
}

export interface SettingsState {
  selectedMosqueId?: string;
  selectedMosqueSlug?: string;
  /** When set, filters mosque pickers to this city; optional for backward compatibility. */
  selectedCityGroupingKey?: string;
  /** When set, filters city/mosque pickers to this country; optional for backward compatibility. */
  selectedCountryGroupingKey?: string;
  uses24HourTime: boolean;
  hideQiblaCompass: boolean;
  hasCompletedOnboarding: boolean;
  lastSeenBuildVersion?: string;
  appLanguage: AppLanguage;
  themeMode: ThemeMode;
  fixedTheme: TimeTheme;
  asrIqamahPreference: AsrIqamahPreference;
  notifications: NotificationSettings;
  setSelectedMosque: (id: string, slug: string, cityGroupingKey?: string, countryGroupingKey?: string) => void;
  setSelectedCityGroupingKey: (key: string | undefined) => void;
  setSelectedCountryGroupingKey: (key: string | undefined) => void;
  setUses24HourTime: (v: boolean) => void;
  setHideQiblaCompass: (v: boolean) => void;
  setHasCompletedOnboarding: (v: boolean) => void;
  setLastSeenBuildVersion: (v: string) => void;
  setAppLanguage: (v: AppLanguage) => void;
  setThemeMode: (v: ThemeMode) => void;
  setFixedTheme: (v: TimeTheme) => void;
  setAsrIqamahPreference: (v: AsrIqamahPreference) => void;
  setNotificationMaster: (v: boolean) => void;
  setAdhanEnabled: (v: boolean) => void;
  setIqamahEnabled: (v: boolean) => void;
  setPreAdhanReminderMinutes: (v: number | null) => void;
  setPreIqamahReminderMinutes: (v: number | null) => void;
  setNotificationPrayer: (
    prayer: keyof Omit<NotificationSettings, "masterEnabled" | "adhanEnabled" | "iqamahEnabled" | "preAdhanReminderMinutes" | "preIqamahReminderMinutes">,
    enabled: boolean
  ) => void;
  setAdhanNotificationPrayer: (prayer: 'fajr' | 'dhuhrJummah' | 'asr' | 'maghrib' | 'isha', enabled: boolean) => void;
  setIqamahNotificationPrayer: (prayer: 'fajr' | 'dhuhrJummah' | 'asr' | 'maghrib' | 'isha', enabled: boolean) => void;
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
  adhanFajr: true,
  adhanDhuhrJummah: true,
  adhanAsr: true,
  adhanMaghrib: true,
  adhanIsha: true,
  iqamahFajr: true,
  iqamahDhuhrJummah: true,
  iqamahAsr: true,
  iqamahMaghrib: true,
  iqamahIsha: true,
};

const initialState: Omit<
  SettingsState,
  | "setSelectedMosque"
  | "setSelectedCityGroupingKey"
  | "setSelectedCountryGroupingKey"
  | "setUses24HourTime"
  | "setHideQiblaCompass"
  | "setHasCompletedOnboarding"
  | "setLastSeenBuildVersion"
  | "setAppLanguage"
  | "setThemeMode"
  | "setFixedTheme"
  | "setAsrIqamahPreference"
  | "setNotificationMaster"
  | "setAdhanEnabled"
  | "setIqamahEnabled"
  | "setPreAdhanReminderMinutes"
  | "setPreIqamahReminderMinutes"
  | "setNotificationPrayer"
  | "setAdhanNotificationPrayer"
  | "setIqamahNotificationPrayer"
  | "resetSettings"
> = {
  selectedMosqueId: undefined,
  selectedMosqueSlug: undefined,
  selectedCityGroupingKey: undefined,
  selectedCountryGroupingKey: undefined,
  uses24HourTime: false,
  hideQiblaCompass: false,
  hasCompletedOnboarding: false,
  lastSeenBuildVersion: undefined,
  appLanguage: "en",
  themeMode: "dynamic",
  fixedTheme: "fajr",
  asrIqamahPreference: "first",
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

function normalizeAsrIqamahPreference(value: unknown): AsrIqamahPreference {
  return value === "second" ? "second" : "first";
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
      setSelectedMosque: (id, slug, cityKey, countryKey) =>
        set({
          selectedMosqueId: id,
          selectedMosqueSlug: slug,
          ...(cityKey !== undefined ? { selectedCityGroupingKey: cityKey } : {}),
          ...(countryKey !== undefined ? { selectedCountryGroupingKey: countryKey } : {}),
        }),
      setSelectedCityGroupingKey: (key) => set({ selectedCityGroupingKey: key }),
      setSelectedCountryGroupingKey: (key) => set({ selectedCountryGroupingKey: key }),
      setUses24HourTime: (v) => set({ uses24HourTime: v }),
      setHideQiblaCompass: (v) => set({ hideQiblaCompass: v }),
      setHasCompletedOnboarding: (v) => set({ hasCompletedOnboarding: v }),
      setLastSeenBuildVersion: (v) => set({ lastSeenBuildVersion: v }),
      setAppLanguage: (v) => set({ appLanguage: v }),
      setThemeMode: (v) => set({ themeMode: v }),
      setFixedTheme: (v) => set({ fixedTheme: normalizeFixedTheme(v) }),
      setAsrIqamahPreference: (v) => set({ asrIqamahPreference: normalizeAsrIqamahPreference(v) }),
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
      setAdhanNotificationPrayer: (prayer, enabled) =>
        set((state) => ({
          notifications: {
            ...state.notifications,
            [`adhan${prayer.charAt(0).toUpperCase()}${prayer.slice(1)}` as keyof NotificationSettings]: enabled,
          },
        })),
      setIqamahNotificationPrayer: (prayer, enabled) =>
        set((state) => ({
          notifications: {
            ...state.notifications,
            [`iqamah${prayer.charAt(0).toUpperCase()}${prayer.slice(1)}` as keyof NotificationSettings]: enabled,
          },
        })),
      resetSettings: () => set({ ...initialState }),
    }),
    {
      name: "masjidly-settings",
      storage: createJSONStorage(() => AsyncStorage),
      version: 9,
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

        // Merge notification defaults & migrate legacy per-prayer fields
        const notifs = (shell.state.notifications ?? {}) as Record<string, unknown>;
        shell.state.notifications = {
          ...defaultNotifications,
          ...notifs,
          adhanFajr: (notifs.adhanFajr as boolean | undefined) ?? (notifs.fajr as boolean | undefined) ?? true,
          iqamahFajr: (notifs.iqamahFajr as boolean | undefined) ?? (notifs.fajr as boolean | undefined) ?? true,
          adhanDhuhrJummah: (notifs.adhanDhuhrJummah as boolean | undefined) ?? (notifs.dhuhrJummah as boolean | undefined) ?? true,
          iqamahDhuhrJummah: (notifs.iqamahDhuhrJummah as boolean | undefined) ?? (notifs.dhuhrJummah as boolean | undefined) ?? true,
          adhanAsr: (notifs.adhanAsr as boolean | undefined) ?? (notifs.asr as boolean | undefined) ?? true,
          iqamahAsr: (notifs.iqamahAsr as boolean | undefined) ?? (notifs.asr as boolean | undefined) ?? true,
          adhanMaghrib: (notifs.adhanMaghrib as boolean | undefined) ?? (notifs.maghrib as boolean | undefined) ?? true,
          iqamahMaghrib: (notifs.iqamahMaghrib as boolean | undefined) ?? (notifs.maghrib as boolean | undefined) ?? true,
          adhanIsha: (notifs.adhanIsha as boolean | undefined) ?? (notifs.isha as boolean | undefined) ?? true,
          iqamahIsha: (notifs.iqamahIsha as boolean | undefined) ?? (notifs.isha as boolean | undefined) ?? true,
        };

        return {
          ...shell,
          state: {
            ...shell.state,
            appLanguage: normalizeAppLanguage(shell.state.appLanguage),
            themeMode: normalizeThemeMode(shell.state.themeMode),
            fixedTheme: normalizeFixedTheme(shell.state.fixedTheme),
            asrIqamahPreference: normalizeAsrIqamahPreference(shell.state.asrIqamahPreference),
          },
        };
      },
    }
  )
);
