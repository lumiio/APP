import SwiftUI

@MainActor
final class PurchasedModel: ObservableObject {
    static let shared = PurchasedModel()

    @Published private(set) var apps: [OwnedApp] = []
    @Published private(set) var loading = false
    @Published private(set) var notice: String?

    private var loadedFor: String?

    func load(force: Bool = false) async {
        guard let account = AppStore.this.selectedAccount else {
            apps = []
            loadedFor = nil
            notice = L("no_account", "No account signed in")
            return
        }
        guard !loading else { return }
        if !force, loadedFor == account.email, !apps.isEmpty { return }

        loading = true
        notice = nil
        defer { loading = false }

        do {
            let owned = try await PurchaseHistoryService.ownedApps(account: account)
            apps = owned.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            loadedFor = account.email
            if apps.isEmpty {
                notice = L("purchased_empty", "This account has no purchased apps.")
            }
        } catch {
            notice = error.localizedDescription
        }
    }

    func enqueue(_ app: OwnedApp) {
        let manager = UnifiedDownloadManager.shared
        if let existing = manager.downloadRequests.first(where: {
            $0.package.bundleIdentifier == app.bundleID
        }) {
            manager.startDownload(for: existing)
            return
        }
        let id = manager.addDownload(
            bundleIdentifier: app.bundleID,
            name: app.name,
            version: app.version,
            identifier: Int(app.id) ?? 0,
            iconURL: app.iconURL,
            versionId: nil,
            price: nil,
            currency: nil
        )
        if let request = manager.downloadRequests.first(where: { $0.id == id }) {
            manager.startDownload(for: request)
        }
    }
}

struct PurchasedScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var model: PurchasedModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack {
            VStack(spacing: 0) {
                header(p)
                content(p)
            }
            .appCanvas(p)
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.load() }
        }
    }

    private func header(_ p: Palette) -> some View {
        HStack(alignment: .top) {
            DTitle(
                text: "tab_purchased".localized,
                subtitle: subtitle
            )
            Spacer(minLength: 8)
            DIconButton(symbol: "arrow.clockwise") {
                Haptics.tap()
                Task { await model.load(force: true) }
            }
            .rotationEffect(.degrees(model.loading ? 180 : 0))
            .animation(.easeInOut(duration: 0.3), value: model.loading)
        }
        .padding(.horizontal, G.gutter)
        .padding(.top, G.headerTop)
        .padding(.bottom, 10)
    }

    private var subtitle: String {
        if let account = store.selectedAccount {
            let count = model.apps.count
            return count == 0
                ? account.email
                : "\(account.email) · \(count) \(L("apps", "apps"))"
        }
        return L("no_account", "No account signed in")
    }

    @ViewBuilder
    private func content(_ p: Palette) -> some View {
        if model.loading {
            DSweepBar().padding(.horizontal, G.gutter)
        }

        ScrollView {
            VStack(spacing: 10) {
                if store.selectedAccount == nil {
                    DEmpty(
                        symbol: "person.crop.circle.badge.exclamationmark",
                        title: L("no_account", "No account signed in"),
                        message: L("purchased_account_hint", "Add an Apple ID in Settings to list what this account owns.")
                    )
                } else if let notice = model.notice, model.apps.isEmpty {
                    DEmpty(
                        symbol: "tray",
                        title: notice,
                        message: L("purchased_empty_hint", "Purchases show up here after you buy an app with this account.")
                    )
                } else if !model.apps.isEmpty {
                    DCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(model.apps.enumerated()), id: \.element.id) { index, app in
                                row(app, p)
                                if index < model.apps.count - 1 {
                                    DHairline().padding(.leading, 76)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, G.gutter)
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await model.load(force: true) }
    }

    private func row(_ app: OwnedApp, _ p: Palette) -> some View {
        HStack(spacing: 12) {
            DArtwork(url: app.iconURL, size: 52, radius: 13)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(T.medium(15))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(T.body(11))
                    .foregroundStyle(p.muted)
                    .lineLimit(1)
                Text(L("version", "Version") + " " + app.version)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(p.subtext)
            }
            Spacer(minLength: 8)
            Button {
                Haptics.tap()
                model.enqueue(app)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(p.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(p.accentSoft(0.12)))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
