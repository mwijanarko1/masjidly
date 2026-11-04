import SwiftUI

/// Widget copy of the home page `PrayerSunPhaseIcon` (HomeUIComponents.swift).
/// The drawing code is identical so both surfaces show the same art. Stroke widths are heavier
/// because widget glyphs are much smaller than the home orb.
struct WidgetPrayerSunPhaseIcon: View {
    let prayerId: String
    let color: Color
    /// Diameter of the circle the icon sits in.
    let size: CGFloat

    private static let canvas = CGSize(width: 100, height: 88)

    var body: some View {
        Canvas { context, canvasSize in
            let thin = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
            let medium = StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
            let cx = canvasSize.width * 0.5

            switch prayerId.lowercased() {
            case "fajr":
                Self.drawFajr(context: context, cx: cx, size: canvasSize, color: color, thin: thin)
            case "sunrise":
                Self.drawSunrise(context: context, cx: cx, size: canvasSize, color: color, medium: medium)
            case "asr":
                Self.drawAsr(context: context, cx: cx, size: canvasSize, color: color, thin: thin, medium: medium)
            case "maghrib":
                Self.drawMaghrib(context: context, cx: cx, size: canvasSize, color: color, thin: thin, medium: medium)
            case "isha", "tahajjud":
                Self.drawIsha(context: context, cx: cx, size: canvasSize, color: color, thin: thin, medium: medium)
            default:
                Self.drawDhuhr(context: context, cx: cx, size: canvasSize, color: color, medium: medium)
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .scaleEffect(size / 90)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static func fourPointStarPath(cx: CGFloat, cy: CGFloat, size: CGFloat) -> Path {
        var p = Path()
        let c = size * 0.25
        p.move(to: CGPoint(x: cx, y: cy - size))
        p.addQuadCurve(to: CGPoint(x: cx + size, y: cy), control: CGPoint(x: cx + c, y: cy - c))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy + size), control: CGPoint(x: cx + c, y: cy + c))
        p.addQuadCurve(to: CGPoint(x: cx - size, y: cy), control: CGPoint(x: cx - c, y: cy + c))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy - size), control: CGPoint(x: cx - c, y: cy - c))
        return p
    }

    private static func drawFajr(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle) {
        let baseY = size.height * 0.61
        let lineHalf: CGFloat = 16

        var horizon = Path()
        horizon.move(to: CGPoint(x: cx - lineHalf, y: baseY))
        horizon.addLine(to: CGPoint(x: cx + lineHalf, y: baseY))
        context.stroke(horizon, with: .color(color), style: thin)

        let star = fourPointStarPath(cx: cx, cy: baseY - 14, size: 6)
        context.stroke(star, with: .color(color), style: thin)
    }

    private static func drawSunrise(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, medium: StrokeStyle) {
        let baseY = size.height * 0.66
        let r: CGFloat = 14
        let lineHalf: CGFloat = 32

        var horizon = Path()
        horizon.move(to: CGPoint(x: cx - lineHalf, y: baseY))
        horizon.addLine(to: CGPoint(x: cx + lineHalf, y: baseY))
        context.stroke(horizon, with: .color(color), style: medium)

        var sunStroke = Path()
        sunStroke.addArc(center: CGPoint(x: cx, y: baseY), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        context.stroke(sunStroke, with: .color(color), style: medium)

        let gap: CGFloat = 6
        let rayLen: CGFloat = 8
        for deg in [-135.0, -90.0, -45.0] {
            let rad = deg * .pi / 180
            var ray = Path()
            ray.move(to: CGPoint(x: cx + cos(rad) * (r + gap), y: baseY + sin(rad) * (r + gap)))
            ray.addLine(to: CGPoint(x: cx + cos(rad) * (r + gap + rayLen), y: baseY + sin(rad) * (r + gap + rayLen)))
            context.stroke(ray, with: .color(color), style: medium)
        }
    }

    private static func drawDhuhr(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, medium: StrokeStyle) {
        let cy = size.height * 0.50
        let r: CGFloat = 12

        var circle = Path()
        circle.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        context.stroke(circle, with: .color(color), style: medium)

        let gap: CGFloat = 6
        let len: CGFloat = 8
        for i in 0..<8 {
            let angle = Double(i) * 45.0 * .pi / 180.0
            var ray = Path()
            ray.move(to: CGPoint(x: cx + cos(angle) * (r + gap), y: cy + sin(angle) * (r + gap)))
            ray.addLine(to: CGPoint(x: cx + cos(angle) * (r + gap + len), y: cy + sin(angle) * (r + gap + len)))
            context.stroke(ray, with: .color(color), style: medium)
        }
    }

    private static func drawAsr(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let cy = size.height * 0.45
        let bodyH: CGFloat = 14
        let top = cy - bodyH * 0.5
        let bottom = cy + bodyH * 0.5
        let startX = cx - 10

        var post = Path()
        post.move(to: CGPoint(x: startX, y: top))
        post.addLine(to: CGPoint(x: startX, y: bottom))
        context.stroke(post, with: .color(color), style: medium)

        var shadow = Path()
        shadow.move(to: CGPoint(x: startX, y: bottom))
        shadow.addLine(to: CGPoint(x: startX + 28, y: bottom + 8))
        context.stroke(shadow, with: .color(color), style: thin)
    }

    private static func drawMaghrib(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let baseY = size.height * 0.65
        let r: CGFloat = 14
        let lineHalf: CGFloat = 32

        var horizon = Path()
        horizon.move(to: CGPoint(x: cx - lineHalf, y: baseY))
        horizon.addLine(to: CGPoint(x: cx + lineHalf, y: baseY))
        context.stroke(horizon, with: .color(color), style: medium)

        var sunStroke = Path()
        sunStroke.addArc(center: CGPoint(x: cx, y: baseY), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        context.stroke(sunStroke, with: .color(color), style: medium)

        let arrowY = baseY - r - 4
        var arrow = Path()
        arrow.move(to: CGPoint(x: cx, y: arrowY - 8))
        arrow.addLine(to: CGPoint(x: cx, y: arrowY))
        arrow.move(to: CGPoint(x: cx - 3, y: arrowY - 3))
        arrow.addLine(to: CGPoint(x: cx, y: arrowY))
        arrow.addLine(to: CGPoint(x: cx + 3, y: arrowY - 3))
        context.stroke(arrow, with: .color(color), style: thin)
    }

    private static func drawIsha(context: GraphicsContext, cx: CGFloat, size: CGSize, color: Color, thin: StrokeStyle, medium: StrokeStyle) {
        let cy = size.height * 0.50

        context.stroke(fourPointStarPath(cx: cx - 4, cy: cy, size: 8), with: .color(color), style: medium)
        context.stroke(fourPointStarPath(cx: cx + 12, cy: cy - 6, size: 4), with: .color(color), style: thin)
        context.stroke(fourPointStarPath(cx: cx + 10, cy: cy + 8, size: 3), with: .color(color), style: thin)
    }
}
