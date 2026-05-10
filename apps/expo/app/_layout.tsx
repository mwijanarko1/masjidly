import { Stack } from "expo-router";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { MasjidlyConvexProvider } from "@/lib/convex/client";

export default function RootLayout() {
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
