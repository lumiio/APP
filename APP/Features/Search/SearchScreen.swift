import Foundation
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
                let raw = AppStore.this.selectedAccount?.countryCode ?? ""
                let country = raw.trimmingCharacters(in: .whitespaces).isEmpty ? "us" : raw
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

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if model.results.isEmpty {
                    emptyState
                } else {
                    resultList
                }
            }
            .navigationTitle("tab_search".localized)
            .searchable(
                text: $model.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("search_placeholder".localized)
            )
            .onSubmit(of: .search) { model.submit() }
            .onChange(of: model.query) { _, value in
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.clear()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { familyMenu }
            }
            .navigationDestination(for: iTunesSearchResult.self) { app in
                AppDetailScreen(app: app)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("search_start", "Find an app"), systemImage: "magnifyingglass")
        } description: {
            Text(model.notice ?? L("search_start_hint", "Type a name, then open the result to download it."))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var resultList: some View {
        List {
            Section {
                ForEach(model.results, id: \.id) { app in
                    NavigationLink {
                        AppDetailScreen(app: app)
                    } label: {
                        row(app)
                    }
                }
            } header: {
                if let notice = model.notice {
                    Text(notice)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if model.searching { ProgressView().controlSize(.large) }
        }
    }

    private func row(_ app: iTunesSearchResult) -> some View {
        HStack(spacing: 12) {
            DArtwork(url: app.artworkUrl100 ?? app.artworkUrl60, size: 52, radius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.trackName)
                    .font(.body)
                    .lineLimit(1)
                Text(app.artistName ?? app.sellerName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text([app.primaryGenreName, app.averageUserRating.map { String(format: "★ %.1f", $0) }]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(priceLabel(app))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        }
        .padding(.vertical, 2)
    }

    private func priceLabel(_ app: iTunesSearchResult) -> String {
        if let price = app.formattedPrice, (app.price ?? 0) > 0 { return price }
        return L("get", "GET")
    }

    private var familyMenu: some View {
        Menu {
            Picker(L("device", "Device"), selection: Binding(
                get: { model.deviceFamily },
                set: { model.switchFamily($0) }
            )) {
                Text("iPhone").tag(DeviceFamily.phone)
                Text("iPad").tag(DeviceFamily.pad)
            }
        } label: {
            Image(systemName: model.deviceFamily == .phone ? "iphone" : "ipad")
        }
    }
}
