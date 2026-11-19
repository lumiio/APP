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

    var body: some View {
        let p = Palette(theme, scheme)
        ScrollView {
            VStack(spacing: G.blockGap) {
                if !AppChrome.usesSystemBars {
                    DTitle(text: app.trackName, subtitle: app.artistName ?? app.sellerName, onBack: { dismiss() })
                        .padding(.bottom, 2)
                }

                headlineCard(p)
                actionArea(p)
                if !screenshots.isEmpty { screenshotStrip(p) }
                descriptionCard(p)
                infoCard(p)
            }
            .padding(.horizontal, G.gutter)
            .padding(.top, G.headerTop)
            .padding(.bottom, 30)
        }
        .appCanvas(p)
        .adaptiveNavChrome()
        .navigationTitle(app.trackName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncQueueState)
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
