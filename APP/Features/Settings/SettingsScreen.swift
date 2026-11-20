import Foundation
import SwiftUI

enum SettingsRoute: Hashable {
    case accounts
    case appearance
    case language
    case icon
    case about
}

/// Plain settings page: identity row, account switch entry, then a grouped
/// list. No cover art, badges or duplicated tabs.
struct SettingsScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var language: LanguageManager
    @EnvironmentObject private var purchased: PurchasedModel
    @EnvironmentObject private var downloads: UnifiedDownloadManager
    @Environment(\.colorScheme) private var scheme

    @State private var showAccounts = false

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    identityCard(p)
                    settingsCard(p)
                    footer(p)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L("settings", "设置"))
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
            .sheet(isPresented: $showAccounts) {
                NavigationStack {
                    AccountsScreen()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(L("done", "完成")) { showAccounts = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Identity

    private func identityCard(_ p: Palette) -> some View {
        DCard(padding: 16) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    avatar(p)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(displayName)
                                .font(T.headline(18))
                                .foregroundStyle(p.text)
                                .lineLimit(1)
                            if store.selectedAccount != nil {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(p.accent)
                            }
                        }
                        Text(store.selectedAccount?.email ?? L("not_signed_in", "未登录 Apple ID"))
                            .font(T.body(12))
                            .foregroundStyle(p.subtext)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 6)

                    Button {
                        Haptics.tap()
                        showAccounts = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "person.2")
                                .font(.system(size: 11, weight: .semibold))
                            Text(L("accounts", "账号"))
                                .font(T.caption(12))
                        }
                        .foregroundStyle(p.accent)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Capsule(style: .continuous).fill(p.accentSoft(0.14)))
                    }
                    .buttonStyle(.plain)
                }

                Rectangle()
                    .fill(p.line)
                    .frame(height: 0.5)

                HStack(spacing: 0) {
                    stat(p, value: "\(purchased.apps.count)", label: L("p_owned", "已购"))
                    Rectangle().fill(p.line).frame(width: 0.5, height: 26)
                    stat(p, value: "\(downloads.downloadRequests.count)", label: L("p_downloads", "下载"))
                    Rectangle().fill(p.line).frame(width: 0.5, height: 26)
                    stat(p, value: regionCode, label: L("region", "地区"))
                }
            }
        }
    }

    private func stat(_ p: Palette, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(p.text)
            Text(label)
                .font(T.caption(11))
                .foregroundStyle(p.subtext)
        }
        .frame(maxWidth: .infinity)
    }

    private func avatar(_ p: Palette) -> some View {
        ZStack {
            Circle().fill(p.fill)
            if let initial = avatarInitial {
                Text(initial)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(p.accent)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(p.muted)
            }
        }
        .frame(width: 52, height: 52)
    }

    // MARK: - Settings list

    private func settingsCard(_ p: Palette) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: SettingsRoute.appearance) {
                row(p, symbol: "paintpalette.fill", title: L("appearance", "外观"), detail: theme.selectedTheme.displayName)
            }
            hairline(p)
            NavigationLink(value: SettingsRoute.language) {
                row(p, symbol: "globe", title: L("language", "语言"), detail: language.currentLanguage.displayName)
            }
            hairline(p)
            NavigationLink(value: SettingsRoute.icon) {
                row(p, symbol: "app.badge", title: L("icon", "图标"), detail: iconDetail)
            }
            hairline(p)
            NavigationLink(value: SettingsRoute.about) {
                row(p, symbol: "info.circle", title: L("about", "关于"), detail: appVersion)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func row(_ p: Palette, symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(p.subtext)
                .frame(width: 24)
            Text(title)
                .font(T.body(15))
                .foregroundStyle(p.text)
            Spacer(minLength: 8)
            Text(detail)
                .font(T.body(13))
                .foregroundStyle(p.subtext)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(p.muted)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .contentShape(Rectangle())
    }

    private func hairline(_ p: Palette) -> some View {
        Rectangle().fill(p.line).frame(height: 0.5).padding(.leading, 52)
    }

    private func footer(_ p: Palette) -> some View {
        VStack(spacing: 3) {
            Text("APP \(appVersion) · Build \(buildNumber)")
                .font(T.caption(11))
                .foregroundStyle(p.muted)
            Text(L("footer_note", "本机下载、解密与归档，不上传任何文件。"))
                .font(T.caption(11))
                .foregroundStyle(p.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Data

    private var displayName: String {
        guard let account = store.selectedAccount else { return L("guest_name", "未登录") }
        let name = [account.firstName, account.lastName].compactMap { $0 }.joined(separator: " ")
        if !name.isEmpty { return name }
        return String(account.email.split(separator: "@").first ?? "APP")
    }

    private var avatarInitial: String? {
        guard let account = store.selectedAccount else { return nil }
        let name = [account.firstName, account.lastName].compactMap { $0 }.joined()
        if let first = name.first { return String(first).uppercased() }
        if let first = account.email.first { return String(first).uppercased() }
        return nil
    }

    private var regionCode: String {
        let code = store.selectedAccount?.countryCode.uppercased() ?? ""
        return code.isEmpty ? "—" : code
    }

    private var iconDetail: String {
        AppIconManager.shared.currentAlternateIconName == nil
            ? L("icon_default", "默认")
            : L("icon_alternate", "自定义")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
