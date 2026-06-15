import React from "react";
import {
  StyleSheet,
  Text,
  View,
  type TextStyle,
  type ViewStyle,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import * as Location from "expo-location";
import { useOnboardingStore } from "@/store/onboarding";
import { CoachMarkCard } from "./CoachMarkCard";
import { MosqueSelectionCard } from "./MosqueSelectionCard";
import { NotificationSetupCard } from "./NotificationSetupCard";
import { ACCENT, type TimeTheme } from "@/lib/design/themes";
import type { Mosque } from "@/types/prayer";
import { useSettingsStore, type AppLanguage } from "@/store/settings";
import { t } from "@/lib/i18n/translations";

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
  const insets = useSafeAreaInsets();
  const selectedLanguage = useSettingsStore((s) => s.appLanguage);
  const notificationDraft = useOnboardingStore((s) => s.notificationDraft);
  const isCompletingNotifications = useOnboardingStore(
    (s) => s.isCompletingNotifications
  );
  const isSelectingMosque = useOnboardingStore((s) => s.isSelectingMosque);
  const selectLanguage = useOnboardingStore((s) => s.selectLanguage);
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
      case "chooseLanguage":
        return (
          <LanguageSelectionCard
            selectedLanguage={selectedLanguage}
            onContinue={selectLanguage}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

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
            isContinuing={isSelectingMosque}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
            locale={locale}
          />
        );

      case "prayerShortcut":
        return (
          <View style={StyleSheet.absoluteFill} pointerEvents="box-none">
            <CoachMarkCard
              title={t("onboarding.shortcut.title", locale)}
              message={t("onboarding.shortcut.message_format", locale)}
              variant="aboveShortcutRow"
              theme={theme}
              textColor={textColor}
              usesLightForeground={usesLightForeground}
            />
            <View
              style={{
                position: "absolute",
                bottom: insets.bottom + 24,
                left: 0,
                right: 0,
                alignItems: "center",
              }}
              pointerEvents="auto"
            >
              <Pressable
                onPress={() =>
                  useOnboardingStore.getState().skipTutorialToNotifications()
                }
                accessibilityRole="button"
                accessibilityLabel="Skip tutorial"
                accessibilityIdentifier="Onboarding.SkipTutorial"
              >
                <View
                  style={{
                    paddingVertical: 12,
                    paddingHorizontal: 28,
                    borderRadius: 100,
                    borderWidth: 1,
                    borderColor: textColor + "44",
                    alignItems: "center",
                  }}
                >
                  <Text
                    style={{
                      color: textColor,
                      fontSize: 15,
                      fontFamily: "Comfortaa_600SemiBold",
                      opacity: 0.72,
                    }}
                  >
                    Skip tutorial
                  </Text>
                </View>
              </Pressable>
            </View>
          </View>
        );

      case "qiblaCountdown":
        return (
          <CoachMarkCard
            title={t("onboarding.qibla_countdown.title", locale)}
            message={t("onboarding.qibla_countdown.message", locale)}
            variant="belowQiblaIconLower"
            primaryButtonTitle={t("onboarding.continue", locale)}
            onPrimaryButton={() => {
              const cs = useOnboardingStore.getState();
              cs.completeQiblaCountdown();
            }}
            blocksBackgroundInteractions={false}
            accessibilityIdentifier="Onboarding.QiblaCountdownContinue"
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
            variant="belowQiblaIconLower"
            primaryButtonTitle={t("onboarding.qibla.allow_location", locale)}
            onPrimaryButton={() => {
              void Location.requestForegroundPermissionsAsync();
              completeQiblaOnboardingAllowingLocationRequest();
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
            onAdhanPrayerChange={(prayer, value) =>
              useOnboardingStore.setState({
                notificationDraft: {
                  ...notificationDraft,
                  [`adhan${prayer.charAt(0).toUpperCase()}${prayer.slice(1)}`]: value,
                },
              })
            }
            onIqamahPrayerChange={(prayer, value) =>
              useOnboardingStore.setState({
                notificationDraft: {
                  ...notificationDraft,
                  [`iqamah${prayer.charAt(0).toUpperCase()}${prayer.slice(1)}`]: value,
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

const LANGUAGE_OPTIONS: { value: AppLanguage; label: string }[] = [
  { value: "en", label: "English" },
  { value: "ar", label: "العربية" },
  { value: "ur", label: "اردو" },
  { value: "id", label: "Bahasa Indonesia" },
];

function LanguageSelectionCard({
  selectedLanguage,
  onContinue,
  textColor,
  usesLightForeground,
}: {
  selectedLanguage: AppLanguage;
  onContinue: (language: AppLanguage) => void;
  textColor: string;
  usesLightForeground: boolean;
}) {
  const [draftLanguage, setDraftLanguage] = React.useState<AppLanguage>(selectedLanguage);

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="auto">
      <View
        style={[
          StyleSheet.absoluteFill,
          {
            backgroundColor: usesLightForeground
              ? "rgba(0, 0, 0, 0.24)"
              : "rgba(0, 0, 0, 0.13)",
          },
        ]}
      />

      <View style={languageStyles.centerContainer} pointerEvents="box-none">
        <View
          style={[
            languageStyles.glassCard,
            {
              backgroundColor: usesLightForeground ? "rgb(10, 10, 30)" : "rgb(255, 255, 255)",
              borderColor: usesLightForeground ? "rgba(255, 255, 255, 0.15)" : "rgba(240, 240, 240, 0.6)",
              shadowColor: usesLightForeground ? "rgba(0,0,0,0.25)" : "rgba(0,0,0,0.10)",
            },
          ]}
        >
          <Text style={[languageStyles.title, { color: textColor }]}>Choose your language</Text>
          <Text style={[languageStyles.langLine, { color: textColor }]}>اختر لغتك</Text>
          <Text style={[languageStyles.langLine, { color: textColor }]}>اپنی زبان منتخب کریں</Text>
          <Text style={[languageStyles.langLine, { color: textColor }]}>Pilih bahasa</Text>
          <Text style={[languageStyles.message, { color: textColor + "B8" }]}>You can change this later in Settings.</Text>

          <View style={languageStyles.options}>
            {LANGUAGE_OPTIONS.map((option) => {
              const selected = option.value === draftLanguage;
              return (
                <Pressable
                  key={option.value}
                  style={[
                    languageStyles.option,
                    {
                      backgroundColor: selected ? textColor + "24" : textColor + "0D",
                      borderColor: selected ? ACCENT : textColor + "1A",
                    },
                  ]}
                  onPress={() => setDraftLanguage(option.value)}
                  accessibilityRole="button"
                  accessibilityLabel={option.label}
                  accessibilityIdentifier={`Onboarding.Language.${option.value}`}
                >
                  <Text style={[languageStyles.optionText, { color: textColor }]}>{option.label}</Text>
                  <Text style={[languageStyles.checkmark, { color: selected ? ACCENT : "transparent" }]}>✓</Text>
                </Pressable>
              );
            })}
          </View>

          <Pressable
            style={languageStyles.continueButton}
            onPress={() => onContinue(draftLanguage)}
            accessibilityRole="button"
            accessibilityLabel="Continue"
            accessibilityIdentifier="Onboarding.LanguageContinue"
          >
            <Text style={languageStyles.continueButtonText}>Continue</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const languageStyles = StyleSheet.create({
  centerContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 24,
  } as ViewStyle,
  glassCard: {
    width: "100%",
    maxWidth: 400,
    borderRadius: 24,
    padding: 24,
    borderWidth: 1,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.24,
    shadowRadius: 30,
    elevation: 10,
  } as ViewStyle,
  title: {
    fontSize: 23,
    fontFamily: "Comfortaa_600SemiBold",
    letterSpacing: -0.5,
    textAlign: "center",
    marginBottom: 6,
  } as TextStyle,
  langLine: {
    fontSize: 22,
    fontFamily: "Comfortaa_600SemiBold",
    letterSpacing: -0.4,
    textAlign: "center",
  } as TextStyle,
  message: {
    fontSize: 14,
    fontFamily: "Comfortaa_400Regular",
    textAlign: "center",
    marginBottom: 18,
  } as TextStyle,
  options: {
    gap: 10,
    marginBottom: 20,
  } as ViewStyle,
  option: {
    minHeight: 52,
    borderRadius: 16,
    borderWidth: 1,
    paddingHorizontal: 16,
    flexDirection: "row",
    alignItems: "center",
  } as ViewStyle,
  optionText: {
    flex: 1,
    fontSize: 17,
    fontFamily: "Comfortaa_600SemiBold",
  } as TextStyle,
  checkmark: {
    fontSize: 20,
    fontFamily: "Comfortaa_600SemiBold",
  } as TextStyle,
  continueButton: {
    backgroundColor: ACCENT,
    paddingVertical: 16,
    borderRadius: 100,
    alignItems: "center",
    shadowColor: ACCENT,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.35,
    shadowRadius: 15,
    elevation: 6,
  } as ViewStyle,
  continueButtonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontFamily: "Comfortaa_600SemiBold",
  } as TextStyle,
});
