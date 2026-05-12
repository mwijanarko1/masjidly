import { useEffect, useRef, useState } from "react";
import * as Location from "expo-location";
import type { Mosque } from "@/types/prayer";

const KAABA_LATITUDE = 21.4225;
const KAABA_LONGITUDE = 39.8262;
const HEADING_FILTER = 1;
const DEADBAND = 0.5;

function normalizeDegrees(degrees: number): number {
  const remainder = degrees % 360;
  return remainder >= 0 ? remainder : remainder + 360;
}

function bearingDegrees(fromLatitude: number, fromLongitude: number): number {
  const startLat = (fromLatitude * Math.PI) / 180;
  const startLng = (fromLongitude * Math.PI) / 180;
  const destLat = (KAABA_LATITUDE * Math.PI) / 180;
  const destLng = (KAABA_LONGITUDE * Math.PI) / 180;
  const lngDelta = destLng - startLng;

  const y = Math.sin(lngDelta);
  const x =
    Math.cos(startLat) * Math.tan(destLat) -
    Math.sin(startLat) * Math.cos(lngDelta);

  return normalizeDegrees((Math.atan2(y, x) * 180) / Math.PI);
}

function indicatorRotationDegrees(
  qiblaBearing: number,
  heading: number | null,
): number {
  return normalizeDegrees(qiblaBearing - (heading ?? 0));
}

function continuousRotationDegrees(
  previous: number | null,
  target: number,
): number {
  if (previous === null) return target;
  const delta = normalizeDegrees(target - previous + 180) - 180;
  return previous + delta;
}

interface UseQiblaDirectionOptions {
  fallbackMosque?: Mosque | null;
  enabled?: boolean;
}

export function useQiblaDirection({
  fallbackMosque,
  enabled = true,
}: UseQiblaDirectionOptions = {}) {
  const [rotationDegrees, setRotationDegrees] = useState<number | null>(null);
  const [headingAvailable, setHeadingAvailable] = useState(false);

  const currentLocation = useRef<{ latitude: number; longitude: number } | null>(null);
  const headingDegrees = useRef<number | null>(null);
  const displayedRotation = useRef<number | null>(null);
  const fallbackMosqueRef = useRef(fallbackMosque);
  const enabledRef = useRef(enabled);

  fallbackMosqueRef.current = fallbackMosque;
  enabledRef.current = enabled;

  const updateDisplayedRotation = useRef(() => {
    if (!enabledRef.current) return;

    const coordinates = currentLocation.current ?? null;
    const fallback = fallbackMosqueRef.current;

    // Use GPS location if available, otherwise fallback to mosque coordinates
    const lat = coordinates?.latitude ?? fallback?.lat ?? null;
    const lng = coordinates?.longitude ?? fallback?.lng ?? null;

    if (lat === null || lng === null) return;

    const bearing = bearingDegrees(lat, lng);
    const targetRotation = indicatorRotationDegrees(bearing, headingDegrees.current);
    const continuous = continuousRotationDegrees(displayedRotation.current, targetRotation);

    if (
      displayedRotation.current === null ||
      Math.abs(continuous - displayedRotation.current) >= DEADBAND
    ) {
      displayedRotation.current = continuous;
      setRotationDegrees(continuous);
    }
  }).current;

  useEffect(() => {
    if (!enabled) return;

    let headingSub: Location.LocationSubscription | null = null;
    let locationSub: Location.LocationSubscription | null = null;
    let mounted = true;

    async function setup() {
      const { status } = await Location.requestForegroundPermissionsAsync();

      if (status !== "granted") {
        // No GPS - use mosque coordinates as fallback for bearing
        // heading may still be available on iOS
        updateDisplayedRotation();
        return;
      }

      // Get initial position
      try {
        const loc = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.HundredMeters,
        });
        if (!mounted) return;
        currentLocation.current = {
          latitude: loc.coords.latitude,
          longitude: loc.coords.longitude,
        };
        updateDisplayedRotation();
      } catch {
        // Location failed - fall through to heading-only mode
      }

      if (!mounted) return;

      // Watch position for changes
      locationSub = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.HundredMeters,
          distanceInterval: 250,
        },
        (location) => {
          currentLocation.current = {
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
          };
          updateDisplayedRotation();
        },
      );

      // Watch compass heading
      try {
        headingSub = await Location.watchHeadingAsync((heading) => {
          const h =
            heading.trueHeading >= 0
              ? heading.trueHeading
              : heading.magHeading;
          headingDegrees.current = h;
          setHeadingAvailable(true);
          updateDisplayedRotation();
        });
      } catch {
        // Heading not available on this device (Android mostly)
      }
    }

    setup();

    return () => {
      mounted = false;
      if (headingSub) headingSub.remove();
      if (locationSub) locationSub.remove();
    };
  }, [enabled, updateDisplayedRotation]);

  // Update when fallback mosque changes
  useEffect(() => {
    updateDisplayedRotation();
  }, [fallbackMosque, updateDisplayedRotation]);

  return { rotationDegrees, headingAvailable };
}
