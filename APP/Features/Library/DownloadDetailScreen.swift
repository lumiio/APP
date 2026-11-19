import SwiftUI

struct DownloadDetailScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var manager: UnifiedDownloadManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var request: DownloadRequest

    @State private var confirmDelete = false
    @State private var showDecrypt = false

    var body: some View {
        let p = Palette(theme, scheme)
        ScrollView {
            VStack(spacing: G.blockGap) {
                DTitle(text: request.name, subtitle: request.bundleIdentifier, onBack: { dismiss() })
                    .padding(.bottom, 2)

                headCard(p)
                progressCard(p)
                actionCard(p)
                fileCard(p)
            }
            .padding(.horizontal, G.gutter)
            .padding(.top, G.headerTop)
            .padding(.bottom, 30)
        }
        .appCanvas(p)
        .toolbar(.hidden, for: .navigationBar)
        .alert(L("delete_download", "Delete this download?"), isPresented: $confirmDelete) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                manager.deleteDownload(request: request)
                dismiss()
            }
        }
        .sheet(isPresented: $showDecrypt) {
            DecryptScreen(initialPath: request.localFilePath)
        }
    }

    private func headCard(_ p: Palette) -> some View {
        DCard {
            HStack(alignment: .top, spacing: 14) {
                DArtwork(url: request.iconURL, size: 70, radius: 17)
                VStack(alignment: .leading, spacing: 6) {
                    Text(request.name)
                        .font(T.headline(16))
                        .foregroundStyle(p.text)
                        .lineLimit(2)
                    Text(request.bundleIdentifier)
                        .font(T.body(11))
                        .foregroundStyle(p.muted)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        DChip(text: L("version", "Version") + " " + request.version)
                        StatusChip(status: request.runtime.status, progress: request.runtime.progressValue)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func progressCard(_ p: Palette) -> some View {
        DCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(statusLabel)
                        .font(T.medium(14))
                        .foregroundStyle(p.text)
                    Spacer()
                    Text(String(format: "%.1f%%", request.runtime.progressValue * 100))
                        .font(T.medium(14))
                        .foregroundStyle(p.accent)
                }
                DBar(value: request.runtime.progressValue, height: 5, tint: p.accent)

                HStack {
                    Text(byteLabel)
                    Spacer()
                    if request.runtime.bytesPerSecond > 0, request.runtime.status == .downloading {
                        Text(speedLabel)
                    }
                }
                .font(T.body(11))
                .foregroundStyle(p.subtext)

                if let error = request.runtime.error, !error.isEmpty {
                    DHairline().padding(.vertical, 2)
                    DNote(text: error, isError: true)
                }
            }
        }
    }

    private var statusLabel: String {
        switch request.runtime.status {
        case .waiting: return "download_waiting".localized
        case .downloading: return L("download_running", "Downloading")
        case .paused: return "download_paused".localized
        case .completed: return "download_completed".localized
        case .failed: return "download_failed".localized
        case .cancelled: return "status_cancelled".localized
        }
    }

    private var byteLabel: String {
        let done = ByteCountFormatter.string(fromByteCount: request.runtime.completedBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: request.runtime.totalBytes, countStyle: .file)
        return "\(done) / \(total)"
    }

    private var speedLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(request.runtime.bytesPerSecond), countStyle: .file) + "/s"
    }

    private func actionCard(_ p: Palette) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                switch request.runtime.status {
                case .downloading:
                    DButton(title: L("pause", "Pause"), icon: "pause.fill", kind: .secondary) {
                        manager.pauseDownload(request: request)
                    }
                case .paused:
                    DButton(title: L("resume", "Resume"), icon: "play.fill") {
                        manager.resumeDownload(request: request)
                    }
                case .completed:
                    DButton(title: L("decrypt", "Decrypt"), icon: "lock.open") {
                        showDecrypt = true
                    }
                case .failed, .cancelled, .waiting:
                    DButton(title: "retry".localized, icon: "arrow.clockwise") {
                        manager.startDownload(for: request)
                    }
                }

                DButton(title: L("delete", "Delete"), icon: "trash", kind: .danger) {
                    confirmDelete = true
                }
            }
        }
    }

    private func fileCard(_ p: Palette) -> some View {
        DCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("file", "File"))
                    .font(T.caption(12))
                    .foregroundStyle(p.subtext)
                Text(request.localFilePath ?? L("file_pending", "Waiting for the package to finish"))
                    .font(T.mono(11))
                    .foregroundStyle(p.text)
                    .lineLimit(3)
                    .textSelection(.enabled)
                if let path = request.localFilePath, request.runtime.status == .completed {
                    let url = URL(fileURLWithPath: path)
                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("export".localized)
                        }
                        .font(T.caption(12))
                        .foregroundStyle(p.accent)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}
