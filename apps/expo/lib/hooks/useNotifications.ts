import { useEffect, useState } from 'react';
import * as Notifications from 'expo-notifications';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: false,
    shouldSetBadge: false,
  }),
});

interface UseNotificationsReturn {
  /** The Expo push token for this device, or undefined while loading or if permissions are denied. */
  expoPushToken: string | undefined;
  /** Whether the push token is still being fetched. */
  isLoadingToken: boolean;
  /**
   * Schedules a local notification to fire after a delay.
   * @param title - The notification title.
   * @param body - The notification body text.
   * @param seconds - Delay in seconds before the notification fires. Defaults to 1.
   */
  scheduleNotification: (title: string, body: string, seconds?: number) => Promise<void>;
}

/**
 * Handles push notification permission requests and token registration.
 * Also provides a helper for scheduling local notifications.
 *
 * @returns {@link UseNotificationsReturn}
 */
export function useNotifications(): UseNotificationsReturn {
  const [expoPushToken, setExpoPushToken] = useState<string | undefined>();
  const [isLoadingToken, setIsLoadingToken] = useState(true);

  useEffect(() => {
    registerForPushNotificationsAsync()
      .then(token => setExpoPushToken(token))
      .finally(() => setIsLoadingToken(false));
  }, []);

  const scheduleNotification = async (title: string, body: string, seconds = 1) => {
    await Notifications.scheduleNotificationAsync({
      content: { title, body },
      trigger: { seconds },
    });
  };

  return { expoPushToken, isLoadingToken, scheduleNotification };
}

/**
 * Requests push notification permissions and retrieves the Expo push token.
 *
 * @returns The Expo push token string, or undefined if permissions were denied.
 */
async function registerForPushNotificationsAsync(): Promise<string | undefined> {
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  if (finalStatus !== 'granted') {
    if (__DEV__) {
      console.warn('Push notification permissions not granted.');
    }
    return undefined;
  }

  return (await Notifications.getExpoPushTokenAsync()).data;
}
