import Foundation
import SwiftUI

enum SettingsRoute: Hashable {
    case accounts
    case appearance
    case language
    case icon
    case about
}

/// Profile page laid out like a QQ "我的" card: a circular icon row on top, one
/// large identity card with avatar / name / status / like count, then flat
/// information rows and a three-button action bar pinned above the tab bar.
struct SettingsScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var language: LanguageManager
    @EnvironmentObject private var purchased: PurchasedModel
    @EnvironmentObject private var downloads: UnifiedDownloadManager
    @Environment(\.colorScheme) private var scheme

    @State private var path: [SettingsRoute] = []
    @State private var showAddAccount = false

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    topIcons(p)
                    identityCard(p)
                    infoRow(
                        symbol: "doc.text",
                        title: L("completion", "资料完成度") + " \(completionPercent)%",
                        detail: L("improve", "去完善"),
                        p: p
                    ) { path.append(.accounts) }

                    infoRow(
                        symbol: "star",
                        title: L("purchases_row", "已购应用"),
                        detail: "\(purchased.apps.count) · " + L("view_all", "查看全部"),
                        p: p
                    ) { path.append(.accounts) }

                    settingsRows(p)
                }
                .padding(.bottom, 18)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar(p)
            }
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

    // MARK: - Top icon row

    private func topIcons(_ p: Palette) -> some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            circleButton("qrcode", p) { path.append(.about) }
            circleButton("bell", p) { path.append(.language) }
            circleButton("gearshape", p) { path.append(.appearance) }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private func circleButton(_ symbol: String, _ p: Palette, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(p.subtext)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(uiColor: .tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Identity card

    private func identityCard(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 14) {
                avatar(p)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text(displayName)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(p.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        statusChip(p)
                    }
                    HStack(spacing: 7) {
                        Text(roleLine)
                            .font(.system(size: 14))
                            .foregroundStyle(p.subtext)
                            .lineLimit(1)
                        idChip(p)
                    }
                }

                Spacer(minLength: 4)

                Button {
                    Haptics.tap()
                    path.append(.accounts)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 17, weight: .regular))
                        Text("\(purchased.apps.count)")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(p.text)
                }
                .buttonStyle(.plain)
            }

            Button {
                Haptics.tap()
                path.append(.about)
            } label: {
                HStack(spacing: 6) {
                    Text(signLine)
                        .font(.system(size: 15))
                        .foregroundStyle(p.text)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(p.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                path.append(.language)
            } label: {
                HStack(spacing: 5) {
                    Text(L("add_tag", "添加标签"))
                        .font(.system(size: 13))
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(p.subtext)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(p.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 12)
    }

    private func avatar(_ p: Palette) -> some View {
        ZStack {
            Circle().fill(Color(uiColor: .tertiarySystemFill))
            if let initial = avatarInitial {
                Text(initial)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [p.accent.opacity(0.75), p.accent.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
        .frame(width: 84, height: 84)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2))
    }

    private func statusChip(_ p: Palette) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "face.smiling")
                .font(.system(size: 10, weight: .semibold))
            Text(L("status", "状态"))
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(p.text)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
        )
    }

    private func idChip(_ p: Palette) -> some View {
        HStack(spacing: 3) {
            Text(L("id", "ID"))
                .font(.system(size: 11, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous)
                .fill(Color(uiColor: .systemGray2))
        )
    }

    // MARK: - Flat rows

    private func infoRow(
        symbol: String,
        title: String,
        detail: String,
        p: Palette,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(p.subtext)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(p.text)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(uiColor: .systemBlue).opacity(0.9))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(p.muted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    private func settingsRows(_ p: Palette) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: SettingsRoute.accounts) {
                settingRow(symbol: "person.crop.circle", title: L("account_management", "账号"), detail: "", p: p)
            }
            divider(p)
            NavigationLink(value: SettingsRoute.appearance) {
                settingRow(symbol: "paintpalette", title: L("appearance", "外观"), detail: theme.selectedTheme.displayName, p: p)
            }
            divider(p)
            NavigationLink(value: SettingsRoute.language) {
                settingRow(symbol: "globe", title: L("language", "语言"), detail: language.currentLanguage.displayName, p: p)
            }
            divider(p)
            NavigationLink(value: SettingsRoute.icon) {
                settingRow(symbol: "app.badge", title: L("icon", "App 图标"), detail: iconDetail, p: p)
            }
            divider(p)
            NavigationLink(value: SettingsRoute.about) {
                settingRow(symbol: "info.circle", title: "about".localized, detail: appVersion, p: p)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 12)
    }

    private func divider(_ p: Palette) -> some View {
        Rectangle()
            .fill(p.line)
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    private func settingRow(symbol: String, title: String, detail: String, p: Palette) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(p.subtext)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(p.text)
            Spacer(minLength: 8)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(p.subtext)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    // MARK: - Bottom action bar

    private func actionBar(_ p: Palette) -> some View {
        HStack(spacing: 10) {
            barButton(L("appearance", "外观"), p, filled: false) { path.append(.appearance) }
            barButton(L("language", "语言"), p, filled: false) { path.append(.language) }
            barButton(store.selectedAccount == nil ? "add_account".localized : L("account_management", "账号"), p, filled: true) {
                if store.selectedAccount == nil { showAddAccount = true } else { path.append(.accounts) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color(uiColor: .systemGroupedBackground).opacity(0.95))
    }

    private func barButton(_ title: String, _ p: Palette, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled ? Color.white : p.text)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(filled ? p.accent : Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .strokeBorder(filled ? Color.clear : p.line, lineWidth: filled ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
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

    private var roleLine: String {
        guard let account = store.selectedAccount else {
            return L("role_guest", "添加 Apple ID 后即可下载")
        }
        let region = account.countryCode.uppercased()
        return region.isEmpty ? account.email : "\(account.email) · \(region)"
    }

    private var signLine: String {
        L("profile_slogan", "下载、解密、归档，全在本地。")
    }

    private var completionPercent: Int {
        var score = 0
        if store.selectedAccount != nil { score += 40 }
        if purchased.apps.count > 0 { score += 30 }
        if downloads.downloadRequests.count > 0 { score += 30 }
        return min(score, 100)
    }

    private var iconDetail: String {
        AppIconManager.shared.currentAlternateIconName == nil
            ? L("icon_default", "Default")
            : L("icon_alternate", "Alternate")
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        return version
    }
}
