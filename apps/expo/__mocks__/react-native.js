const React = require("react");

function createMockComponent(name) {
  return React.forwardRef((props, ref) => {
    const { children, ...rest } = props;
    return React.createElement(name, { ref, ...rest }, children);
  });
}

module.exports = {
  View: createMockComponent("View"),
  Text: createMockComponent("Text"),
  Image: createMockComponent("Image"),
  Pressable: React.forwardRef((props, ref) => {
    const { children, ...rest } = props;
    return React.createElement("Pressable", { ref, accessible: true, ...rest }, children);
  }),
  ScrollView: createMockComponent("ScrollView"),
  FlatList: createMockComponent("FlatList"),
  ActivityIndicator: createMockComponent("ActivityIndicator"),
  Switch: React.forwardRef((props, ref) => {
    const { children, ...rest } = props;
    return React.createElement("RCTSwitch", { ref, accessibilityRole: "switch", ...rest }, children);
  }),
  TextInput: createMockComponent("TextInput"),
  Modal: createMockComponent("Modal"),
  TouchableOpacity: createMockComponent("TouchableOpacity"),
  SafeAreaView: createMockComponent("SafeAreaView"),

  StyleSheet: {
    create: (styles) => styles,
    flatten: (style) => style,
    absoluteFill: {
      position: "absolute",
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
    },
  },

  Dimensions: {
    get: (dim) => {
      if (dim === "window" || dim === "screen") {
        return { width: 375, height: 812, scale: 2, fontScale: 1 };
      }
      return { width: 0, height: 0 };
    },
    addEventListener: () => ({ remove: () => {} }),
  },

  Platform: {
    OS: "ios",
    select: (obj) => obj.ios ?? obj.default,
  },

  Animated: {
    View: createMockComponent("Animated.View"),
    Text: createMockComponent("Animated.Text"),
    Value: class {
      constructor(v) { this._value = v; }
      setValue(v) { this._value = v; }
      interpolate() { return this; }
    },
    timing: () => ({ start: () => {} }),
    spring: () => ({ start: () => {} }),
  },

  StatusBar: {
    setBarStyle: () => {},
    setHidden: () => {},
    setBackgroundColor: () => {},
  },

  useColorScheme: () => "light",
  useWindowDimensions: () => ({ width: 375, height: 812, scale: 2, fontScale: 1 }),
};
