import { ConvexReactClient, ConvexProvider, useQuery } from "convex/react";
import Constants from "expo-constants";
import React from "react";
import { anyApi } from "convex/server";

const DEFAULT_CONVEX_URL = "https://upbeat-goat-583.eu-west-1.convex.cloud";

function resolveConvexUrl(): string {
  const fromEnv = process.env.EXPO_PUBLIC_CONVEX_URL;
  const fromExtra = (
    Constants.expoConfig?.extra as { convexUrl?: string } | undefined
  )?.convexUrl;

  const configuredUrl =
    fromEnv?.startsWith("https://") ? fromEnv : fromExtra?.startsWith("https://") ? fromExtra : null;

  if (configuredUrl) {
    return configuredUrl;
  }

  if (__DEV__) {
    console.warn(
      "[Masjidly] EXPO_PUBLIC_CONVEX_URL missing from bundle; using default Convex deployment."
    );
  }

  return DEFAULT_CONVEX_URL;
}

export const convexClient = new ConvexReactClient(resolveConvexUrl(), {
  unsavedChangesWarning: false,
});

export const MasjidlyConvexProvider: React.FC<{
  children: React.ReactNode;
}> = ({ children }) => {
  return <ConvexProvider client={convexClient}>{children}</ConvexProvider>;
};

/** Convenience API references for Masjidly Convex functions. */
export const api = {
  mosques: {
    list: anyApi.mosques.list,
  },
  prayerTimes: {
    getMonthly: anyApi.prayerTimes.getMonthly,
    getRamadan: anyApi.prayerTimes.getRamadan,
    getUkDstDates: anyApi.prayerTimes.getUkDstDates,
  },
};

/** Re-export of convex/react useQuery for reactive reads. */
export { useQuery as useConvexQuery };
