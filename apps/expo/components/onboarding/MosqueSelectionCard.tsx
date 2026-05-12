import React from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  type ViewStyle,
  type TextStyle,
} from "react-native";
import { ACCENT } from "@/lib/design/themes";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface MosqueItem {
  id: string;
  name: string;
}

interface MosqueSelectionCardProps {
  mosques: MosqueItem[];
  selectedMosqueId: string;
  onSelect: (id: string) => void;
  onContinue: () => void;
  textColor: string;
  usesLightForeground: boolean;
  locale: string;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function MosqueSelectionCard({
  mosques,
  selectedMosqueId,
  onSelect,
  onContinue,
  textColor,
  usesLightForeground,
  locale,
}: MosqueSelectionCardProps) {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="auto">
      {/* Dimming backdrop */}
      <View
        style={[
          StyleSheet.absoluteFill,
          {
            backgroundColor: usesLightForeground
              ? "rgba(0, 0, 0, 0.28)"
              : "rgba(0, 0, 0, 0.14)",
          },
        ]}
      />

      {/* Center card */}
      <View style={styles.centerContainer} pointerEvents="box-none">
        <View
          style={[
            styles.glassCard,
            {
              backgroundColor: usesLightForeground
                ? "rgba(10, 10, 30, 0.72)"
                : "rgba(255, 255, 255, 0.82)",
              borderColor: usesLightForeground
                ? "rgba(255, 255, 255, 0.15)"
                : "rgba(240, 240, 240, 0.6)",
              shadowColor: usesLightForeground
                ? "rgba(0,0,0,0.25)"
                : "rgba(0,0,0,0.10)",
            },
          ]}
        >
          {/* Title */}
          <View style={{ alignItems: "center", marginBottom: 10 }}>
            <Text
              style={[
                styles.title,
                { color: textColor },
              ]}
            >
              {locale === "ar"
                ? "اختر مسجدك"
                : locale === "ur"
                ? "اپنی مسجد منتخب کریں"
                : "Choose Your Mosque"}
            </Text>

            <Text
              style={[
                styles.message,
                { color: textColor + "CC" },
              ]}
            >
              {locale === "ar"
                ? "اختر المسجد الذي تريد عرض مواقيت الصلاة الخاصة به"
                : locale === "ur"
                ? "وہ مسجد منتخب کریں جس کے اوقات نماز آپ دیکھنا چاہتے ہیں"
                : "Select the mosque whose prayer times you'd like to view"}
            </Text>
          </View>

          {/* Mosque picker */}
          <ScrollView
            style={styles.pickerList}
            showsVerticalScrollIndicator={false}
          >
            {mosques.map((mosque) => {
              const isSelected = mosque.id === selectedMosqueId;
              return (
                <Pressable
                  key={mosque.id}
                  style={[
                    styles.mosqueRow,
                    {
                      backgroundColor: isSelected
                        ? textColor + "1A"
                        : "transparent",
                    },
                  ]}
                  onPress={() => onSelect(mosque.id)}
                  accessibilityRole="button"
                  accessibilityLabel={mosque.name}
                  accessibilityIdentifier="Onboarding.MosquePicker"
                >
                  <Text
                    style={[
                      styles.mosqueName,
                      {
                        color: textColor,
                        fontFamily: isSelected
                          ? "Comfortaa_600SemiBold"
                          : "Comfortaa_400Regular",
                      },
                    ]}
                  >
                    {mosque.name}
                  </Text>
                  {isSelected ? (
                    <View
                      style={[
                        styles.checkmark,
                        { backgroundColor: ACCENT },
                      ]}
                    >
                      <Text style={styles.checkmarkText}>✓</Text>
                    </View>
                  ) : null}
                </Pressable>
              );
            })}
          </ScrollView>

          {/* Continue button */}
          <Pressable
            style={[
              styles.continueButton,
              { opacity: selectedMosqueId ? 1 : 0.45 },
            ]}
            onPress={onContinue}
            disabled={!selectedMosqueId}
            accessibilityRole="button"
            accessibilityLabel="Continue"
            accessibilityIdentifier="Onboarding.MosqueContinue"
          >
            <Text style={styles.continueButtonText}>
              {locale === "ar"
                ? "متابعة"
                : locale === "ur"
                ? "جاری رکھیں"
                : "Continue"}
            </Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  centerContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 24,
  } as ViewStyle,
  glassCard: {
    width: "100%",
    maxWidth: 380,
    borderRadius: 24,
    padding: 24,
    borderWidth: 1,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.24,
    shadowRadius: 30,
    elevation: 10,
    maxHeight: "80%",
  } as ViewStyle,
  title: {
    fontSize: 23,
    fontFamily: "Comfortaa_600SemiBold",
    letterSpacing: -0.5,
    textAlign: "center",
    marginBottom: 10,
  } as TextStyle,
  message: {
    fontSize: 16,
    fontFamily: "Comfortaa_400Regular",
    lineHeight: 22,
    textAlign: "center",
    marginBottom: 16,
  } as TextStyle,
  pickerList: {
    maxHeight: 240,
    marginBottom: 16,
  } as ViewStyle,
  mosqueRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderRadius: 12,
    marginBottom: 4,
  } as ViewStyle,
  mosqueName: {
    fontSize: 18,
    flex: 1,
  } as TextStyle,
  checkmark: {
    width: 24,
    height: 24,
    borderRadius: 12,
    justifyContent: "center",
    alignItems: "center",
  } as ViewStyle,
  checkmarkText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "bold",
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
