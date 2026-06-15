import React from "react";
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from "react-native";
import { HapticPressable as Pressable } from "@/components/ui/HapticPressable";
import { LinearGradient } from "expo-linear-gradient";
import { AlignRight, ChevronDown, Clock, Globe2, Palette } from "lucide-react-native";
import type { AppLanguage } from "@/store/settings";
import { ACCENT, getSkyTheme, getTextColor, type TimeTheme } from "@/lib/design/themes";
import { currentMasjidlyVersion, whatsNewCopy, type WhatsNewItem } from "@/lib/updates/whatsNew";
import { getFontScale } from "@/lib/i18n/language";

interface WhatsNewModalProps {
  visible: boolean;
  theme: TimeTheme;
  language: AppLanguage;
  onDismiss: () => void;
}

function FeatureIcon({ item }: { item: WhatsNewItem }) {
  const props = { size: 23, color: ACCENT, strokeWidth: 1.7 };
  switch (item.icon) {
    case "globe":
      return <Globe2 {...props} />;
    case "rtl":
      return <AlignRight {...props} />;
    case "theme":
      return <Palette {...props} />;
    case "countdown":
      return <Clock {...props} />;
  }
  return null;
}

export function WhatsNewModal({ visible, theme, language, onDismiss, onAction }: WhatsNewModalProps) {
  const sky = getSkyTheme(theme);
  const textColor = getTextColor(theme);
  const usesLightForeground = textColor === "#FFFFFF";
  const copy = whatsNewCopy(language);
  const fontScale = getFontScale(language);
  const version = currentMasjidlyVersion();
  const { height } = useWindowDimensions();
  const hasMultipleItems = copy.items.length > 1;
  const maxCardHeight = hasMultipleItems
    ? Math.max(360, Math.min(580, height - 80))
    : Math.max(300, Math.min(440, height - 80));
  const maxScrollHeight = Math.max(150, maxCardHeight - (hasMultipleItems ? 230 : 190));

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onDismiss}>
      <View style={styles.overlay}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onDismiss}>
          <LinearGradient colors={sky.baseColors.map((c) => `${c}DD`)} style={StyleSheet.absoluteFill} />
          <View style={styles.dim} />
        </Pressable>

        <View
          style={[
            styles.cardWrap,
            { maxHeight: maxCardHeight },
            {
              backgroundColor: usesLightForeground
                ? "rgb(10, 10, 30)"
                : "rgb(255, 255, 255)",
            },
          ]}
        >
          <View
            style={[
              styles.cardBorder,
              {
                borderColor: usesLightForeground
                  ? "rgba(255,255,255,0.15)"
                  : "rgba(0,0,0,0.12)",
              },
            ]}
          >
            <View style={[styles.cardInner, { maxHeight: maxCardHeight }]}>
              <View style={styles.header}>
                <Text style={[styles.title, { color: textColor, fontSize: 26 * fontScale }]}>
                  {copy.title}
                </Text>
                <View style={[styles.versionPill, { backgroundColor: `${textColor}1A` }]}>
                  <Text style={[styles.versionText, { color: `${textColor}A3`, fontSize: 14 * fontScale }]}>
                    {copy.versionLabel.replace("%s", version)}
                  </Text>
                </View>
                {hasMultipleItems ? (
                  <View style={styles.swipeHint}>
                    <Text style={[styles.swipeText, { color: `${textColor}73`, fontSize: 12 * fontScale }]}>
                      {copy.swipeHint}
                    </Text>
                    <ChevronDown size={12} color={`${textColor}73`} strokeWidth={2} />
                  </View>
                ) : null}
              </View>

              <ScrollView
                style={[styles.scroll, { maxHeight: maxScrollHeight }]}
                contentContainerStyle={[styles.items, !hasMultipleItems && styles.singleItem]}
                showsVerticalScrollIndicator={hasMultipleItems}
                nestedScrollEnabled={hasMultipleItems}
                scrollEnabled={hasMultipleItems}
                bounces={hasMultipleItems}
              >
                {copy.items.map((item, index) => (
                  <View key={`${item.title}-${index}`} style={styles.itemRow}>
                    <View style={styles.iconSlot}>
                      <FeatureIcon item={item} />
                    </View>
                    <View style={styles.itemText}>
                      <Text style={[styles.itemTitle, { color: textColor, fontSize: 17 * fontScale }]}>
                        {item.title}
                      </Text>
                      <Text style={[styles.itemDescription, { color: `${textColor}B8`, fontSize: 14 * fontScale }]}>
                        {item.description}
                      </Text>

                    </View>
                  </View>
                ))}
              </ScrollView>

              <Pressable style={styles.continueButton} onPress={onDismiss} accessibilityRole="button">
                <LinearGradient colors={["#5FC3FF", "#2E8DFF"]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.continueGradient}>
                  <Text style={styles.continueText}>{copy.continueLabel}</Text>
                </LinearGradient>
              </Pressable>
            </View>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 24,
  },
  dim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0,0,0,0.38)",
  },
  cardWrap: {
    width: "100%",
    maxWidth: 380,
    maxHeight: "84%",
    borderRadius: 34,
    overflow: "hidden",
  },
  cardBorder: {
    borderRadius: 34,
    borderWidth: 1,
  },
  cardInner: {
    padding: 24,
    gap: 22,
  },
  header: {
    alignItems: "center",
    gap: 10,
    paddingTop: 4,
  },
  title: {
    fontFamily: "Comfortaa_600SemiBold",
    textAlign: "center",
  },
  versionPill: {
    borderRadius: 999,
    paddingHorizontal: 16,
    paddingVertical: 6,
  },
  versionText: {
    fontFamily: "Comfortaa_500Medium",
  },
  swipeHint: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    paddingTop: 2,
  },
  swipeText: {
    fontFamily: "Comfortaa_500Medium",
  },
  scroll: {
    flexGrow: 0,
  },
  items: {
    gap: 24,
    paddingVertical: 4,
    paddingHorizontal: 2,
  },
  singleItem: {
    paddingVertical: 0,
  },
  itemRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 16,
  },
  iconSlot: {
    width: 32,
    alignItems: "center",
    paddingTop: 2,
  },
  itemText: {
    flex: 1,
    gap: 6,
  },
  itemTitle: {
    fontFamily: "Comfortaa_600SemiBold",
  },
  itemDescription: {
    fontFamily: "Comfortaa_400Regular",
    lineHeight: 20,
  },
  continueButton: {
    borderRadius: 999,
    overflow: "hidden",
    marginBottom: 2,
  },
  continueGradient: {
    minHeight: 52,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 20,
  },
  continueText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontFamily: "Comfortaa_600SemiBold",
  },
});
