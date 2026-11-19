import SwiftUI

@MainActor
final class SearchModel: ObservableObject {
    static let shared = SearchModel()

    @Published var query: String = ""
    @Published private(set) var results: [iTunesSearchResult] = []
    @Published private(set) var searching = false
    @Published private(set) var notice: String?
    @Published var deviceFamily: DeviceFamily = .phone

    private var current: Task<Void, Never>?

    func submit() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            notice = nil
            return
        }
        current?.cancel()
        searching = true
        notice = nil

        current = Task { [weak self] in
            guard let self else { return }
            do {
                let country = AppStore.this.selectedAccount?.countryCode ?? "us"
                let hits = try await iTunesClient.shared.search(
                    term: term,
                    limit: 40,
                    countryCode: country,
                    deviceFamily: self.deviceFamily
                )
                guard !Task.isCancelled else { return }
                let list = hits ?? []
                self.results = list
                if list.isEmpty {
                    self.notice = L("search_no_results", "No matching apps")
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.notice = error.localizedDescription
            }
            self.searching = false
        }
    }

    func clear() {
        current?.cancel()
        query = ""
        results = []
        notice = nil
        searching = false
    }

    func switchFamily(_ family: DeviceFamily) {
        guard family != deviceFamily else { return }
        deviceFamily = family
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            submit()
        }
    }
}

struct SearchScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var model: SearchModel
    @Environment(\.colorScheme) private var scheme

    @State private var path = NavigationPath()
    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header(p)
                resultsArea(p)
            }
            .appCanvas(p)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: iTunesSearchResult.self) { app in
                AppDetailScreen(app: app)
            }
        }
    }

    private func header(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                DTitle(
                    text: "tab_search".localized,
                    subtitle: store.selectedAccount.map { accountSubtitle($0) }
                        ?? L("search_sign_in_hint", "Search works without an account; downloading needs one.")
                )
                Spacer(minLength: 8)
                familySwitcher(p)
            }
            DSearchField(
                text: $model.query,
                placeholder: "search_placeholder".localized
            ) {
                model.submit()
            }

            if model.searching {
                DSweepBar()
            }
        }
        .padding(.horizontal, G.gutter)
        .padding(.top, G.headerTop)
        .padding(.bottom, 10)
    }

    private func familySwitcher(_ p: Palette) -> some View {
        HStack(spacing: 2) {
            ForEach(DeviceFamily.allCases, id: \.self) { family in
                let active = model.deviceFamily == family
                Button {
                    Haptics.tap()
                    model.switchFamily(family)
                } label: {
                    Text(family == .phone ? "iPhone" : "iPad")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(active ? Color.white : p.subtext)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(
                            Capsule().fill(active ? p.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule().fill(p.card)
        )
        .overlay(Capsule().strokeBorder(p.line, lineWidth: 1))
    }

    private func accountSubtitle(_ account: Account) -> String {
        let region = account.countryCode.isEmpty ? account.countryCode : account.countryCode.uppercased()
        return region.isEmpty ? account.email : "\(account.email) · \(region)"
    }

    @ViewBuilder
    private func resultsArea(_ p: Palette) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let notice = model.notice, !model.searching {
                    DNote(text: notice, isError: model.results.isEmpty)
                        .padding(.horizontal, G.gutter)
                        .padding(.top, 6)
                }

                if model.results.isEmpty && !model.searching {
                    if model.notice == nil {
                        DEmpty(
                            symbol: "magnifyingglass",
                            title: L("search_start", "Find an app"),
                            message: L("search_start_hint", "Type a name, then open the result to download it.")
                        )
                    }
                } else {
                    DCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, app in
                                NavigationLink(value: app) {
                                    resultRow(app, p)
                                }
                                .buttonStyle(PressableStyle())
                                if index < model.results.count - 1 {
                                    DHairline().padding(.leading, 82)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, G.gutter)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func resultRow(_ app: iTunesSearchResult, _ p: Palette) -> some View {
        HStack(spacing: 12) {
            DArtwork(url: app.artworkUrl100 ?? app.artworkUrl60, size: 56, radius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.trackName)
                    .font(T.medium(15))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                Text(app.artistName ?? app.sellerName ?? "")
                    .font(T.body(12))
                    .foregroundStyle(p.subtext)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let genre = app.primaryGenreName {
                        Text(genre)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(p.muted)
                    }
                    if let rating = app.averageUserRating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 9))
                            Text(String(format: "%.1f", rating)).font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(p.muted)
                    }
                }
            }
            Spacer(minLength: 6)
            if let price = app.formattedPrice, (app.price ?? 0) > 0 {
                DChip(text: price, tint: p.accent)
            } else {
                Text(L("get", "GET"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(p.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(p.accentSoft(0.12)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
