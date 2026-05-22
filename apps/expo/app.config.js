const appJson = require("./app.json");

/** @type {import('expo/config').ExpoConfig} */
module.exports = () => ({
  expo: {
    ...appJson.expo,
    // Prevent native builds / Expo Go from trying EAS OTA during local `expo start`.
    // See: https://github.com/expo/expo/issues/17461
    updates: {
      enabled: false,
      checkAutomatically: "ON_ERROR_RECOVERY",
      fallbackToCacheTimeout: 0,
    },
    extra: {
      ...appJson.expo.extra,
      convexUrl:
        process.env.EXPO_PUBLIC_CONVEX_URL ?? appJson.expo.extra?.convexUrl,
    },
  },
});
