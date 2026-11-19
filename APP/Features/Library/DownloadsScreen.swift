import Foundation
import SwiftUI

struct DownloadsScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var manager: UnifiedDownloadManager
    @Environment(\.colorScheme) private var scheme

    @State private var showDecrypt = false

    private var requests: [DownloadRequest] {
        manager.downloadRequests.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack {
            VStack(spacing: 0) {
                header(p)
                ScrollView {
                    VStack(spacing: 10) {
                        if requests.isEmpty {
                            DEmpty(
                                symbol: "arrow.down.to.line",
                                title: "no_downloads".localized,
                                message: L("downloads_empty_hint", "Apps you start from Search or Purchased land here.")
                            )
                        } else {
                            ForEach(requests, id: \.id) { request in
                                NavigationLink {
                                    DownloadDetailScreen(request: request)
                                } label: {
                                    DownloadRow(request: request)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    .padding(.horizontal, G.gutter)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    manager.saveDownloadTasks()
                }
            }
            .appCanvas(p)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showDecrypt) {
                DecryptScreen()
            }
        }
    }

    private func header(_ p: Palette) -> some View {
        HStack(alignment: .top) {
            DTitle(text: "tab_downloads".localized, subtitle: summary)
            Spacer(minLength: 8)
            DIconButton(symbol: "waveform.path.ecg") {
                Haptics.tap()
                showDecrypt = true
            }
        }
        .padding(.horizontal, G.gutter)
        .padding(.top, G.headerTop)
        .padding(.bottom, 10)
    }

    private var summary: String {
        let active = manager.activeDownloads.count
        let waiting = manager.waitingDownloads.count
        if active == 0 && waiting == 0 {
            return L("downloads_idle", "Queue is empty")
        }
        return "\(active) \(L("active", "active")) · \(waiting) \(L("waiting", "waiting"))"
    }
}

struct DownloadRow: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var manager: UnifiedDownloadManager

    @ObservedObject var request: DownloadRequest

    var body: some View {
        let p = Palette(theme, scheme)
        DCard(padding: 12) {
            HStack(alignment: .center, spacing: 12) {
                DArtwork(url: request.iconURL, size: 48, radius: 12)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(request.name)
                            .font(T.medium(14))
                            .foregroundStyle(p.text)
                            .lineLimit(1)
                        StatusChip(status: request.runtime.status, progress: request.runtime.progressValue)
                    }
                    if request.runtime.status == .downloading {
                        DBar(value: request.runtime.progressValue, height: 3, tint: p.accent)
                            .padding(.top, 1)
                        HStack(spacing: 6) {
                            Text(String(format: "%.0f%%", request.runtime.progressValue * 100))
                            if !request.runtime.speed.isEmpty {
                                Text("·")
                                Text(request.runtime.speed)
                            }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(p.subtext)
                    } else {
                        Text(shortHint)
                            .font(T.body(11))
                            .foregroundStyle(request.runtime.status == .failed ? p.danger : p.subtext)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                actionButton(p)
            }
        }
    }

    private var shortHint: String {
        switch request.runtime.status {
        case .waiting: return "download_waiting".localized
        case .paused: return "download_paused".localized
        case .completed: return "download_completed".localized
        case .failed: return request.runtime.error ?? "download_failed".localized
        case .cancelled: return "status_cancelled".localized
        case .downloading: return ""
        }
    }

    @ViewBuilder
    private func actionButton(_ p: Palette) -> some View {
        switch request.runtime.status {
        case .downloading:
            circleButton("pause.fill", p) { manager.pauseDownload(request: request) }
        case .waiting:
            circleButton("xmark", p) { manager.cancelDownload(request: request) }
        case .paused:
            circleButton("play.fill", p) { manager.resumeDownload(request: request) }
        case .failed, .cancelled:
            circleButton("arrow.clockwise", p) { manager.startDownload(for: request) }
        case .completed:
            circleButton("checkmark", p) { }
        }
    }

    private func circleButton(_ symbol: String, _ p: Palette, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(p.accentSoft(0.12)))
        }
        .buttonStyle(PressableStyle())
    }
}

struct StatusChip: View {
    let status: DownloadStatus
    let progress: Double

    var body: some View {
        switch status {
        case .completed:
            DChip(text: "download_completed".localized, tint: Color(hex: "#3BA55D"))
        case .failed:
            DChip(text: "download_failed".localized, tint: Color(hex: "#E2585F"))
        case .paused:
            DChip(text: "download_paused".localized)
        case .waiting:
            DChip(text: "download_waiting".localized)
        case .cancelled:
            DChip(text: "status_cancelled".localized)
        case .downloading:
            DChip(text: String(format: "%.0f%%", progress * 100))
        }
    }
}
