import { Stack } from "expo-router";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { useEffect } from "react";
import { View, ActivityIndicator } from "react-native";
import { useFonts } from "expo-font";
import {
  Comfortaa_300Light,
  Comfortaa_400Regular,
  Comfortaa_500Medium,
  Comfortaa_600SemiBold,
} from "@expo-google-fonts/comfortaa";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { MasjidlyConvexProvider } from "@/lib/convex/client";
import { useRouter } from "expo-router";
import { COLORS } from "@/constants";

function useNotificationResponseListener() {
  const router = useRouter();
  useEffect(() => {
    let subscription: { remove: () => void } | null = null;

    import("expo-notifications/build/NotificationsEmitter")
      .then((NotificationsEmitter) => {
        subscription =
          NotificationsEmitter.addNotificationResponseReceivedListener(
          (response: any) => {
            const data = response.notification.request.content.data;
            if (!data || typeof data !== "object") return;
            const kind = data.kind;
            if (kind === "adhan" || kind === "iqamah") {
              router.replace("/");
            } else if (kind === "reminder") {
              const prayer = data.prayer;
              if (prayer === "jummah" || prayer === "dhuhr") {
                router.replace("/timetable");
              } else {
                router.replace("/");
              }
            }
          }
        );
      })
      .catch(() => {
        // NotificationsEmitter unavailable in this environment
      });

    return () => {
      subscription?.remove();
    };
  }, [router]);
}

export default function RootLayout() {
  useNotificationResponseListener();

  const [fontsLoaded] = useFonts({
    Comfortaa_300Light,
    Comfortaa_400Regular,
    Comfortaa_500Medium,
    Comfortaa_600SemiBold,
  });

  if (!fontsLoaded) {
    return (
      <View style={{ flex: 1, justifyContent: "center", alignItems: "center", backgroundColor: COLORS.background }}>
        <ActivityIndicator size="large" color={COLORS.accent} />
      </View>
    );
  }

  return (
    <ErrorBoundary>
      <SafeAreaProvider>
        <MasjidlyConvexProvider>
          <Stack>
            <Stack.Screen name="index" options={{ headerShown: false }} />
            <Stack.Screen
              name="timetable"
              options={{ presentation: "modal", headerShown: false }}
            />
            <Stack.Screen
              name="settings"
              options={{ presentation: "modal", headerShown: false }}
            />
          </Stack>
        </MasjidlyConvexProvider>
      </SafeAreaProvider>
    </ErrorBoundary>
  );
}
