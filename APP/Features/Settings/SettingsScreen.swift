import Foundation
import SwiftUI

enum SettingsRoute: Hashable {
    case accounts
    case appearance
    case language
    case icon
    case about
}

/// Profile page modelled on an artist home page: a full-bleed cover with an
/// overlay pill, an identity card that overlaps it, a work row, then a tab
/// strip and a board card.
struct SettingsScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var language: LanguageManager
    @EnvironmentObject private var purchased: PurchasedModel
    @EnvironmentObject private var downloads: UnifiedDownloadManager
    @Environment(\.colorScheme) private var scheme

    @State private var path: [SettingsRoute] = []
    @State private var showAddAccount = false
    @State private var tab: HomeTab = .home

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    cover(p)
                    identityCard(p)
                        .padding(.horizontal, 14)
                    tabStrip(p)
                        .padding(.top, 18)
                    tabContent(p)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 22)
                }
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                miniBar(p)
            }
            .sheet(isPresented: $showAddAccount) { AddAccountScreen() }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .accounts: AccountsScreen()
                case .appearance: AppearanceScreen()
                case .language: LanguageScreen()
                case .icon: IconScreen()
                case .about: AboutScreen()
                }
            }
        }
    }

    // MARK: - Cover

    private func cover(_ p: Palette) -> some View {
        ZStack(alignment: .top) {
            CoverArt(height: 330)

            VStack(spacing: 0) {
                topControls(p)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 10) {
                    nowPlayingBubble
                    Spacer(minLength: 8)
                    likePill(p)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
            }
            .frame(height: 330)
        }
    }

    private func topControls(_ p: Palette) -> some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                path.append(.accounts)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.28)))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text(L("profile_badge", "个人主页"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(Color.black.opacity(0.32)))

            Circle().fill(Color.white.opacity(0.55)).frame(width: 5, height: 5)
            Circle().fill(Color.white.opacity(0.30)).frame(width: 5, height: 5)

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                path.append(.about)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.28)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
    }

    private var nowPlayingBubble: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
            Text(L("now_listening", "在听：") + nowPlaying)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
    }

    private func likePill(_ p: Palette) -> some View {
        Button {
            Haptics.tap()
            path.append(.accounts)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(L("my_likes", "我的赞赏") + " \(purchased.apps.count)")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule(style: .continuous).fill(p.accent))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Identity card

    private func identityCard(_ p: Palette) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(p.accent)
            }

            HStack(spacing: 14) {
                Text("\(purchased.apps.count) \(L("p_owned", "已购"))")
                Text("\(downloads.downloadRequests.count) \(L("p_downloads", "下载"))")
                Text("\(L("region", "地区")) \(regionCode)")
            }
            .font(.system(size: 14))
            .foregroundStyle(p.subtext)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(L("roles_line", "App Store 客户端、下载、解密、归档"))
                .font(.system(size: 14))
                .foregroundStyle(p.subtext)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button {
                Haptics.tap()
                path.append(.accounts)
            } label: {
                Text(L("edit_profile", "编辑资料"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(p.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(p.line, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Rectangle()
                .fill(p.line)
                .frame(height: 0.5)
                .padding(.top, 10)

            workRow(p)
        }
        .padding(.horizontal, 16)
        .padding(.top, 64)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(alignment: .top) {
            avatar(p).offset(y: -58)
        }
        .padding(.top, -12)
    }

    private func avatar(_ p: Palette) -> some View {
        ZStack {
            Circle().fill(Color(uiColor: .secondarySystemGroupedBackground))
            Circle()
                .fill(Color(uiColor: .tertiarySystemFill))
                .padding(5)
            if let initial = avatarInitial {
                Text(initial)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(p.accent)
                    .padding(5)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(5)
            }
        }
        .frame(width: 96, height: 96)
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 6)
    }

    private func workRow(_ p: Palette) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(p.fill)
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(p.accent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("APP \(appVersion)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(p.text)
                Text(L("work_sub", "最新版本上线"))
                    .font(.system(size: 12))
                    .foregroundStyle(p.subtext)
            }

            Spacer(minLength: 8)

            Button {
                Haptics.tap()
                path.append(.about)
            } label: {
                Text(L("tap_to_listen", "点击收听"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(p.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(p.accent.opacity(0.75), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    // MARK: - Tab strip

    private func tabStrip(_ p: Palette) -> some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases) { item in
                let active = item == tab
                Button {
                    guard tab != item else { return }
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.16)) { tab = item }
                } label: {
                    VStack(spacing: 7) {
                        HStack(alignment: .top, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 17, weight: active ? .bold : .medium))
                            if let count = item.count(purchased: purchased, downloads: downloads), count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.top, 1)
                            }
                        }
                        .foregroundStyle(active ? p.text : p.subtext)
                        Capsule()
                            .fill(active ? p.accent : Color.clear)
                            .frame(width: 20, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func tabContent(_ p: Palette) -> some View {
        switch tab {
        case .home:
            VStack(spacing: 12) {
                boardCard(p)
                if purchased.apps.isEmpty {
                    emptyHint(L("home_empty", "还没有已购内容，去搜索页找一个 App。"), p)
                }
            }
        case .owned:
            rows(purchased.apps.prefix(20).map { ($0.name, $0.version) }, p)
        case .downloads:
            rows(downloads.downloadRequests.sorted { $0.createdAt > $1.createdAt }.prefix(20).map { ($0.name, $0.version) }, p)
        case .about:
            aboutRows(p)
        }
    }

    private func boardCard(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "star.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(p.accent)
                Text(L("board_title", "公告板"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(p.text)
            }

            if store.selectedAccount == nil {
                Button {
                    Haptics.tap()
                    showAddAccount = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text(L("board_add_account", "登录 Apple ID，开始下载"))
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(p.subtext)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                p.line,
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                    )
                }
                .buttonStyle(.plain)
            } else if let first = purchased.apps.first {
                HStack(spacing: 12) {
                    DArtwork(url: first.iconURL?.absoluteString, size: 40, radius: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(p.text)
                            .lineLimit(1)
                        Text(L("board_latest", "最近已购"))
                            .font(.system(size: 11))
                            .foregroundStyle(p.subtext)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(p.muted)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func rows(_ items: [(String, String)], _ p: Palette) -> some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                emptyHint(L("list_empty", "这里还是空的。"), p)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: "app.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(p.subtext)
                            .frame(width: 28)
                        Text(item.0)
                            .font(.system(size: 15))
                            .foregroundStyle(p.text)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(item.1)
                            .font(.system(size: 13))
                            .foregroundStyle(p.subtext)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    if index < items.count - 1 {
                        Rectangle().fill(p.line).frame(height: 0.5).padding(.leading, 56)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func aboutRows(_ p: Palette) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: SettingsRoute.appearance) {
                settingRow("paintpalette", L("appearance", "外观"), theme.selectedTheme.displayName, p)
            }
            hairline(p)
            NavigationLink(value: SettingsRoute.language) {
                settingRow("globe", L("language", "语言"), language.currentLanguage.displayName, p)
            }
            hairline(p)
            NavigationLink(value: SettingsRoute.icon) {
                settingRow("app.badge", L("icon", "图标"), iconDetail, p)
            }
            hairline(p)
            NavigationLink(value: SettingsRoute.about) {
                settingRow("info.circle", "about".localized, appVersion, p)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func settingRow(_ symbol: String, _ title: String, _ detail: String, _ p: Palette) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(p.subtext)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(p.text)
            Spacer(minLength: 8)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(p.subtext)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }

    private func hairline(_ p: Palette) -> some View {
        Rectangle().fill(p.line).frame(height: 0.5).padding(.leading, 56)
    }

    private func emptyHint(_ text: String, _ p: Palette) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(p.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }

    // MARK: - Mini bar

    @ViewBuilder
    private func miniBar(_ p: Palette) -> some View {
        if let active = activeDownload {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(p.accent.opacity(0.16))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(p.accent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(active.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(p.text)
                        .lineLimit(1)
                    Text(verbatim: "\(Int(active.runtime.progressValue * 100))% · \(L("p_active", "下载中"))")
                        .font(.system(size: 11))
                        .foregroundStyle(p.subtext)
                }

                Spacer(minLength: 6)

                Button {
                    Haptics.tap()
                    if active.runtime.status == .downloading {
                        downloads.pauseDownload(request: active)
                    } else {
                        downloads.resumeDownload(request: active)
                    }
                } label: {
                    Image(systemName: active.runtime.status == .downloading ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.text)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(uiColor: .tertiarySystemFill)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Data

    private var activeDownload: DownloadRequest? {
        downloads.downloadRequests.first { $0.runtime.status == .downloading || $0.runtime.status == .paused }
    }

    private var nowPlaying: String {
        activeDownload?.name ?? L("idle_value", "空闲")
    }

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
        let info = Bundle.main.infoDictionary
        return info?["CFBundleShortVersionString"] as? String ?? "-"
    }
}

enum HomeTab: String, CaseIterable, Identifiable {
    case home, owned, downloads, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return L("tab_home", "主页")
        case .owned: return L("tab_owned", "已购")
        case .downloads: return L("tab_downloads", "下载")
        case .about: return L("tab_about", "关于")
        }
    }

    @MainActor func count(purchased: PurchasedModel, downloads: UnifiedDownloadManager) -> Int? {
        switch self {
        case .owned: return purchased.apps.count
        case .downloads: return downloads.downloadRequests.count
        default: return nil
        }
    }
}

/// Cover art: a dark plate with halftone dots, a soft bloom and a few sketch
/// strokes, standing in for the illustration the reference page carries.
private struct CoverArt: View {
    var height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1B1B1E"), Color(hex: "#2C2C31"), Color(hex: "#141416")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 90, y: -80)

            Circle()
                .fill(Color(hex: "#4A4A52").opacity(0.6))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: -80, y: 60)

            HalftoneDots()
                .opacity(0.55)

            SketchStrokes()
                .opacity(0.28)
        }
        .frame(height: height)
        .clipped()
    }
}

private struct HalftoneDots: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 7
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let distance = hypot(x - size.width * 0.72, y - size.height * 0.34)
                    let alpha = max(0, 0.42 - distance / (size.width * 1.15))
                    if alpha > 0.02 {
                        let rect = CGRect(x: x, y: y, width: 1.6, height: 1.6)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                    }
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SketchStrokes: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.55, y: 0))
            path.addCurve(
                to: CGPoint(x: size.width * 0.72, y: size.height * 0.55),
                control1: CGPoint(x: size.width * 0.70, y: size.height * 0.18),
                control2: CGPoint(x: size.width * 0.60, y: size.height * 0.40)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.58, y: size.height),
                control1: CGPoint(x: size.width * 0.84, y: size.height * 0.72),
                control2: CGPoint(x: size.width * 0.68, y: size.height * 0.86)
            )
            context.stroke(path, with: .color(.white), lineWidth: 1.4)

            var second = Path()
            second.move(to: CGPoint(x: size.width * 0.80, y: size.height * 0.10))
            second.addQuadCurve(
                to: CGPoint(x: size.width * 0.95, y: size.height * 0.60),
                control: CGPoint(x: size.width * 0.98, y: size.height * 0.34)
            )
            context.stroke(second, with: .color(.white.opacity(0.8)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
