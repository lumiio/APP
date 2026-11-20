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
        TabView(selection: $tab) {
            SearchScreen()
                .tabItem { Label(AppTab.search.title, systemImage: AppTab.search.symbol) }
                .tag(AppTab.search)
            PurchasedScreen()
                .tabItem { Label(AppTab.purchased.title, systemImage: AppTab.purchased.symbol) }
                .tag(AppTab.purchased)
            DownloadsScreen()
                .tabItem { Label(AppTab.downloads.title, systemImage: AppTab.downloads.symbol) }
                .tag(AppTab.downloads)
            SettingsScreen()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
        .tint(p.accent)
        .onAppear {
            Task { @MainActor in LiveActivityController.shared.syncDownloads() }
        }
    }
}
