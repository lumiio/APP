import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case search
    case purchased
    case downloads
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: return "tab_search".localized
        case .purchased: return "tab_purchased".localized
        case .downloads: return "tab_downloads".localized
        case .settings: return "tab_settings".localized
        }
    }

    var symbol: String {
        switch self {
        case .search: return "magnifyingglass"
        case .purchased: return "square.stack"
        case .downloads: return "arrow.down.to.line"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct RootShell: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    @State private var tab: AppTab = .search

    var body: some View {
        let p = Palette(theme, scheme)
        ZStack {
            if theme.liquidGlassEnabled {
                LiquidGlassCanvas()
            } else {
                p.canvas.ignoresSafeArea()
            }
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar(p)
                .padding(.horizontal, G.gutter)
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .search: SearchScreen()
        case .purchased: PurchasedScreen()
        case .downloads: DownloadsScreen()
        case .settings: SettingsScreen()
        }
    }

    // MARK: - Tab bar

    @ViewBuilder
    private func tabBar(_ p: Palette) -> some View {
        if #available(iOS 26.0, *), theme.liquidGlassEnabled {
            GlassEffectContainer(spacing: 8) {
                items(p)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
            }
        } else {
            items(p)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(p.line, lineWidth: 1)
                        )
                }
                .shadow(color: Color.black.opacity(p.isDark ? 0.35 : 0.10), radius: 16, x: 0, y: 8)
        }
    }

    private func items(_ p: Palette) -> some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { item in
                let active = item == tab
                Button {
                    guard tab != item else { return }
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.16)) { tab = item }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 17, weight: active ? .semibold : .regular))
                            .symbolVariant(active ? .fill : .none)
                        Text(item.title)
                            .font(.system(size: 10.5, weight: active ? .semibold : .medium))
                    }
                    .foregroundStyle(active ? p.accent : p.subtext)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        if active {
                            Capsule(style: .continuous)
                                .fill(p.accent.opacity(p.isDark ? 0.16 : 0.11))
                                .padding(.horizontal, 2)
                                .padding(.vertical, 1)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}
