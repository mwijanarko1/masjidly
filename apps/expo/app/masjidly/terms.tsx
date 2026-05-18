import React from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { ArrowLeft } from "lucide-react-native";
import { SPACING, FONT_SIZES } from "@/constants";
import { AtmosphericSkyBackground } from "@/components/ui/AtmosphericSkyBackground";
import { getSkyTheme } from "@/lib/design/themes";
import { useAppLanguage } from "@/lib/i18n/language";
import { t } from "@/lib/i18n/translations";

const sky = getSkyTheme("isha");

export default function TermsScreen() {
  const router = useRouter();
  const language = useAppLanguage();

  return (
    <View style={styles.root}>
      <AtmosphericSkyBackground sky={sky} variant="simple" />

      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <Pressable
            onPress={() => router.back()}
            style={styles.backButton}
            accessibilityRole="button"
            accessibilityLabel={t("accessibility.back", language)}
          >
            <ArrowLeft size={20} color="#FFFFFF" strokeWidth={2} />
          </Pressable>
          <Text style={styles.title}>{t("legal.terms.title", language)}</Text>
          <View style={styles.backButton} />
        </View>

        <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
          <View style={styles.card}>
            <Text style={styles.lastUpdated}>Last updated: May 2025</Text>
            {language !== "en" ? (
              <Text style={styles.body}>{t("legal.localized_notice", language)}</Text>
            ) : null}

            <Text style={styles.heading}>1. Acceptance of Terms</Text>
            <Text style={styles.body}>
              By downloading, accessing, or using Masjidly ("the App"), you agree to be bound by
              these Terms of Service. If you do not agree, please do not use the App.
            </Text>

            <Text style={styles.heading}>2. Description of Service</Text>
            <Text style={styles.body}>
              Masjidly provides prayer times, adhan notifications, and related Islamic prayer
              information for registered mosques. The App displays prayer schedules provided by
              participating mosques and calculates approximate times when official data is
              unavailable.
            </Text>

            <Text style={styles.heading}>3. User Responsibilities</Text>
            <Text style={styles.body}>
              You agree to use the App only for lawful purposes. You must not:
            </Text>
            <Text style={styles.bullet}>
              · Use the App in any way that could disrupt, damage, or impair its functionality.
            </Text>
            <Text style={styles.bullet}>
              · Attempt to gain unauthorised access to any part of the App or its systems.
            </Text>
            <Text style={styles.bullet}>
              · Use the App to distribute harmful content, spam, or malware.
            </Text>

            <Text style={styles.heading}>{`4. ${t("legal.terms.section.accuracy", language)}`}</Text>
            <Text style={styles.body}>
              While we strive to provide accurate prayer times, we make no guarantees regarding
              their precision. Prayer times are provided for convenience and should be verified
              with your local mosque or trusted Islamic authority. Masjidly is not responsible for
              any missed prayers or incorrect timings.
            </Text>

            <Text style={styles.heading}>5. Third-Party Data</Text>
            <Text style={styles.body}>
              The App may display data provided by third parties, including mosques and calculation
              methods. We do not endorse or guarantee the accuracy of third-party content.
            </Text>

            <Text style={styles.heading}>6. Intellectual Property</Text>
            <Text style={styles.body}>
              All content, design, and code within the App are the property of Masjidly unless
              otherwise stated. You may not reproduce, distribute, or create derivative works
              without prior written consent.
            </Text>

            <Text style={styles.heading}>7. Limitation of Liability</Text>
            <Text style={styles.body}>
              Masjidly is provided "as is" without any warranties, express or implied. To the
              fullest extent permitted by law, we shall not be liable for any damages arising from
              your use of the App.
            </Text>

            <Text style={styles.heading}>8. Changes to Terms</Text>
            <Text style={styles.body}>
              We reserve the right to update these terms at any time. Continued use of the App
              after changes constitutes acceptance of the new terms.
            </Text>

            <Text style={styles.heading}>{`9. ${t("legal.terms.section.contact", language)}`}</Text>
            <Text style={styles.body}>
              For questions about these terms, please contact us at{" "}
              <Text style={styles.email}>mikhailbuilds@gmail.com</Text>.
            </Text>
          </View>
        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: SPACING.md,
    paddingTop: SPACING.sm,
    paddingBottom: SPACING.sm,
    zIndex: 1,
  },
  backButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: "rgba(255,255,255,0.18)",
    justifyContent: "center",
    alignItems: "center",
  },
  title: {
    fontSize: 20,
    fontFamily: "Comfortaa_600SemiBold",
    color: "#FFFFFF",
    textAlign: "center",
    letterSpacing: 0.2,
  },
  scrollContent: {
    paddingHorizontal: SPACING.lg,
    paddingBottom: 48,
  },
  card: {
    backgroundColor: "rgba(255,255,255,0.10)",
    borderRadius: 16,
    padding: SPACING.lg,
    marginTop: SPACING.sm,
  },
  lastUpdated: {
    fontSize: 13,
    fontFamily: "Comfortaa_400Regular",
    color: "rgba(255,255,255,0.55)",
    marginBottom: SPACING.lg,
    textAlign: "center",
  },
  heading: {
    fontSize: 17,
    fontFamily: "Comfortaa_600SemiBold",
    color: "#FFFFFF",
    marginTop: SPACING.md,
    marginBottom: SPACING.xs,
    letterSpacing: 0.2,
  },
  body: {
    fontSize: 15,
    fontFamily: "Comfortaa_400Regular",
    color: "rgba(255,255,255,0.80)",
    lineHeight: 24,
    marginBottom: SPACING.xs,
  },
  bullet: {
    fontSize: 15,
    fontFamily: "Comfortaa_400Regular",
    color: "rgba(255,255,255,0.75)",
    lineHeight: 24,
    marginLeft: SPACING.sm,
    marginBottom: 2,
  },
  email: {
    color: "#47A6FF",
    fontFamily: "Comfortaa_600SemiBold",
  },
});
