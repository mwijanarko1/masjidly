import { Pressable, Text, StyleSheet, ViewStyle, TextStyle } from 'react-native';

interface ButtonProps {
  /** The label text displayed inside the button. */
  title: string;
  /** Callback fired when the button is pressed. */
  onPress: () => void;
  /** Visual style variant of the button. Defaults to 'primary'. */
  variant?: 'primary' | 'secondary' | 'outline';
  /** When true, the button is non-interactive and visually dimmed. */
  disabled?: boolean;
  /** Additional styles applied to the button container. */
  style?: ViewStyle;
  /** Additional styles applied to the button label. */
  textStyle?: TextStyle;
}

/**
 * Reusable button component with primary, secondary, and outline variants.
 *
 * @param props - {@link ButtonProps}
 * @returns A pressable button element.
 */
export function Button({
  title,
  onPress,
  variant = 'primary',
  disabled = false,
  style,
  textStyle,
}: ButtonProps) {
  const buttonStyle = [
    styles.button,
    styles[variant],
    disabled ? styles.disabled : null,
    style,
  ];

  const buttonTextStyle = [
    styles.buttonText,
    styles[`${variant}Text` as const],
    disabled ? styles.disabledText : null,
    textStyle,
  ];

  return (
    <Pressable
      style={buttonStyle}
      onPress={onPress}
      disabled={disabled}
      accessibilityRole="button"
      accessibilityLabel={title}
      accessibilityState={{ disabled }}
    >
      <Text style={buttonTextStyle}>{title}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 100,
  },
  primary: {
    backgroundColor: '#007AFF',
  },
  secondary: {
    backgroundColor: '#6B7280',
  },
  outline: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  disabled: {
    opacity: 0.5,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '600',
  },
  primaryText: {
    color: '#FFFFFF',
  },
  secondaryText: {
    color: '#FFFFFF',
  },
  outlineText: {
    color: '#007AFF',
  },
  disabledText: {
    opacity: 0.5,
  },
});
