import AsyncStorage from "@react-native-async-storage/async-storage";
import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";

export interface NotificationSettings {
  masterEnabled: boolean;
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
  appLanguage: "system" | "english" | "arabic" | "urdu";
  notifications: NotificationSettings;
  // actions
  setSelectedMosque: (id: string, slug: string) => void;
  setUses24HourTime: (v: boolean) => void;
  setAppLanguage: (v: SettingsState["appLanguage"]) => void;
  setNotificationMaster: (v: boolean) => void;
  setNotificationPrayer: (
    prayer: keyof Omit<NotificationSettings, "masterEnabled">,
    v: boolean
  ) => void;
  resetSettings: () => void;
}

const defaultNotifications: NotificationSettings = {
  masterEnabled: false,
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
  | "setAppLanguage"
  | "setNotificationMaster"
  | "setNotificationPrayer"
  | "resetSettings"
> = {
  selectedMosqueId: undefined,
  selectedMosqueSlug: undefined,
  uses24HourTime: false,
  appLanguage: "system",
  notifications: defaultNotifications,
};

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      ...initialState,
      setSelectedMosque: (id, slug) =>
        set({ selectedMosqueId: id, selectedMosqueSlug: slug }),
      setUses24HourTime: (v) => set({ uses24HourTime: v }),
      setAppLanguage: (v) => set({ appLanguage: v }),
      setNotificationMaster: (v) =>
        set((state) => ({
          notifications: { ...state.notifications, masterEnabled: v },
        })),
      setNotificationPrayer: (prayer, v) =>
        set((state) => ({
          notifications: { ...state.notifications, [prayer]: v },
        })),
      resetSettings: () => set({ ...initialState }),
    }),
    {
      name: "masjidly-settings",
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);
