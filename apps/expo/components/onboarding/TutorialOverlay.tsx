import React from "react";
import { useOnboardingStore } from "@/store/onboarding";
import { CoachMarkCard } from "./CoachMarkCard";
import { MosqueSelectionCard } from "./MosqueSelectionCard";
import { NotificationSetupCard } from "./NotificationSetupCard";
import type { TimeTheme } from "@/lib/design/themes";

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

function shortcutMessage(index: number, locale: string): string {
  const p = SHORTCUT_PRAYERS[index];
  if (!p) return "";
  if (locale === "ar") {
    return `اضغط على ${p.letter} لعرض تفاصيل ${p.name === "Isha" ? "العشاء" : p.name === "Fajr" ? "الفجر" : p.name}`;
  }
  if (locale === "ur") {
    return `${p.name} کی تفصیلات دیکھنے کے لیے ${p.letter} دبائیں`;
  }
  return `Tap ${p.letter} to see ${p.name} details`;
}

function shortcutTitle(_index: number, locale: string): string {
  if (locale === "ar") return "استكشاف أوقات الصلاة";
  if (locale === "ur") return "نماز کے اوقات دریافت کریں";
  return "Explore Prayer Times";
}

// ---------------------------------------------------------------------------
// Strings lookup
// ---------------------------------------------------------------------------

function s(key: string, locale: string): string {
  if (locale === "ar") {
    const m: Record<string, string> = {
      "qibla.title": "اتجاه القبلة",
      "qibla.message": "تعرف على اتجاه القبلة للصلاة",
      "qibla.continue": "متابعة",
      "timetable.title": "جدول المواقيت",
      "timetable.message": "اضغط على أيقونة التقويم لعرض جدول المواقيت الشهري الكامل",
      "explore.timetable.title": "استكشاف جدول المواقيت",
      "explore.timetable.message": "هذا هو جدول المواقيت الشهري الكامل. يمكنك التنقل بين الأيام والأشهر.",
      "explore.timetable.continue": "متابعة",
      "close.timetable.message": "اضغط على زر الإغلاق للعودة إلى الشاشة الرئيسية",
      "settings.title": "الإعدادات",
      "settings.message": "اضغط على أيقونة الإعدادات لتخصيص تجربتك",
      "explore.settings.title": "استكشاف الإعدادات",
      "explore.settings.message": "هنا يمكنك ضبط تفضيلات المسجد والعرض والإشعارات.",
      "explore.settings.continue": "متابعة",
      "close.settings.message": "اضغط على زر الإغلاق للعودة إلى الشاشة الرئيسية",
    };
    return m[key] ?? key;
  }
  if (locale === "ur") {
    const m: Record<string, string> = {
      "qibla.title": "قبلہ سمت",
      "qibla.message": "نماز کے لیے قبلہ کی سمت دریافت کریں",
      "qibla.continue": "جاری رکھیں",
      "timetable.title": "نظام الاوقات",
      "timetable.message": "مکمل ماہانہ نظام الاوقات دیکھنے کے لیے کیلنڈر آئیکن دبائیں",
      "explore.timetable.title": "نظام الاوقات دریافت کریں",
      "explore.timetable.message": "یہ آپ کا مکمل ماہانہ نظام الاوقات ہے۔ دنوں اور مہینوں کے درمیان منتقل ہو سکتے ہیں۔",
      "explore.timetable.continue": "جاری رکھیں",
      "close.timetable.message": "مرکزی اسکرین پر واپس جانے کے لیے بٹن دبائیں",
      "settings.title": "ترتیبات",
      "settings.message": "اپنی ترجیحات حسب ضرورت بنانے کے لیے ترتیبات کا آئیکن دبائیں",
      "explore.settings.title": "ترتیبات دریافت کریں",
      "explore.settings.message": "یہاں آپ مسجد، ڈسپلے اور اطلاعات کی ترتیبات کو ایڈجسٹ کر سکتے ہیں۔",
      "explore.settings.continue": "جاری رکھیں",
      "close.settings.message": "مرکزی اسکرین پر واپس جانے کے لیے بٹن دبائیں",
    };
    return m[key] ?? key;
  }
  const m: Record<string, string> = {
    "qibla.title": "Qibla Direction",
    "qibla.message": "Discover the Qibla direction for your prayers.",
    "qibla.continue": "Continue",
    "timetable.title": "Monthly Timetable",
    "timetable.message": "Tap the calendar icon to view the full monthly prayer timetable.",
    "explore.timetable.title": "Explore Timetable",
    "explore.timetable.message": "This is your full monthly timetable. You can navigate between days and months.",
    "explore.timetable.continue": "Continue",
    "close.timetable.message": "Tap the close button to return to the home screen.",
    "settings.title": "Settings",
    "settings.message": "Tap the settings icon to customize your experience.",
    "explore.settings.title": "Explore Settings",
    "explore.settings.message": "Here you can adjust your mosque, display, and notification preferences.",
    "explore.settings.continue": "Continue",
    "close.settings.message": "Tap the close button to return to the home screen.",
  };
  return m[key] ?? key;
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

export type OverlayScreen = "home" | "timetable" | "settings";

interface MosqueStub {
  id: string;
  name: string;
}

interface TutorialOverlayProps {
  screen: OverlayScreen;
  mosques: MosqueStub[];
  theme: TimeTheme;
  textColor: string;
  usesLightForeground: boolean;
  locale: string;
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
  const acknowledgeQiblaIntro = useOnboardingStore(
    (s) => s.acknowledgeQiblaIntro
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
            title={s("qibla.title", locale)}
            message={s("qibla.message", locale)}
            variant="belowQiblaIcon"
            primaryButtonTitle={s("qibla.continue", locale)}
            onPrimaryButton={acknowledgeQiblaIntro}
            accessibilityIdentifier="Onboarding.QiblaContinue"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "openTimetable":
        return (
          <CoachMarkCard
            title={s("timetable.title", locale)}
            message={s("timetable.message", locale)}
            variant="belowTopChrome"
            theme={theme}
            textColor={textColor}
            usesLightForeground={usesLightForeground}
          />
        );

      case "openSettings":
        return (
          <CoachMarkCard
            title={s("settings.title", locale)}
            message={s("settings.message", locale)}
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
            title={s("explore.timetable.title", locale)}
            message={s("explore.timetable.message", locale)}
            variant="floatingBottom"
            primaryButtonTitle={s("explore.timetable.continue", locale)}
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
            title={s("explore.timetable.title", locale)}
            message={s("close.timetable.message", locale)}
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
            title={s("explore.settings.title", locale)}
            message={s("explore.settings.message", locale)}
            variant="floatingBottom"
            primaryButtonTitle={s("explore.settings.continue", locale)}
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
            title={s("explore.settings.title", locale)}
            message={s("close.settings.message", locale)}
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
