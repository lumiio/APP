import Foundation
import SwiftUI

enum SettingsRoute: Hashable {
    case accounts
    case appearance
    case language
    case icon
    case about
}

struct SettingsScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var language: LanguageManager
    @Environment(\.colorScheme) private var scheme

    @State private var path: [SettingsRoute] = []
    @State private var showAddAccount = false

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: G.sectionGap) {
                    accountBlock(p)
                    preferencesBlock(p)
                    aboutBlock(p)
                }
                .padding(.top, G.headerTop)
                .padding(.bottom, 30)
            }
            .appCanvas(p)
            .navigationTitle("tab_settings".localized)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .accounts: AccountsScreen()
                case .appearance: AppearanceScreen()
                case .language: LanguageScreen()
                case .icon: IconScreen()
                case .about: AboutScreen()
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountScreen()
            }
        }
    }

    private func accountBlock(_ p: Palette) -> some View {
        DSection(L("account", "Account")) {
            DCard {
                if let account = store.selectedAccount {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(p.accentSoft(0.16))
                            Text(String(account.email.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(p.accent)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.email)
                                .font(T.medium(14))
                                .foregroundStyle(p.text)
                                .lineLimit(1)
                            Text(subtitle(for: account))
                                .font(T.body(11))
                                .foregroundStyle(p.subtext)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Button {
                            Haptics.tap()
                            path.append(.accounts)
                        } label: {
                            Text(L("manage", "Manage"))
                                .font(T.caption(12))
                                .foregroundStyle(p.accent)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 12) {
                        DTile(symbol: "person.badge.plus", size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("no_account".localized)
                                .font(T.medium(14))
                                .foregroundStyle(p.text)
                            Text(L("account_add_hint", "Add an Apple ID to download purchases."))
                                .font(T.body(11))
                                .foregroundStyle(p.subtext)
                        }
                        Spacer(minLength: 8)
                        DButton(title: "add_account".localized, kind: .secondary, compact: true) {
                            showAddAccount = true
                        }
                    }
                }
            }
            .padding(.horizontal, G.gutter)
        }
    }

    private func subtitle(for account: Account) -> String {
        let country = account.countryCode.uppercased()
        let name = [account.firstName, account.lastName].compactMap { $0 }.joined(separator: " ")
        return [name.isEmpty ? nil : name, country.isEmpty ? nil : country]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func preferencesBlock(_ p: Palette) -> some View {
        DSection(L("preferences", "Preferences")) {
            DCard(padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink(value: SettingsRoute.appearance) {
                        row(
                            symbol: "paintpalette",
                            title: L("appearance", "Appearance"),
                            detail: theme.selectedTheme.displayName,
                            p: p
                        )
                    }
                    DHairline().padding(.leading, 60)
                    NavigationLink(value: SettingsRoute.language) {
                        row(
                            symbol: "globe",
                            title: L("language", "Language"),
                            detail: language.currentLanguage.displayName,
                            p: p
                        )
                    }
                    DHairline().padding(.leading, 60)
                    NavigationLink(value: SettingsRoute.icon) {
                        row(
                            symbol: "app.badge",
                            title: L("icon", "App Icon"),
                            detail: AppIconManager.shared.currentAlternateIconName == nil
                                ? L("icon_default", "Default")
                                : L("icon_alternate", "Alternate"),
                            p: p
                        )
                    }
                }
            }
            .padding(.horizontal, G.gutter)
        }
    }

    private func aboutBlock(_ p: Palette) -> some View {
        DSection(L("more", "More")) {
            DCard(padding: 0) {
                NavigationLink(value: SettingsRoute.about) {
                    row(
                        symbol: "info.circle",
                        title: "about".localized,
                        detail: appVersion,
                        p: p
                    )
                }
            }
            .padding(.horizontal, G.gutter)
        }
    }

    private func row(symbol: String, title: String, detail: String, p: Palette) -> some View {
        HStack(spacing: 12) {
            DTile(symbol: symbol, size: 32)
            Text(title)
                .font(T.medium(14))
                .foregroundStyle(p.text)
            Spacer(minLength: 8)
            Text(detail)
                .font(T.body(12))
                .foregroundStyle(p.subtext)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(p.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        return version
    }
}
