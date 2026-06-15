import React from "react";
import { View } from "react-native";
import Svg, { Path, Circle, G } from "react-native-svg";
import type { TimeTheme } from "@/lib/design/themes";
import { getIconColor } from "@/lib/design/themes";

interface PrayerSunPhaseIconProps {
  theme: TimeTheme;
  size?: number;
}

const CANVAS_W = 100;
const CANVAS_H = 88;

function fourPointStarPath(cx: number, cy: number, size: number): string {
  const c = size * 0.25;
  return (
    `M ${cx} ${cy - size} ` +
    `Q ${cx + c} ${cy - c} ${cx + size} ${cy} ` +
    `Q ${cx + c} ${cy + c} ${cx} ${cy + size} ` +
    `Q ${cx - c} ${cy + c} ${cx - size} ${cy} ` +
    `Q ${cx - c} ${cy - c} ${cx} ${cy - size} Z`
  );
}

export const PrayerSunPhaseIcon: React.FC<PrayerSunPhaseIconProps> = React.memo(({
  theme,
  size = 100,
}) => {
  const color = getIconColor(theme);
  const scale = size / CANVAS_W;

  const content = (() => {
    const cx = CANVAS_W / 2;

    switch (theme) {
      case "fajr": {
        const baseY = CANVAS_H * 0.5 + 10;
        const lineHalf = 16;
        return (
          <G>
            <Path
              d={`M ${cx - lineHalf} ${baseY} L ${cx + lineHalf} ${baseY}`}
              stroke={color}
              strokeWidth={1.8}
              strokeLinecap="round"
            />
            <Path
              d={fourPointStarPath(cx, baseY - 14, 6)}
              stroke={color}
              strokeWidth={1.8}
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
          </G>
        );
      }

      case "sunrise": {
        const baseY = CANVAS_H * 0.5 + 14;
        const r = 14;
        const lineHalf = 32;
        const gap = 6;
        const rayLen = 8;
        const angles = [-135, -90, -45];
        return (
          <G>
            <Path
              d={`M ${cx - lineHalf} ${baseY} L ${cx + lineHalf} ${baseY}`}
              stroke={color}
              strokeWidth={2.2}
              strokeLinecap="round"
            />
            <Path
              d={`M ${cx - r} ${baseY} A ${r} ${r} 0 0 1 ${cx + r} ${baseY}`}
              stroke={color}
              strokeWidth={2.2}
              strokeLinecap="round"
              fill="none"
            />
            {angles.map((deg, i) => {
              const rad = (deg * Math.PI) / 180;
              const startR = r + gap;
              const endR = r + gap + rayLen;
              const x1 = cx + Math.cos(rad) * startR;
              const y1 = baseY + Math.sin(rad) * startR;
              const x2 = cx + Math.cos(rad) * endR;
              const y2 = baseY + Math.sin(rad) * endR;
              return (
                <Path
                  key={i}
                  d={`M ${x1} ${y1} L ${x2} ${y2}`}
                  stroke={color}
                  strokeWidth={2.2}
                  strokeLinecap="round"
                />
              );
            })}
          </G>
        );
      }

      case "dhuhr": {
        const cy = CANVAS_H * 0.5;
        const r = 12;
        const gap = 6;
        const len = 8;
        return (
          <G>
            <Circle
              cx={cx}
              cy={cy}
              r={r}
              stroke={color}
              strokeWidth={2.2}
              fill="none"
            />
            {Array.from({ length: 8 }).map((_, i) => {
              const angle = (i * 45 * Math.PI) / 180;
              const startR = r + gap;
              const endR = r + gap + len;
              const x1 = cx + Math.cos(angle) * startR;
              const y1 = cy + Math.sin(angle) * startR;
              const x2 = cx + Math.cos(angle) * endR;
              const y2 = cy + Math.sin(angle) * endR;
              return (
                <Path
                  key={i}
                  d={`M ${x1} ${y1} L ${x2} ${y2}`}
                  stroke={color}
                  strokeWidth={2.2}
                  strokeLinecap="round"
                />
              );
            })}
          </G>
        );
      }

      case "asr": {
        const cy = CANVAS_H * 0.5 - 4;
        const bodyH = 14;
        const top = cy - bodyH * 0.5;
        const bottom = cy + bodyH * 0.5;
        const startX = cx - 10;
        return (
          <G>
            <Path
              d={`M ${startX} ${top} L ${startX} ${bottom}`}
              stroke={color}
              strokeWidth={2.2}
              strokeLinecap="round"
            />
            <Path
              d={`M ${startX} ${bottom} L ${startX + 28} ${bottom + 8}`}
              stroke={color}
              strokeWidth={1.8}
              strokeLinecap="round"
            />
          </G>
        );
      }

      case "maghrib": {
        const baseY = CANVAS_H * 0.5 + 13;
        const r = 14;
        const lineHalf = 32;
        const arrowY = baseY - r - 4;
        return (
          <G>
            <Path
              d={`M ${cx - lineHalf} ${baseY} L ${cx + lineHalf} ${baseY}`}
              stroke={color}
              strokeWidth={2.2}
              strokeLinecap="round"
            />
            <Path
              d={`M ${cx - r} ${baseY} A ${r} ${r} 0 0 1 ${cx + r} ${baseY}`}
              stroke={color}
              strokeWidth={2.2}
              strokeLinecap="round"
              fill="none"
            />
            <Path
              d={`M ${cx} ${arrowY - 8} L ${cx} ${arrowY}`}
              stroke={color}
              strokeWidth={1.8}
              strokeLinecap="round"
            />
            <Path
              d={`M ${cx - 3} ${arrowY - 3} L ${cx} ${arrowY} L ${cx + 3} ${arrowY - 3}`}
              stroke={color}
              strokeWidth={1.8}
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
          </G>
        );
      }

      case "isha":
      case "tahajjud": {
        const cy = CANVAS_H * 0.5;
        return (
          <G>
            <Path
              d={fourPointStarPath(cx - 4, cy, 8)}
              stroke={color}
              strokeWidth={2.2}
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
            <Path
              d={fourPointStarPath(cx + 12, cy - 6, 4)}
              stroke={color}
              strokeWidth={1.8}
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
            <Path
              d={fourPointStarPath(cx + 10, cy + 8, 3)}
              stroke={color}
              strokeWidth={1.8}
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
          </G>
        );
      }

      default:
        return null;
    }
  })();

  return (
    <View style={{ width: size, height: size * (CANVAS_H / CANVAS_W) }}>
      <Svg
        width={size}
        height={size * (CANVAS_H / CANVAS_W)}
        viewBox={`0 0 ${CANVAS_W} ${CANVAS_H}`}
      >
        {content}
      </Svg>
    </View>
  );
});
