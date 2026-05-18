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

export default function PrivacyScreen() {
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
          <Text style={styles.title}>{t("legal.privacy.title", language)}</Text>
          <View style={styles.backButton} />
        </View>

        <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
          <View style={styles.card}>
            <Text style={styles.lastUpdated}>Last updated: May 2025</Text>
            {language !== "en" ? (
              <Text style={styles.body}>{t("legal.localized_notice", language)}</Text>
            ) : null}

            <Text style={styles.heading}>1. Introduction</Text>
            <Text style={styles.body}>
              Masjidly ("we", "our", or "us") is committed to protecting your privacy. This
              Privacy Policy explains how we collect, use, and safeguard your personal information
              when you use our mobile application.
            </Text>

            <Text style={styles.heading}>{`2. ${t("legal.privacy.section.collection", language)}`}</Text>
            <Text style={styles.subheading}>2.1 Information You Provide</Text>
            <Text style={styles.body}>
              We do not require you to create an account or provide personal information to use
              Masjidly. If you contact us via email, we will receive your email address and any
              information you include in your message.
            </Text>

            <Text style={styles.subheading}>2.2 Information Collected Automatically</Text>
            <Text style={styles.body}>
              We may collect non-personal usage data such as app launch counts, feature usage
              patterns, and crash reports to help us improve the App. This data is anonymised and
              cannot be used to identify you.
            </Text>

            <Text style={styles.subheading}>2.3 Location Data</Text>
            <Text style={styles.body}>
              Masjidly may request access to your device's location for the Qibla compass feature.
              Location data is processed on-device and is never sent to our servers or shared with
              third parties. You can disable location access at any time in your device settings.
            </Text>

            <Text style={styles.heading}>3. Notifications</Text>
            <Text style={styles.body}>
              If you enable notifications, we schedule local notifications on your device for
              prayer times and adhan alerts. No notification data is transmitted to our servers.
              All scheduling is handled locally on your device.
            </Text>

            <Text style={styles.heading}>4. Third-Party Services</Text>
            <Text style={styles.body}>
              Masjidly uses Convex for backend data storage of mosque prayer time schedules.
              Prayer time data is public information provided by participating mosques. No
              personal user data is stored on Convex.
            </Text>

            <Text style={styles.heading}>{`5. ${t("legal.privacy.section.storage", language)}`}</Text>
            <Text style={styles.body}>
              We implement reasonable security measures to protect your information. However, no
              method of electronic storage is 100% secure, and we cannot guarantee absolute
              security.
            </Text>

            <Text style={styles.heading}>6. Children's Privacy</Text>
            <Text style={styles.body}>
              Masjidly is not directed at children under 13. We do not knowingly collect personal
              information from children. If you believe a child has provided us with personal data,
              please contact us so we can delete it.
            </Text>

            <Text style={styles.heading}>7. Changes to This Policy</Text>
            <Text style={styles.body}>
              We may update this Privacy Policy from time to time. We will notify you of changes
              by updating the "Last updated" date at the top of this page.
            </Text>

            <Text style={styles.heading}>8. Your Rights</Text>
            <Text style={styles.body}>
              Depending on your jurisdiction, you may have the right to access, correct, or delete
              your personal data. Since we do not store personal user data, no action is needed on
              our part. For any privacy-related inquiries, please contact us.
            </Text>

            <Text style={styles.heading}>{`9. ${t("legal.privacy.section.contact", language)}`}</Text>
            <Text style={styles.body}>
              For questions about this Privacy Policy, please contact us at{" "}
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
  subheading: {
    fontSize: 15,
    fontFamily: "Comfortaa_500Medium",
    color: "rgba(255,255,255,0.90)",
    marginTop: SPACING.sm,
    marginBottom: 2,
    letterSpacing: 0.1,
  },
  body: {
    fontSize: 15,
    fontFamily: "Comfortaa_400Regular",
    color: "rgba(255,255,255,0.80)",
    lineHeight: 24,
    marginBottom: SPACING.xs,
  },
  email: {
    color: "#47A6FF",
    fontFamily: "Comfortaa_600SemiBold",
  },
});
