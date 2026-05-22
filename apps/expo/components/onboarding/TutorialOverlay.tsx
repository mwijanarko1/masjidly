import React from "react";
import * as Location from "expo-location";
import { useOnboardingStore } from "@/store/onboarding";
import { CoachMarkCard } from "./CoachMarkCard";
import { MosqueSelectionCard } from "./MosqueSelectionCard";
import { NotificationSetupCard } from "./NotificationSetupCard";
import type { TimeTheme } from "@/lib/design/themes";
import type { Mosque } from "@/types/prayer";
import type { AppLanguage } from "@/store/settings";
import { t, type TranslationKey } from "@/lib/i18n/translations";

// ---------------------------------------------------------------------------
// Prayer names for shortcut coach marks
// ---------------------------------------------------------------------------

const SHORTCUT_PRAYERS: { letter: string; name: string }[] = [
  { letter: "F", name: "Fajr" },
  { letter: "S", name: "Sunrise" },
  { letter: "D", name: "Dhuhr" },
  { letter: "A", name: "Asr" },
  { letter: "M", name: "Maghrib" },
  { letter: "I", name: "Isha" },
];

function shortcutMessage(index: number, locale: AppLanguage): string {
  const p = SHORTCUT_PRAYERS[index];
  if (!p) return "";
  return t("onboarding.shortcut.message_format", locale)
    .replace("%s", p.letter)
    .replace("%s", t(prayerKeyForName(p.name), locale));
}

function shortcutTitle(_index: number, locale: AppLanguage): string {
  return t("onboarding.shortcut.title", locale);
}

