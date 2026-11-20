import Foundation
import SwiftUI

enum SettingsRoute: Hashable {
    case accounts
    case appearance
    case language
    case icon
    case about
}

/// Tabs of the profile page, mirroring the artist page layout this screen is
/// modelled on: a cover, an overlapping identity card, and a tab strip.
enum ProfileTab: String, CaseIterable, Identifiable {
    case home, account, look, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return L("p_home", "主页")
        case .account: return L("p_account", "账号")
        case .look: return L("p_look", "外观")
        case .about: return L("p_about", "关于")
        }
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var language: LanguageManager
    @EnvironmentObject private var purchased: PurchasedModel
    @EnvironmentObject private var downloads: UnifiedDownloadManager
    @Environment(\.colorScheme) private var scheme

    @State private var path: [SettingsRoute] = []
    @State private var showAddAccount = false
    @State private var tab: ProfileTab = .home

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    coverAndCard(p)
                    savedBar(p)
                    tabStrip(p)
                    tabContent(p)
                }
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Cover + identity card

    private func coverAndCard(_ p: Palette) -> some View {
        ZStack(alignment: .top) {
            ProfileCover(height: 300)

            VStack(spacing: 0) {
                Color.clear.frame(height: 246)
                profileCard(p)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func profileCard(_ p: Palette) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(p.accent)
            }

            statsRow(p)

            Text(roleLine)
                .font(.system(size: 13))
                .foregroundStyle(p.subtext)
                .lineLimit(1)

            Text(L("profile_slogan", "下载、解密、归档，全在本地。"))
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(p.text)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
                .padding(.horizontal, 6)

            workRow(p)
        }
        .padding(.horizontal, 16)
        .padding(.top, 62)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(alignment: .top) {
            avatar(p).offset(y: -46)
        }
    }

    private func avatar(_ p: Palette) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [p.accent.opacity(0.55), p.accent.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let initial = avatarInitial {
                Text(initial)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 92, height: 92)
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 8)
    }

    private func statsRow(_ p: Palette) -> some View {
        HStack(spacing: 9) {
            Text("\(purchased.apps.count) \(L("p_owned", "已购"))")
            Text("|").foregroundStyle(p.muted)
            Text("\(downloads.downloadRequests.count) \(L("p_downloads", "下载"))")
            Text("|").foregroundStyle(p.muted)
            Text("\(L("region", "地区")) \(regionCode)")
        }
        .font(.system(size: 13))
        .foregroundStyle(p.subtext)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func workRow(_ p: Palette) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(p.line)
                .frame(height: 0.5)
                .padding(.top, 6)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(p.fill)
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(p.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(L("app_name", "APP")) \(appVersion)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(p.text)
                    Text(L("p_work_sub", "最近版本，本地下载与解密"))
                        .font(.system(size: 12))
                        .foregroundStyle(p.subtext)
                }
                Spacer(minLength: 8)
                Button {
                    Haptics.tap()
                    path.append(.about)
                } label: {
                    Text(L("p_view", "查看"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(p.accent)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .strokeBorder(p.accent.opacity(0.55), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Saved account bar

    private func savedBar(_ p: Palette) -> some View {
        Button {
            Haptics.tap()
            path.append(.accounts)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(p.accent)
                Text(L("p_current_account", "当前账号"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(p.text)
                Spacer(minLength: 8)
                Text(savedDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(p.subtext)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(p.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Tab strip

    private func tabStrip(_ p: Palette) -> some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases) { item in
                let active = item == tab
                Button {
                    guard tab != item else { return }
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.18)) { tab = item }
                } label: {
                    VStack(spacing: 7) {
                        Text(item.title)
                            .font(.system(size: 16, weight: active ? .bold : .medium))
                            .foregroundStyle(active ? p.text : p.subtext)
                        Capsule()
                            .fill(active ? p.accent : Color.clear)
                            .frame(width: 22, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func tabContent(_ p: Palette) -> some View {
        switch tab {
        case .home:
            VStack(spacing: G.sectionGap) {
                metricCard(p)
                quickLinks(p)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        case .account:
            accountBlock(p).padding(.top, 4)
        case .look:
            preferencesBlock(p).padding(.top, 4)
        case .about:
            aboutBlock(p).padding(.top, 4)
        }
    }

    private func metricCard(_ p: Palette) -> some View {
        DCard(padding: 0) {
            HStack(spacing: 0) {
                metric("\(purchased.apps.count)", L("p_owned", "已购"), p)
                Divider().frame(height: 34)
                metric("\(downloads.activeDownloads.count)", L("p_active", "下载中"), p)
                Divider().frame(height: 34)
                metric("\(downloads.completedRequests.count)", L("p_completed", "已完成"), p)
            }
            .padding(.vertical, 16)
        }
    }

    private func metric(_ value: String, _ label: String, _ p: Palette) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(p.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(p.subtext)
        }
        .frame(maxWidth: .infinity)
    }

    private func quickLinks(_ p: Palette) -> some View {
        DCard(padding: 0) {
            VStack(spacing: 0) {
                NavigationLink(value: SettingsRoute.accounts) {
                    row(symbol: "person.crop.circle", title: L("account_management", "Accounts"), detail: "", p: p)
                }
                DHairline().padding(.leading, 60)
                NavigationLink(value: SettingsRoute.appearance) {
                    row(symbol: "paintpalette", title: L("appearance", "Appearance"), detail: theme.selectedTheme.displayName, p: p)
                }
                DHairline().padding(.leading, 60)
                NavigationLink(value: SettingsRoute.language) {
                    row(symbol: "globe", title: L("language", "Language"), detail: language.currentLanguage.displayName, p: p)
                }
                DHairline().padding(.leading, 60)
                NavigationLink(value: SettingsRoute.icon) {
                    row(symbol: "app.badge", title: L("icon", "App Icon"), detail: iconDetail, p: p)
                }
                DHairline().padding(.leading, 60)
                NavigationLink(value: SettingsRoute.about) {
                    row(symbol: "info.circle", title: "about".localized, detail: appVersion, p: p)
                }
            }
        }
    }

    // MARK: - Data

    private var displayName: String {
        guard let account = store.selectedAccount else { return L("app_name", "APP") }
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
            return L("role_guest", "未登录 · App Store 客户端")
        }
        return "Apple ID · \(account.email)"
    }

    private var regionCode: String {
        let code = store.selectedAccount?.countryCode.uppercased() ?? ""
        return code.isEmpty ? "—" : code
    }

    private var savedDetail: String {
        guard let account = store.selectedAccount else { return L("no_account", "未登录") }
        return "\(purchased.apps.count) \(L("p_owned", "已购")) · \(account.countryCode.uppercased())"
    }

    private var iconDetail: String {
        AppIconManager.shared.currentAlternateIconName == nil
            ? L("icon_default", "Default")
            : L("icon_alternate", "Alternate")
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

/// Abstract cover art: a deep teal field with soft blooms and orbital rings,
/// standing in for the album artwork the reference page uses.
private struct ProfileCover: View {
    var height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A3944"), Color(hex: "#0E6D66"), Color(hex: "#0C2F42")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "#8FE4D4").opacity(0.32))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -100, y: 70)

            Circle()
                .fill(Color(hex: "#1E8F93").opacity(0.55))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 110, y: -30)

            Circle()
                .fill(Color(hex: "#0B2A3E").opacity(0.55))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: 80, y: 150)

            OrbitRings()
        }
        .frame(height: height)
        .clipped()
    }
}

private struct OrbitRings: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<3 {
                let inset = CGFloat(index) * 26
                let rect = CGRect(
                    x: inset + 10,
                    y: size.height * 0.10 + CGFloat(index) * 12,
                    width: size.width - (inset + 10) * 2,
                    height: size.height * 0.72 - CGFloat(index) * 10
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(0.16)),
                    lineWidth: 1
                )
            }

            let big = CGRect(
                x: size.width * 0.52,
                y: -size.height * 0.30,
                width: size.width * 0.92,
                height: size.width * 0.92
            )
            context.stroke(
                Path(ellipseIn: big),
                with: .color(.white.opacity(0.22)),
                lineWidth: 1.2
            )

            let small = CGRect(
                x: -size.width * 0.25,
                y: size.height * 0.35,
                width: size.width * 0.55,
                height: size.width * 0.55
            )
            context.stroke(
                Path(ellipseIn: small),
                with: .color(.white.opacity(0.14)),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
    }
}
