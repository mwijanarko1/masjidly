import { View, Text, StyleSheet } from 'react-native';
import { Link } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { COLORS, SPACING, FONT_SIZES } from '@/constants';

export default function ProfileScreen() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.container}>
        <Text style={styles.title}>Profile</Text>
        <Text style={styles.text}>This is the profile screen.</Text>
        <Link
          href="/"
          style={styles.link}
          accessibilityLabel="Go back to Home screen"
          accessibilityRole="link"
        >
          Go back to Home
        </Link>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.md,
  },
  title: {
    fontSize: FONT_SIZES.xxl,
    fontWeight: 'bold',
    marginBottom: SPACING.sm,
    color: COLORS.text,
  },
  text: {
    fontSize: FONT_SIZES.md,
    marginBottom: SPACING.md,
    color: COLORS.textSecondary,
  },
  link: {
    color: COLORS.primary,
    fontSize: FONT_SIZES.md,
  },
});