function prayerKeyForName(name: string): TranslationKey {
  const key = name.toLowerCase() as "fajr" | "sunrise" | "dhuhr" | "asr" | "maghrib" | "isha";
  return `prayer.${key}` as TranslationKey;
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export type OverlayScreen = "home" | "timetable" | "settings";

interface TutorialOverlayProps {
  screen: OverlayScreen;
  mosques: Mosque[];
  theme: TimeTheme;
  textColor: string;
  usesLightForeground: boolean;
  locale: AppLanguage;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function TutorialOverlay({
  screen,
  mosques,
  theme,
  textColor,
  usesLightForeground,
  locale,
}: TutorialOverlayProps) {
  const currentStep = useOnboardingStore((s) => s.currentStep);
  const selectedMosqueId = useOnboardingStore((s) => s.selectedMosqueId);
  const notificationDraft = useOnboardingStore((s) => s.notificationDraft);
  const isCompletingNotifications = useOnboardingStore(
    (s) => s.isCompletingNotifications
  );
  const selectMosque = useOnboardingStore((s) => s.selectMosque);
  const completeQiblaOnboardingAllowingLocationRequest = useOnboardingStore(
    (s) => s.completeQiblaOnboardingAllowingLocationRequest
  );
  const completeQiblaOnboardingDeferringLocation = useOnboardingStore(
    (s) => s.completeQiblaOnboardingDeferringLocation
  );
  const acknowledgeTimetableExplore = useOnboardingStore(
    (s) => s.acknowledgeTimetableExplore
  );
  const acknowledgeSettingsExplore = useOnboardingStore(
    (s) => s.acknowledgeSettingsExplore
  );
  const completeNotificationSetup = useOnboardingStore(
    (s) => s.completeNotificationSetup
  );

  if (!currentStep) return null;

  // ----- Home screen overlays -----
  if (screen === "home") {
    switch (currentStep.type) {
      case "chooseMosque":
        return (
          <MosqueSelectionCard
            mosques={mosques}
            selectedMosqueId={selectedMosqueId}
            onSelect={(id) =>
              useOnboardingStore.setState({ selectedMosqueId: id })
            }
            onContinue={async () => {
              await selectMosque(selectedMosqueId);
            }}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
            locale={locale}
          />
        );

      case "prayerShortcut":
        return (
          <CoachMarkCard
            title={shortcutTitle(currentStep.index, locale)}
            message={shortcutMessage(currentStep.index, locale)}
            variant="aboveShortcutRow"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "qibla":
        return (
          <CoachMarkCard
            title={t("onboarding.qibla.title", locale)}
            message={t("onboarding.qibla.message", locale)}
            variant="belowQiblaIcon"
            primaryButtonTitle={t("onboarding.qibla.allow_location", locale)}
            onPrimaryButton={() => {
              Location.requestForegroundPermissionsAsync().finally(() => {
                completeQiblaOnboardingAllowingLocationRequest();
              });
            }}
            secondaryButtonTitle={t("onboarding.qibla.later", locale)}
            onSecondaryButton={completeQiblaOnboardingDeferringLocation}
            accessibilityIdentifier="Onboarding.QiblaAllow"
            secondaryAccessibilityIdentifier="Onboarding.QiblaLater"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "openTimetable":
        return (
          <CoachMarkCard
            title={t("onboarding.timetable.title", locale)}
            message={t("onboarding.timetable.message", locale)}
            variant="belowTopChrome"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "openSettings":
        return (
          <CoachMarkCard
            title={t("onboarding.settings.title", locale)}
            message={t("onboarding.settings.message", locale)}
            variant="belowTopChrome"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "notifications":
        return (
          <NotificationSetupCard
            draft={notificationDraft}
            isSaving={isCompletingNotifications}
            onAdhanChange={(v) =>
              useOnboardingStore.setState({
                notificationDraft: { ...notificationDraft, adhanEnabled: v },
              })
            }
            onIqamahChange={(v) =>
              useOnboardingStore.setState({
                notificationDraft: { ...notificationDraft, iqamahEnabled: v },
              })
            }
            onAdhanReminderChange={(v) =>
              useOnboardingStore.setState({
                notificationDraft: {
                  ...notificationDraft,
                  preAdhanReminderMinutes: v,
                },
              })
            }
            onIqamahReminderChange={(v) =>
              useOnboardingStore.setState({
                notificationDraft: {
                  ...notificationDraft,
                  preIqamahReminderMinutes: v,
                },
              })
            }
            onFinish={completeNotificationSetup}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
            locale={locale}
          />
        );

      default:
        return null;
    }
  }

  // ----- Timetable screen overlays -----
  if (screen === "timetable") {
    switch (currentStep.type) {
      case "exploreTimetable":
        return (
          <CoachMarkCard
            title={t("onboarding.explore_timetable.title", locale)}
            message={t("onboarding.explore_timetable.message", locale)}
            variant="floatingBottom"
            primaryButtonTitle={t("onboarding.continue", locale)}
            onPrimaryButton={acknowledgeTimetableExplore}
            accessibilityIdentifier="Onboarding.TimetableExploreContinue"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "closeTimetable":
        return (
          <CoachMarkCard
            title={t("onboarding.explore_timetable.title", locale)}
            message={t("onboarding.close_timetable.message", locale)}
            variant="belowTopChrome"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      default:
        return null;
    }
  }

  // ----- Settings screen overlays -----
  if (screen === "settings") {
    switch (currentStep.type) {
      case "exploreSettings":
        return (
          <CoachMarkCard
            title={t("onboarding.explore_settings.title", locale)}
            message={t("onboarding.explore_settings.message", locale)}
            variant="floatingBottom"
            primaryButtonTitle={t("onboarding.continue", locale)}
            onPrimaryButton={acknowledgeSettingsExplore}
            accessibilityIdentifier="Onboarding.SettingsExploreContinue"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "closeSettings":
        return (
          <CoachMarkCard
            title={t("onboarding.explore_settings.title", locale)}
            message={t("onboarding.close_settings.message", locale)}
            variant="belowTopChrome"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      default:
        return null;
    }
  }

  return null;
}
