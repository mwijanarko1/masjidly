import { useEffect, useRef, useState } from "react";
import { Animated, Easing } from "react-native";
import * as Location from "expo-location";
import type { Mosque } from "@/types/prayer";

const KAABA_LATITUDE = 21.4225;
const KAABA_LONGITUDE = 39.8262;
const HEADING_FILTER_DEGREES = 1;
const ROTATION_DEADBAND_DEGREES = 0.5;
// Matches iOS QiblaPrayerIcon `.animation(.easeOut(duration: 0.2), value:)`.
const ANIMATION_DURATION_MS = 200;

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

function shortestSignedDeltaDegrees(from: number, to: number): number {
  return normalizeDegrees(to - from + 180) - 180;
}

function continuousRotationDegrees(
  previous: number | null,
  target: number,
): number {
  if (previous === null) return target;
  return previous + shortestSignedDeltaDegrees(previous, target);
}

interface UseQiblaDirectionOptions {
  fallbackMosque?: Mosque | null;
  enabled?: boolean;
  deferAuthorization?: boolean;
}

export function useQiblaDirection({
  fallbackMosque,
  enabled = true,
  deferAuthorization = false,
}: UseQiblaDirectionOptions = {}) {
  // Animated value for native-driver rotation — completely decoupled from React render cycle.
  const animatedRotation = useRef(new Animated.Value(0)).current;

  const [headingAvailable, setHeadingAvailable] = useState(false);

  const currentLocation = useRef<{ latitude: number; longitude: number } | null>(null);
  const headingDegrees = useRef<number | null>(null);
  const displayedRotation = useRef<number | null>(null);
  const lastProcessedHeading = useRef<number | null>(null);
  const fallbackMosqueRef = useRef(fallbackMosque);
  const enabledRef = useRef(enabled);

  fallbackMosqueRef.current = fallbackMosque;
  enabledRef.current = enabled;

  const updateDisplayedRotation = useRef(() => {
    if (!enabledRef.current) return;

    const coordinates = currentLocation.current ?? null;
    const fallback = fallbackMosqueRef.current;

    const lat = coordinates?.latitude ?? fallback?.lat ?? null;
    const lng = coordinates?.longitude ?? fallback?.lng ?? null;

    if (lat === null || lng === null) return;

    const bearing = bearingDegrees(lat, lng);
    const targetRotation = indicatorRotationDegrees(bearing, headingDegrees.current);
    const continuous = continuousRotationDegrees(displayedRotation.current, targetRotation);

    const isFirstRotation = displayedRotation.current === null;
    const rotationChangedEnough =
      displayedRotation.current !== null &&
      Math.abs(continuous - displayedRotation.current) >= ROTATION_DEADBAND_DEGREES;

    if (isFirstRotation || rotationChangedEnough) {
      displayedRotation.current = continuous;

      if (isFirstRotation) {
        animatedRotation.setValue(continuous);
      } else {
        // iOS eases each heading step; do not stopAnimation() — that caused jank.
        Animated.timing(animatedRotation, {
          toValue: continuous,
          duration: ANIMATION_DURATION_MS,
          easing: Easing.out(Easing.ease),
          useNativeDriver: true,
          isInteraction: false,
        }).start();
      }
    }
  }).current;

  useEffect(() => {
    if (!enabled) return;

    let headingSub: Location.LocationSubscription | null = null;
    let locationSub: Location.LocationSubscription | null = null;
    let mounted = true;
    let headingInitialised = false; // Only set headingAvailable once to avoid redundant re-renders

    async function setup() {
      let permission = await Location.getForegroundPermissionsAsync();

      if (permission.status === "undetermined" && !deferAuthorization) {
        permission = await Location.requestForegroundPermissionsAsync();
      }

      if (permission.status === "granted") {
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
          // Location failed — fall through to fallback-mosque + heading mode
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
      } else {
        // Native iOS still displays/rotates against fallback mosque coordinates when
        // precise device location is unavailable.
        updateDisplayedRotation();
      }

      // Watch compass heading independently of location authorization, matching native iOS.
      try {
        headingSub = await Location.watchHeadingAsync((heading) => {
          // Expo accuracy 0 means "poor calibration", not "no heading". Android
          // production builds can report 0 forever, so keep the sample.
          const h = heading.trueHeading >= 0 ? heading.trueHeading : heading.magHeading;
          if (!Number.isFinite(h)) return;
          const last = lastProcessedHeading.current;

          // Match iOS headingFilter = 1: ignore sub-degree sensor noise.
          if (
            last !== null &&
            Math.abs(shortestSignedDeltaDegrees(last, h)) < HEADING_FILTER_DEGREES
          ) {
            return;
          }

          lastProcessedHeading.current = h;
          headingDegrees.current = h;

          // Only update headingAvailable state once (matches iOS — no separate "available" concept)
          if (!headingInitialised) {
            headingInitialised = true;
            setHeadingAvailable(true);
          }

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
  }, [enabled, deferAuthorization, updateDisplayedRotation]);

  // Update when fallback mosque changes
  useEffect(() => {
    updateDisplayedRotation();
  }, [fallbackMosque, updateDisplayedRotation]);

  return { animatedRotation, headingAvailable };
}
