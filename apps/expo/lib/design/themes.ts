export type ThemeMode = "dynamic" | "fixed";

export type TimeTheme =
  | "fajr"
  | "sunrise"
  | "dhuhr"
  | "asr"
  | "maghrib"
  | "isha"
  | "tahajjud";

export interface SkyTheme {
  baseColors: string[];
  glowColor: string | null;
  /** Scales horizon glow like SwiftUI `glowColor.opacity(...)` before radial stops (e.g. dhuhr 0.2, isha 0.4). */
  glowBaseAlpha?: number;
}

const themes: Record<TimeTheme, SkyTheme> = {
  fajr: {
    baseColors: ["#020326", "#06114F", "#0B1E6D", "#3B2A5A"],
    glowColor: "#F08A4B",
  },
  sunrise: {
    baseColors: ["#6B7280", "#C084FC", "#FB923C", "#F59E0B"],
    glowColor: "#FEF08A",
  },
  dhuhr: {
    baseColors: ["#E0F2FE", "#7DD3FC", "#38BDF8"],
    glowColor: "#38BDF8",
    glowBaseAlpha: 0.2,
  },
  asr: {
    baseColors: ["#93C5FD", "#FDE68A", "#FDBA74"],
    glowColor: "#D6B38A",
  },
  maghrib: {
    baseColors: ["#6D3FA9", "#A855F7", "#F472B6", "#FB7185"],
    glowColor: "#F59E0B",
  },
  isha: {
    baseColors: ["#000000", "#020617", "#0F172A"],
    glowColor: "#0F172A",
    glowBaseAlpha: 0.4,
  },
  tahajjud: {
    baseColors: ["#000000", "#01030A", "#020617"],
    glowColor: null,
  },
};

export function getSkyTheme(theme: TimeTheme): SkyTheme {
  return themes[theme];
}

export function getTextColor(theme: TimeTheme): string {
  switch (theme) {
    case "fajr":
    case "maghrib":
    case "isha":
    case "tahajjud":
      return "#FFFFFF";
    default:
      return "#111111";
  }
}

export function getIconColor(theme: TimeTheme): string {
  return getTextColor(theme);
}

export function getUsesLightForeground(theme: TimeTheme): boolean {
  switch (theme) {
    case "fajr":
    case "maghrib":
    case "isha":
    case "tahajjud":
      return true;
    default:
      return false;
  }
}

export const SELECTABLE_PRAYER_THEMES: TimeTheme[] = [
  "fajr",
  "sunrise",
  "dhuhr",
  "asr",
  "maghrib",
  "isha",
];

export const PRAYER_THEMES: Record<string, TimeTheme> = {
  Fajr: "fajr",
  Sunrise: "sunrise",
  Dhuhr: "dhuhr",
  Jummah: "dhuhr",
  Asr: "asr",
  Maghrib: "maghrib",
  Isha: "isha",
};

export function themeForPrayer(prayerName: string): TimeTheme {
  return PRAYER_THEMES[prayerName] ?? "fajr";
}

export function resolveTheme(
  dynamicTheme: TimeTheme,
  themeMode: ThemeMode,
  fixedTheme: TimeTheme
): TimeTheme {
  return themeMode === "dynamic" ? dynamicTheme : fixedTheme;
}

export const ACCENT = "#47A6FF";
export const ACCENT_DEEP = "#2E8DFF";
export const SUCCESS = "#58D66D";
