import { Platform } from "react-native";
import Constants from "expo-constants";
import * as Linking from "expo-linking";

/**
 * Schema for the version manifest served at
 * https://sheffieldmasjids.com/masjidly/latest.json
 */
export interface MasjidlyRelease {
  android: {
    version: string;
    versionCode: number;
    url: string;
    sha256: string;
    minVersionCode: number;
  };
  ios: {
    version: string;
    build: number;
    appStoreUrl: string;
  };
  pub_date: string;
  notes: {
    en: string;
    ar: string;
    ur: string;
    id: string;
  };
}

export interface UpdateInfo {
  /** Whether a newer version is available */
  updateAvailable: boolean;
  /** The latest release info (or null if fetch failed) */
  release: MasjidlyRelease | null;
  /** Human-readable error message if fetch failed */
  error: string | null;
}

const LATEST_JSON_URL =
  "https://sheffieldmasjids.com/masjidly/latest.json";

const FETCH_TIMEOUT_MS = 10_000;

/**
 * Fetches the latest release manifest from the website.
 * Returns null if the fetch fails or times out.
 */
async function fetchLatestRelease(): Promise<MasjidlyRelease | null> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    const response = await fetch(LATEST_JSON_URL, {
      signal: controller.signal,
      headers: { Accept: "application/json" },
    });
    clearTimeout(timeout);

    if (!response.ok) {
      console.warn(
        `[updateChecker] HTTP ${response.status}: ${response.statusText}`
      );
      return null;
    }

    const data: MasjidlyRelease = await response.json();
    return data;
  } catch (err) {
    console.warn("[updateChecker] Failed to fetch latest.json:", err);
    return null;
  }
}

/**
 * Gets the current app's version code for Android.
 */
function currentVersionCode(): number | null {
  const android = Constants.expoConfig?.android;
  if (android?.versionCode != null) {
    return android.versionCode;
  }
  return null;
}

/**
 * Gets the current app's build number for iOS.
 */
function currentBuildNumber(): number | null {
  const nativeBuild = Constants.nativeBuildVersion;
  if (nativeBuild) {
    const parsed = parseInt(nativeBuild, 10);
    if (!isNaN(parsed)) return parsed;
  }
  return null;
}

/**
 * Checks whether an update is available for the current platform.
 *
 * - On **Android**: compares `versionCode` against the manifest's `versionCode`.
 * - On **iOS**: compares `build number` against the manifest's `build`.
 *
 * Returns an `UpdateInfo` object. Even if the fetch fails, you get
 * `{ updateAvailable: false, release: null, error: "..." }`.
 */
export async function checkForUpdate(): Promise<UpdateInfo> {
  const release = await fetchLatestRelease();

  if (!release) {
    return {
      updateAvailable: false,
      release: null,
      error: "Could not fetch latest version info.",
    };
  }

  if (Platform.OS === "android") {
    const current = currentVersionCode();
    if (current == null) {
      return {
        updateAvailable: false,
        release,
        error: "Could not determine current Android versionCode.",
      };
    }
    return {
      updateAvailable: release.android.versionCode > current,
      release,
      error: null,
    };
  }

  if (Platform.OS === "ios") {
    const current = currentBuildNumber();
    if (current == null) {
      return {
        updateAvailable: false,
        release,
        error: "Could not determine current iOS build number.",
      };
    }
    return {
      updateAvailable: release.ios.build > current,
      release,
      error: null,
    };
  }

  return {
    updateAvailable: false,
    release,
    error: `Unsupported platform: ${Platform.OS}`,
  };
}

/**
 * Opens the appropriate download/update URL for the platform.
 *
 * - **Android**: returns the APK download URL from the manifest.
 * - **iOS**: returns the App Store page URL from the manifest.
 */
export function getUpdateUrl(release: MasjidlyRelease): string | null {
  if (Platform.OS === "android") {
    return release.android.url;
  }
  if (Platform.OS === "ios") {
    return release.ios.appStoreUrl;
  }
  return null;
}

/**
 * Opens the update URL in the device browser.
 */
export async function openUpdateUrl(release: MasjidlyRelease): Promise<void> {
  const url = getUpdateUrl(release);
  if (url) {
    await Linking.openURL(url);
  }
}
