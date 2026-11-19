import Foundation
import SwiftUI
import UIKit

/// Shared geometry. Everything on screen derives its spacing from here so the
/// app keeps one rhythm instead of per-screen ad-hoc numbers.
enum G {
    static let gutter: CGFloat = 20
    static let cardRadius: CGFloat = 12
    static let fieldRadius: CGFloat = 14
    static let controlRadius: CGFloat = 13
    static let cardPadding: CGFloat = 16
    static let blockGap: CGFloat = 14
    static let sectionGap: CGFloat = 28
    static let tabBarHeight: CGFloat = 62
    static let headerTop: CGFloat = 10
}

/// Monochrome surface ramp plus the single accent used for emphasis.
struct Palette {
    let isDark: Bool
    let canvas: Color
    let card: Color
    let fill: Color
    let line: Color
    let text: Color
    let subtext: Color
    let muted: Color
    let accent: Color
    let danger: Color

    init(_ theme: ThemeManager, _ scheme: ColorScheme) {
        let dark = scheme == .dark
        isDark = dark
        // Native iOS surface ramp; no tinted greys of our own.
        canvas = Color(uiColor: .systemGroupedBackground)
        card = Color(uiColor: .secondarySystemGroupedBackground)
        fill = Color(uiColor: .tertiarySystemFill)
        line = Color(uiColor: .separator)
        text = Color(uiColor: .label)
        subtext = Color(uiColor: .secondaryLabel)
        muted = Color(uiColor: .tertiaryLabel)
        accent = theme.accentColor
        danger = Color(uiColor: .systemRed)
    }

    func accentSoft(_ opacity: Double = 0.14) -> Color { accent.opacity(isDark ? opacity : opacity + 0.03) }
    func lineSoft(_ opacity: Double = 0.04) -> Color { text.opacity(opacity) }
}

extension View {
    func appCanvas(_ palette: Palette) -> some View {
        background(palette.canvas.ignoresSafeArea())
    }
}

enum T {
    static func display(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .semibold) }
    static func headline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
    static func medium(_ size: CGFloat = 14) -> Font { .system(size: size, weight: .medium) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium) }
}

/// Fallback helper: localization tables cover the older keys; anything new
/// renders the English source until the table is updated.
func L(_ key: String, _ fallback: String) -> String {
    let value = key.localized
    return value == key ? fallback : value
}
