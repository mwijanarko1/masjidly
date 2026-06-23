import { create } from "zustand";

export type SettingsOverlayParams = {
  theme?: string;
};

export type TimetableOverlayParams = {
  theme?: string;
  mosqueName?: string;
  mosqueSlug?: string;
};

type AppOverlay =
  | { type: "settings"; params: SettingsOverlayParams }
  | { type: "timetable"; params: TimetableOverlayParams };

type AppOverlayState = {
  overlay: AppOverlay | null;
  openSettings: (params?: SettingsOverlayParams) => void;
  openTimetable: (params?: TimetableOverlayParams) => void;
  close: () => void;
};

export const useAppOverlayStore = create<AppOverlayState>((set) => ({
  overlay: null,
  openSettings: (params = {}) => set({ overlay: { type: "settings", params } }),
  openTimetable: (params = {}) => set({ overlay: { type: "timetable", params } }),
  close: () => set({ overlay: null }),
}));
