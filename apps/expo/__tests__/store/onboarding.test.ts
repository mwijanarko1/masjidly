/**
 * @jest-environment node
 */

import { act } from "react";
import { useOnboardingStore } from "@/store/onboarding";
import { useSettingsStore } from "@/store/settings";
import { prayerRepository } from "@/lib/prayer/prayerRepository";
import {
  requestNotificationAuthorizationIfNeeded,
  rescheduleUpcomingPrayerNotifications,
  cancelAllPrayerNotifications,
} from "@/lib/notifications/prayerNotifications";

jest.mock("@react-native-async-storage/async-storage", () => ({
  setItem: jest.fn(),
  getItem: jest.fn(() => Promise.resolve(null)),
  removeItem: jest.fn(),
}));

jest.mock("@/lib/prayer/prayerRepository", () => ({
  prayerRepository: {
    listMosques: jest.fn(),
  },
}));

jest.mock("@/lib/notifications/prayerNotifications", () => ({
  requestNotificationAuthorizationIfNeeded: jest.fn(),
  rescheduleUpcomingPrayerNotifications: jest.fn(),
  cancelAllPrayerNotifications: jest.fn(),
}));

const mockedRepository = jest.mocked(prayerRepository);
const mockedRequestAuthorization = jest.mocked(requestNotificationAuthorizationIfNeeded);
const mockedReschedule = jest.mocked(rescheduleUpcomingPrayerNotifications);
const mockedCancel = jest.mocked(cancelAllPrayerNotifications);

const mosque = {
  id: "1",
  name: "Test Mosque",
  address: "123 Test St",
  lat: 53.38,
  lng: -1.47,
  slug: "test-mosque",
  website: null,
  isHidden: false,
  isHiddenResolved: false,
};

const defaultSettingsState = {
  selectedMosqueId: "1",
  selectedMosqueSlug: "test-mosque",
  selectedCityGroupingKey: undefined,
  uses24HourTime: false,
  hideQiblaCompass: false,
  hasCompletedOnboarding: false,
  lastSeenBuildVersion: undefined,
  appLanguage: "en" as const,
  themeMode: "dynamic" as const,
  fixedTheme: "fajr" as const,
  notifications: {
    masterEnabled: false,
    adhanEnabled: true,
    iqamahEnabled: true,
    preAdhanReminderMinutes: null as number | null,
    preIqamahReminderMinutes: null as number | null,
    fajr: true,
    dhuhrJummah: true,
    asr: true,
    maghrib: true,
    isha: true,
  },
};

describe("Onboarding notification setup", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedRepository.listMosques.mockResolvedValue([mosque]);
    mockedRequestAuthorization.mockResolvedValue(true);
    mockedReschedule.mockResolvedValue(undefined);
    mockedCancel.mockResolvedValue(undefined);

    act(() => {
      useSettingsStore.setState(defaultSettingsState);
      useOnboardingStore.setState({
        currentStep: { type: "notifications" },
        selectedMosqueId: "1",
        notificationDraft: {
          adhanEnabled: true,
          iqamahEnabled: false,
          preAdhanReminderMinutes: 10,
          preIqamahReminderMinutes: null,
          fajr: true,
          dhuhrJummah: true,
          asr: true,
          maghrib: true,
          isha: true,
        },
        isCompletingNotifications: false,
      });
    });
  });

  it("persists masterEnabled and schedules with the user's tutorial choices", async () => {
    await act(async () => {
      await useOnboardingStore.getState().completeNotificationSetup();
    });

    const notifications = useSettingsStore.getState().notifications;
    expect(notifications).toMatchObject({
      masterEnabled: true,
      adhanEnabled: true,
      iqamahEnabled: false,
      preAdhanReminderMinutes: 10,
      preIqamahReminderMinutes: null,
    });
    expect(mockedRequestAuthorization).toHaveBeenCalled();
    expect(mockedReschedule).toHaveBeenCalledWith({
      mosque,
      settings: expect.objectContaining({
        masterEnabled: true,
        adhanEnabled: true,
        iqamahEnabled: false,
        preAdhanReminderMinutes: 10,
      }),
      locale: "en",
    });
    expect(useSettingsStore.getState().hasCompletedOnboarding).toBe(true);
    expect(useOnboardingStore.getState().currentStep).toBeNull();
  });

  it("turns master off and cancels when every tutorial notification option is off", async () => {
    act(() => {
      useOnboardingStore.setState({
        notificationDraft: {
          adhanEnabled: false,
          iqamahEnabled: false,
          preAdhanReminderMinutes: null,
          preIqamahReminderMinutes: null,
          fajr: false,
          dhuhrJummah: false,
          asr: false,
          maghrib: false,
          isha: false,
        },
      });
    });

    await act(async () => {
      await useOnboardingStore.getState().completeNotificationSetup();
    });

    expect(useSettingsStore.getState().notifications.masterEnabled).toBe(false);
    expect(mockedCancel).toHaveBeenCalled();
    expect(mockedReschedule).not.toHaveBeenCalled();
  });
});
