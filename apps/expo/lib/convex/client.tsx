import { ConvexReactClient, ConvexProvider, useQuery } from "convex/react";
import React from "react";
import { anyApi } from "convex/server";

export const convexClient = new ConvexReactClient(
  process.env.EXPO_PUBLIC_CONVEX_URL!,
  { unsavedChangesWarning: false }
);

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
