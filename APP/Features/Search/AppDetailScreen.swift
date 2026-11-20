import Foundation
import SwiftUI

struct AppDetailScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    let app: iTunesSearchResult

    @State private var busy = false
    @State private var queued = false
    @State private var errorText: String?
    @State private var expandedDescription = false
    @State private var versions: [StoreAppVersion] = []
    @State private var loadingVersions = false
    @State private var versionsLoaded = false
    @State private var versionError: String?
    @State private var showAllVersions = false
    @State private var busyVersion: String?

    var body: some View {
        let p = Palette(theme, scheme)
        ScrollView {
            VStack(spacing: G.blockGap) {
                headlineCard(p)
                actionArea(p)
                versionCard(p)
                if !screenshots.isEmpty { screenshotStrip(p) }
                descriptionCard(p)
                infoCard(p)
            }
            .padding(.horizontal, G.gutter)
            .padding(.top, G.headerTop)
            .padding(.bottom, 30)
        }
        .appCanvas(p)
        .navigationTitle(app.trackName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncQueueState()
            loadVersions()
        }
    }

    private var screenshots: [String] {
        let phone = app.screenshotUrls ?? []
        return phone.isEmpty ? (app.ipadScreenshotUrls ?? []) : phone
    }

    private func headlineCard(_ p: Palette) -> some View {
        DCard {
            HStack(alignment: .top, spacing: 14) {
                DArtwork(url: app.artworkUrl512 ?? app.artworkUrl100, size: 78, radius: 18)
                VStack(alignment: .leading, spacing: 7) {
                    Text(app.trackName)
                        .font(T.headline(17))
                        .foregroundStyle(p.text)
                        .lineLimit(2)
                    Text(app.artistName ?? app.sellerName ?? "")
                        .font(T.body(13))
                        .foregroundStyle(p.subtext)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let genre = app.primaryGenreName {
                            DChip(text: genre)
                        }
                        DChip(text: L("version", "Version") + " " + app.version)
                        if let age = app.contentAdvisoryRating {
                            DChip(text: age)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func actionArea(_ p: Palette) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                DButton(
                    title: queued ? L("in_queue", "In queue") : downloadTitle,
                    icon: queued ? "checkmark" : "arrow.down",
                    kind: queued ? .secondary : .primary,
                    loading: busy,
                    action: startDownload
                )
                .frame(maxWidth: .infinity)

                if let price = app.formattedPrice, (app.price ?? 0) > 0 {
                    Text(price)
                        .font(T.medium(13))
                        .foregroundStyle(p.subtext)
                        .frame(width: 72, height: 44)
                        .background(RoundedRectangle(cornerRadius: G.controlRadius).fill(p.card))
                        .overlay(RoundedRectangle(cornerRadius: G.controlRadius).strokeBorder(p.line, lineWidth: 1))
                }
            }

            if let errorText {
                DNote(text: errorText, isError: true)
            } else if store.selectedAccount == nil {
                DNote(text: L("detail_account_hint", "Sign in with an Apple ID in Settings before downloading."))
            } else {
                DNote(text: L("detail_queue_hint", "The download keeps running in the background after you leave this page."))
            }
        }
    }

    private var downloadTitle: String {
        ((app.price ?? 0) == 0) ? L("get", "GET") : L("purchase", "Buy")
    }

    private var visibleVersions: [StoreAppVersion] {
        showAllVersions ? versions : Array(versions.prefix(6))
    }

    private func versionCard(_ p: Palette) -> some View {
        DSection(L("version_history", "Version history")) {
            VStack(alignment: .leading, spacing: 0) {
                if loadingVersions && versions.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text(L("loading", "Loading"))
                            .font(T.body(13))
                            .foregroundStyle(p.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                } else if versions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(versionError ?? L("version_history_empty", "No older builds were found for this app."))
                            .font(T.body(13))
                            .foregroundStyle(versionError == nil ? p.subtext : p.danger)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            versionsLoaded = false
                            loadVersions()
                        } label: {
                            Text(L("retry", "Retry"))
                                .font(T.caption(12))
                                .foregroundStyle(p.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(visibleVersions) { version in
                        versionRow(version, p)
                        if version.id != visibleVersions.last?.id {
                            Divider().overlay(p.line)
                        }
                    }
                    if versions.count > 6 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { showAllVersions.toggle() }
                        } label: {
                            Text(showAllVersions
                                 ? L("collapse", "Show less")
                                 : L("show_all", "Show all") + " \(versions.count)")
                                .font(T.caption(12))
                                .foregroundStyle(p.accent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func versionRow(_ version: StoreAppVersion, _ p: Palette) -> some View {
        let isCurrent = version.versionString == app.version
        let downloadable = !version.versionId.isEmpty
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(version.versionString.isEmpty ? L("version_unknown", "Unknown") : version.versionString)
                        .font(T.medium(14))
                        .foregroundStyle(p.text)
                    if isCurrent {
                        DChip(text: L("current_version", "Current"), tint: p.accent)
                    }
                }
                HStack(spacing: 8) {
                    if let date = version.releaseDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(T.caption(11))
                            .foregroundStyle(p.muted)
                    }
                    if let notes = version.releaseNotes, !notes.isEmpty {
                        Text(notes.replacingOccurrences(of: "\n", with: " "))
                            .font(T.caption(11))
                            .foregroundStyle(p.subtext)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            if isCurrent {
                Text(L("installed_latest", "Latest"))
                    .font(T.caption(11))
                    .foregroundStyle(p.muted)
            } else if busyVersion == version.versionString {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    download(version)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text(L("download", "Get"))
                            .font(T.caption(12))
                    }
                    .foregroundStyle(downloadable ? p.accent : p.muted)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(
                        Capsule().fill(downloadable ? p.accentSoft(0.16) : p.fill)
                    )
                }
                .buttonStyle(.plain)
                .disabled(busyVersion != nil)
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func loadVersions() {
        guard !loadingVersions else { return }
        if versionsLoaded && !versions.isEmpty { return }
        loadingVersions = true
        versionError = nil

        let trackId = app.trackId
        let bundleId = app.bundleId
        let accountCountry = store.selectedAccount.map { $0.countryCode } ?? ""
        let fallbackRegion = Locale.current.region?.identifier ?? "US"
        let region = accountCountry.isEmpty ? fallbackRegion : accountCountry

        Task {
            var list: [StoreAppVersion] = []

            // Old builds with downloadable ids come from the external mirrors.
            let mirrors = await IPadnVersionSources.fetch(appID: String(trackId))
            if !mirrors.isEmpty {
                list = mirrors.map { item in
                    StoreAppVersion(
                        versionString: item.version,
                        versionId: item.versionId,
                        isCurrent: item.version == app.version,
                        releaseDate: item.releaseDate
                    )
                }
            }

            // iTunes metadata fills in dates and release notes.
            var infos: [ITunesAPIClientVersion] = []
            for code in (region.uppercased() == "US" ? ["US"] : [region, "US"]) {
                if let hit = try? await iTunesClient.shared.versionHistory(id: trackId, country: code), !hit.isEmpty {
                    infos = hit.map { .init(version: $0.version, date: $0.releaseDate, notes: $0.releaseNotes) }
                    break
                }
            }

            if list.isEmpty {
                list = infos.map { info in
                    StoreAppVersion(
                        versionString: info.version,
                        versionId: "",
                        isCurrent: info.version == app.version,
                        releaseDate: info.date,
                        releaseNotes: info.notes
                    )
                }
            } else {
                let map = Dictionary(uniqueKeysWithValues: infos.map { ($0.version, $0) })
                for index in list.indices {
                    guard let info = map[list[index].versionString] else { continue }
                    if list[index].releaseDate == nil { list[index].releaseDate = info.date }
                    if (list[index].releaseNotes ?? "").isEmpty { list[index].releaseNotes = info.notes }
                }
            }

            if list.isEmpty, !bundleId.isEmpty {
                list = await Self.versionsByBundleID(bundleId, region: region)
            }

            list.sort { lhs, rhs in
                if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
                switch (lhs.releaseDate, rhs.releaseDate) {
                case let (l?, r?): return l > r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.versionString.compare(rhs.versionString, options: .numeric) == .orderedDescending
                }
            }

            await MainActor.run {
                versions = list
                versionsLoaded = true
                loadingVersions = false
                if list.isEmpty {
                    versionError = L("version_history_empty", "No older builds were found for this app.")
                }
            }
        }
    }

    private static func versionsByBundleID(_ bundleId: String, region: String) async -> [StoreAppVersion] {
        for code in (region.uppercased() == "US" ? ["US"] : [region, "US"]) {
            guard let results = try? await iTunesClient.shared.search(term: bundleId, limit: 5, countryCode: code) else { continue }
            if let hit = results?.first(where: { $0.bundleId.caseInsensitiveCompare(bundleId) == .orderedSame }), hit.trackId > 0,
               let infos = try? await iTunesClient.shared.versionHistory(id: hit.trackId, country: code), !infos.isEmpty {
                return infos.map { info in
                    StoreAppVersion(versionString: info.version, versionId: "", isCurrent: false, releaseDate: info.releaseDate, releaseNotes: info.releaseNotes)
                }
            }
        }
        return []
    }

    private func download(_ version: StoreAppVersion) {
        guard busyVersion == nil else { return }
        guard let account = store.selectedAccount else {
            errorText = L("no_account", "No account signed in")
            Haptics.warning()
            return
        }
        guard !version.versionId.isEmpty else {
            errorText = L("version_no_id", "This build has no store identifier, so it cannot be fetched.")
            Haptics.warning()
            return
        }
        errorText = nil
        busyVersion = version.versionString
        let versionId = version.versionId
        let versionString = version.versionString

        Task {
            let outcome = await PurchaseManager.shared.purchaseAppIfNeeded(
                appIdentifier: String(app.trackId),
                account: account,
                countryCode: account.countryCode,
                isFree: (app.price ?? 0) == 0,
                deviceFamily: .phone
            )
            await MainActor.run {
                busyVersion = nil
                switch outcome {
                case .failure(let err):
                    errorText = err.errorDescription ?? err.localizedDescription
                    Haptics.warning()
                case .success:
                    let manager = UnifiedDownloadManager.shared
                    if let existing = manager.downloadRequests.first(where: {
                        $0.bundleIdentifier == app.bundleId && $0.version == versionString
                    }) {
                        manager.startDownload(for: existing)
                    } else {
                        let id = manager.addDownload(
                            bundleIdentifier: app.bundleId,
                            name: app.trackName,
                            version: versionString,
                            identifier: app.trackId,
                            iconURL: app.artworkUrl512,
                            versionId: versionId,
                            price: app.price,
                            currency: app.currency
                        )
                        if let request = manager.downloadRequests.first(where: { $0.id == id }) {
                            manager.startDownload(for: request)
                        }
                    }
                    syncedQueuedState()
                    Haptics.success()
                }
            }
        }
    }

    private func syncedQueuedState() {
        queued = UnifiedDownloadManager.shared.downloadRequests.contains {
            $0.bundleIdentifier == app.bundleId
        }
    }

    private struct ITunesAPIClientVersion {
        let version: String
        let date: Date?
        let notes: String?
    }

    private func screenshotStrip(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("screenshots", "Screenshots"))
                .font(T.caption(12))
                .foregroundStyle(p.subtext)
                .padding(.leading, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(screenshots, id: \.self) { raw in
                        DShot(url: raw)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func descriptionCard(_ p: Palette) -> some View {
        DCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("description", "Description"))
                    .font(T.caption(12))
                    .foregroundStyle(p.subtext)
                Text(app.description ?? L("detail_no_description", "This app has no description."))
                    .font(T.body(14))
                    .foregroundStyle(p.text)
                    .lineSpacing(4)
                    .lineLimit(expandedDescription ? nil : 6)
                if let notes = app.releaseNotes, !notes.isEmpty {
                    DHairline().padding(.vertical, 4)
                    Text(L("release_notes", "What's new"))
                        .font(T.caption(12))
                        .foregroundStyle(p.subtext)
                    Text(notes)
                        .font(T.body(13))
                        .foregroundStyle(p.subtext)
                        .lineSpacing(3)
                        .lineLimit(expandedDescription ? nil : 4)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expandedDescription.toggle() }
                } label: {
                    Text(expandedDescription ? L("collapse", "Show less") : L("expand", "Show more"))
                        .font(T.caption(12))
                        .foregroundStyle(p.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func infoCard(_ p: Palette) -> some View {
        DCard {
            VStack(spacing: 0) {
                infoRow(L("developer", "Developer"), app.sellerName ?? app.artistName ?? "-", p)
                DHairline().padding(.vertical, 10)
                infoRow(L("version", "Version"), app.version, p)
                DHairline().padding(.vertical, 10)
                infoRow(L("size", "Size"), readableSize(app.fileSizeBytes), p)
                DHairline().padding(.vertical, 10)
                infoRow(L("minimum_os", "Requires"), app.minimumOsVersion.map { "iOS \($0)" } ?? "-", p)
                if let updated = app.currentVersionReleaseDate, !updated.isEmpty {
                    DHairline().padding(.vertical, 10)
                    infoRow(L("updated", "Updated"), updated, p)
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String, _ p: Palette) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(T.body(13))
                .foregroundStyle(p.subtext)
            Spacer(minLength: 16)
            Text(value)
                .font(T.medium(13))
                .foregroundStyle(p.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func readableSize(_ raw: String?) -> String {
        guard let raw, let bytes = Double(raw) else { return "-" }
        let mb = bytes / 1_048_576
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    private func syncQueueState() {
        queued = UnifiedDownloadManager.shared.downloadRequests.contains {
            $0.package.bundleIdentifier == app.bundleId
        }
    }

    private func startDownload() {
        guard !busy else { return }
        guard let account = store.selectedAccount else {
            errorText = L("no_account", "No account signed in")
            Haptics.warning()
            return
        }
        errorText = nil
        busy = true

        Task {
            let outcome = await PurchaseManager.shared.purchaseAppIfNeeded(
                appIdentifier: String(app.trackId),
                account: account,
                countryCode: account.countryCode,
                isFree: (app.price ?? 0) == 0,
                deviceFamily: .phone
            )

            await MainActor.run {
                switch outcome {
                case .failure(let err):
                    errorText = err.errorDescription ?? err.localizedDescription
                    busy = false
                    Haptics.warning()
                case .success:
                    enqueue()
                    busy = false
                    queued = true
                    Haptics.success()
                }
            }
        }
    }

    @MainActor
    private func enqueue() {
        let manager = UnifiedDownloadManager.shared
        if let existing = manager.downloadRequests.first(where: {
            $0.package.bundleIdentifier == app.bundleId
        }) {
            manager.startDownload(for: existing)
            return
        }
        let id = manager.addDownload(
            bundleIdentifier: app.bundleId,
            name: app.trackName,
            version: app.version,
            identifier: app.trackId,
            iconURL: app.artworkUrl512,
            versionId: nil,
            price: app.price,
            currency: app.currency
        )
        if let request = manager.downloadRequests.first(where: { $0.id == id }) {
            manager.startDownload(for: request)
        }
    }
}

private struct DShot: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme

    let url: String

    var body: some View {
        let p = Palette(theme, scheme)
        Group {
            if let link = URL(string: url) {
                AsyncImage(url: link) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        p.fill
                    }
                }
            } else {
                p.fill
            }
        }
        .frame(width: 158, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(p.line, lineWidth: 1)
        )
    }
}
