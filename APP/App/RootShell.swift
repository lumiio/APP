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
            p.canvas.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar(p)
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

    private func tabBar(_ p: Palette) -> some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                let active = item == tab
                Button {
                    guard tab != item else { return }
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.18)) { tab = item }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 17, weight: active ? .semibold : .regular))
                        Text(item.title)
                            .font(.system(size: 10, weight: active ? .semibold : .regular))
                    }
                    .foregroundStyle(active ? p.accent : p.subtext)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        if active {
                            Capsule()
                                .fill(p.accentSoft(0.13))
                                .frame(width: 78, height: 40)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(p.line, lineWidth: 1)
                )
        }
        .padding(.horizontal, G.gutter)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}
