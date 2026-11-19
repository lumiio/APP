import Foundation
import SwiftUI

/// Full-screen liquid glass field: a soft monochrome gradient with an accent
/// bloom, a slow caustic water layer, and a Metal lens pass that bends the
/// surface near the rim (refraction + thin specular edge).
struct LiquidGlassBackdrop: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if #available(iOS 17.0, *) {
            lens
        } else {
            LiquidGlassCanvas()
        }
    }

    @available(iOS 17.0, *)
    private var lens: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                LiquidGlassCanvas()
                    .layerEffect(
                        ShaderLibrary.liquidLens(
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(reduceMotion ? 0 : Float(timeline.date.timeIntervalSinceReferenceDate)),
                            .float(0.58),
                            .float(0.46)
                        ),
                        maxSampleOffset: CGSize(width: 42, height: 42)
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The flat canvas underneath the lens. One accent, no rainbow gradients.
struct LiquidGlassCanvas: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette(theme, scheme)
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: baseColors(p),
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(p.accent.opacity(p.isDark ? 0.20 : 0.13))
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .blur(radius: 110)
                    .offset(x: -size.width * 0.30, y: -size.height * 0.20)

                Circle()
                    .fill(p.accent.opacity(p.isDark ? 0.10 : 0.07))
                    .frame(width: size.width * 0.7, height: size.width * 0.7)
                    .blur(radius: 90)
                    .offset(x: size.width * 0.34, y: size.height * 0.16)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(p.isDark ? 0.05 : 0.28), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                if theme.waterEffectEnabled {
                    WaterCausticsLayer()
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func baseColors(_ p: Palette) -> [Color] {
        if p.isDark {
            return [Color(hex: "#0A0A0C"), Color(hex: "#111114"), Color(hex: "#0B0B0E")]
        }
        return [Color(hex: "#F4F4F6"), Color(hex: "#ECECF1"), Color(hex: "#F6F6F8")]
    }
}

/// Thin moving caustic lines. Low opacity on purpose: they read as a wet
/// surface, not as decoration.
struct WaterCausticsLayer: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                guard size.width > 1, size.height > 1 else { return }
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                drawCaustics(context: context, size: size, time: time)
                drawRipples(context: context, size: size, time: time)
            }
            .blendMode(.plusLighter)
            .opacity(0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawCaustics(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        var blurred = context
        blurred.addFilter(.blur(radius: 12))

        for index in 0..<4 {
            let base = size.height * (0.16 + CGFloat(index) * 0.21)
            let amplitude = 9 + CGFloat(index) * 4
            let speed = 0.28 + Double(index) * 0.05
            var path = Path()
            var started = false
            var x = -24.0
            while x <= Double(size.width) + 24 {
                let u = x / Double(max(size.width, 1))
                let y = Double(base)
                    + sin(u * 6.1 + time * speed + Double(index) * 1.7) * Double(amplitude)
                    + sin(u * 2.2 - time * speed * 0.7) * Double(amplitude) * 0.55
                let point = CGPoint(x: x, y: y)
                if started { path.addLine(to: point) } else { path.move(to: point); started = true }
                x += 9
            }

            let gradient = Gradient(colors: [
                theme.accentColor.opacity(0.0),
                theme.accentColor.opacity(0.22),
                Color.white.opacity(0.20),
                theme.accentColor.opacity(0.0)
            ])
            blurred.stroke(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: base),
                    endPoint: CGPoint(x: size.width, y: base)
                ),
                lineWidth: 1.2 + CGFloat(index) * 0.4
            )
        }
    }

    private func drawRipples(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
        for index in 0..<2 {
            let progress = (time * 0.08 + Double(index) / 2.0).truncatingRemainder(dividingBy: 1.0)
            let radius = size.width * (0.12 + progress * 0.42)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.6,
                width: radius * 2,
                height: radius * 1.2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(0.08 * (1.0 - progress))),
                lineWidth: 0.7
            )
        }
    }
}

/// A glass slab used when the panel is too small for a full lens pass:
/// frosted material, a tilted highlight, an accent bloom and a specular rim.
struct LiquidGlassPanel: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    var cornerRadius: CGFloat = 20

    var body: some View {
        let p = Palette(theme, scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(p.isDark ? Color.white.opacity(0.03) : Color.white.opacity(0.30))
            shape.fill(
                LinearGradient(
                    colors: [p.accent.opacity(p.isDark ? 0.10 : 0.06), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            if theme.liquidGlassEnabled {
                GlassSheen().clipShape(shape)
            }
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(p.isDark ? 0.26 : 0.55),
                        Color.white.opacity(p.isDark ? 0.05 : 0.12),
                        p.accent.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
        }
        .shadow(color: Color.black.opacity(p.isDark ? 0.28 : 0.10), radius: 18, x: 0, y: 10)
    }
}

/// Slow diagonal light sweep so the slab reads as glass rather than as a blur.
struct GlassSheen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.8

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.10), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * 0.5, height: proxy.size.height * 1.6)
                .rotationEffect(.degrees(18))
                .offset(x: proxy.size.width * phase, y: -proxy.size.height * 0.3)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 4.2).repeatForever(autoreverses: false)) {
                phase = 1.4
            }
        }
    }
}

extension View {
    /// Wraps a bar / panel in glass. On iOS 26 this is the system liquid glass
    /// effect; below it falls back to the frosted slab above.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat, enabled: Bool = true) -> some View {
        if enabled {
            if #available(iOS 26.0, *) {
                self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                self.background(LiquidGlassPanel(cornerRadius: cornerRadius))
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func glassCircle(enabled: Bool = true) -> some View {
        if enabled {
            if #available(iOS 26.0, *) {
                self.glassEffect(.regular, in: Circle())
            } else {
                self.glassCircleFallback()
            }
        } else {
            self
        }
    }

    private func glassCircleFallback() -> some View {
        self.background(
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7)
            }
        )
    }
}
