import Foundation
import SwiftUI
import UIKit

struct AppearanceScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    private let accents: [(name: String, hex: String)] = [
        ("Sakura", "#F07E9E"),
        ("Coral", "#E2585F"),
        ("Violet", "#8B7CF6"),
        ("Ocean", "#4C9EEB"),
        ("Mint", "#3BA55D"),
        ("Graphite", "#8E8E93")
    ]

    var body: some View {
        let p = Palette(theme, scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: G.sectionGap) {
                if !AppChrome.usesSystemBars {
                    DTitle(text: L("appearance", "Appearance"), subtitle: L("appearance_subtitle", "Theme and accent colour"), onBack: { dismiss() })
                }

                DSection(L("theme", "Theme")) {
                    DCard(padding: 6) {
                        HStack(spacing: 4) {
                            ForEach(AppTheme.allCases, id: \.self) { mode in
                                let active = theme.selectedTheme == mode
                                Button {
                                    Haptics.tap()
                                    theme.selectedTheme = mode
                                } label: {
                                    Text(mode.displayName)
                                        .font(T.caption(12))
                                        .foregroundStyle(active ? Color.white : p.subtext)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(active ? p.accent : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                DSection(L("effects", "Effects")) {
                    DCard {
                        VStack(spacing: 14) {
                            effectRow(
                                L("liquid_glass", "Liquid Glass"),
                                L("liquid_glass_desc", "Refraction, specular rim and frosted chrome on the tab bar and buttons"),
                                isOn: $theme.liquidGlassEnabled,
                                p
                            )
                            DHairline()
                            effectRow(
                                L("water_layer", "Water Layer"),
                                L("water_layer_desc", "Slow caustic lines moving across the backdrop"),
                                isOn: $theme.waterEffectEnabled,
                                p
                            )
                        }
                    }
                }

                DSection(L("accent_color", "Accent")) {
                    DCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ForEach(accents, id: \.hex) { item in
                                    let color = Color(hex: item.hex)
                                    let active = hexString(theme.accentColor) == item.hex
                                    Button {
                                        Haptics.tap()
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            theme.accentColor = color
                                        }
                                    } label: {
                                        ZStack {
                                            Circle().fill(color)
                                            if active {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle().strokeBorder(
                                                active ? p.text.opacity(0.35) : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                                Spacer(minLength: 0)
                            }
                            Text(L("accent_hint", "One accent is used everywhere: buttons, progress and the selected tab."))
                                .font(T.body(11))
                                .foregroundStyle(p.subtext)
                        }
                    }
                }
            }
            .padding(.horizontal, G.gutter)
            .padding(.top, G.headerTop)
            .padding(.bottom, 30)
        }
        .appCanvas(p)
        .adaptiveNavChrome()
        .navigationTitle(L("appearance", "Appearance"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func effectRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>, _ p: Palette) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(T.medium(14))
                    .foregroundStyle(p.text)
                Text(subtitle)
                    .font(T.body(11))
                    .foregroundStyle(p.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            DSwitch(isOn: isOn)
        }
    }

    private func hexString(_ color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
