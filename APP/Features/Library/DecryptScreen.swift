import Foundation
import SwiftUI
import UIKit

@MainActor
final class DecryptRunner: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var workingName: String?
    @Published private(set) var notice: String?
    @Published private(set) var phase: DecryptPhase = .prepare
    @Published private(set) var fraction: Double = 0
    @Published private(set) var processed = 0
    @Published private(set) var total = 0

    private var cancelToken: DecryptCancelToken?
    private var keepAlive: UIBackgroundTaskIdentifier = .invalid

    func run(path: String, name: String) async {
        guard !running else { return }
        running = true
        workingName = name
        notice = nil
        fraction = 0
        processed = 0
        total = 0
        phase = .prepare

        let token = DecryptCancelToken()
        cancelToken = token

        let emit: @Sendable (DecryptEvent) -> Void = { [weak self] event in
            Task { @MainActor [weak self] in self?.apply(event) }
        }

        LiveActivityController.shared.showDecrypt(name: name, phase: .prepare, fraction: 0, processed: 0, total: 0)
        beginKeepAlive()

        do {
            let result = try await DecryptEngine.decrypt(
                url: URL(fileURLWithPath: path),
                cancel: token,
                progress: emit
            )
            DecryptStore.shared.upsert(DecryptRecord(result: result, sourcePath: path))
            notice = DecryptRecord(result: result, sourcePath: path).message
            LiveActivityController.shared.finishDecrypt(name: name, success: true, message: notice)
            Haptics.success()
        } catch {
            let record = DecryptRecord(failure: error.localizedDescription, sourcePath: path)
            DecryptStore.shared.upsert(record)
            notice = record.message
            LiveActivityController.shared.finishDecrypt(name: name, success: false, message: record.message)
            Haptics.warning()
        }

        endKeepAlive()
        workingName = nil
        running = false
        cancelToken = nil
    }

    private func beginKeepAlive() {
        endKeepAlive()
        keepAlive = UIApplication.shared.beginBackgroundTask(withName: "APP.decrypt") { [weak self] in
            Task { @MainActor in self?.endKeepAlive() }
        }
    }

    private func endKeepAlive() {
        guard keepAlive != .invalid else { return }
        UIApplication.shared.endBackgroundTask(keepAlive)
        keepAlive = .invalid
    }

    func cancel() {
        cancelToken?.cancel()
    }

    private func apply(_ event: DecryptEvent) {
        switch event {
        case .phase(let value):
            phase = value
            pushActivity()
        case .log:
            break
        case .progress(let done, let count):
            processed = done
            total = count
            fraction = count > 0 ? min(1, Double(done) / Double(count)) : 0
            pushActivity()
        case .failedEntry:
            break
        }
    }

    private func pushActivity() {
        guard let name = workingName else { return }
        LiveActivityController.shared.showDecrypt(
            name: name,
            phase: phase,
            fraction: fraction,
            processed: processed,
            total: total
        )
    }
}

struct DecryptScreen: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var manager: UnifiedDownloadManager
    @EnvironmentObject private var store: DecryptStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var runner = DecryptRunner()
    @State private var selectedPath: String?

    let initialPath: String?

    init(initialPath: String? = nil) {
        self.initialPath = initialPath
    }

    private var candidates: [DownloadRequest] {
        manager.downloadRequests
            .filter { $0.runtime.status == .completed && ($0.localFilePath?.isEmpty == false) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        let p = Palette(theme, scheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: G.sectionGap) {
                    intro(p)
                    if runnersAvailable {
                        pickerSection(p)
                    } else {
                        DNote(text: L("decrypt_unavailable", "FairPlay decryption needs a device that supports it. This build cannot open encrypted binaries here."), isError: false)
                            .padding(.horizontal, G.gutter)
                    }
                    historySection(p)
                }
                .padding(.top, G.headerTop)
                .padding(.bottom, 30)
            }
            .appCanvas(p)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                sheetHeader(p)
            }
            .onAppear {
                if selectedPath == nil { selectedPath = initialPath ?? candidates.first?.localFilePath }
            }
        }
    }

    private var runnersAvailable: Bool {
        DecryptEngine.isAvailable
    }

    private func sheetHeader(_ p: Palette) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("decrypt", "Decrypt"))
                    .font(T.headline(18))
                    .foregroundStyle(p.text)
                Text(L("decrypt_subtitle", "Strip FairPlay encryption from a downloaded IPA"))
                    .font(T.body(12))
                    .foregroundStyle(p.subtext)
            }
            Spacer()
            DIconButton(symbol: "xmark") { dismiss() }
        }
        .padding(.horizontal, G.gutter)
        .padding(.vertical, 12)
        .background(p.canvas)
    }

    private func intro(_ p: Palette) -> some View {
        DCard {
            HStack(alignment: .top, spacing: 12) {
                DTile(symbol: "lock.open", size: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("decrypt_step_title", "Local only"))
                        .font(T.medium(14))
                        .foregroundStyle(p.text)
                    Text(L("decrypt_step_body", "Decryption runs on this device. The result is written to the app's Documents/Decrypted folder and never uploaded."))
                        .font(T.body(12))
                        .foregroundStyle(p.subtext)
                        .lineSpacing(3)
                }
            }
        }
        .padding(.horizontal, G.gutter)
    }

    private func pickerSection(_ p: Palette) -> some View {
        DSection(L("decrypt_source", "Choose a downloaded package")) {
            if candidates.isEmpty {
                DNote(text: L("decrypt_no_source", "Finish a download first, then come back here."))
                    .padding(.horizontal, G.gutter)
            } else {
                DCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, item in
                            Button {
                                Haptics.tap()
                                selectedPath = item.localFilePath
                            } label: {
                                HStack(spacing: 12) {
                                    DArtwork(url: item.iconURL, size: 44, radius: 11)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name)
                                            .font(T.medium(14))
                                            .foregroundStyle(p.text)
                                            .lineLimit(1)
                                        Text(item.bundleIdentifier)
                                            .font(T.body(11))
                                            .foregroundStyle(p.muted)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: selectedPath == item.localFilePath ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 17))
                                        .foregroundStyle(selectedPath == item.localFilePath ? p.accent : p.muted)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                            if index < candidates.count - 1 {
                                DHairline().padding(.leading, 70)
                            }
                        }
                    }
                }
                .padding(.horizontal, G.gutter)

                DButton(
                    title: runningTitle,
                    icon: "lock.open",
                    loading: runner.running,
                    enabled: selectedPath != nil,
                    action: startDecrypt
                )
                .padding(.horizontal, G.gutter)
            }
        }
    }

    private var runningTitle: String {
        guard let name = runner.workingName else {
            return L("decrypt_start", "开始解密")
        }
        if runner.total > 0 {
            let percent = Int(runner.fraction * 100)
            return "\(name) · \(runner.phase.label) \(percent)%"
        }
        return "\(name) · \(runner.phase.label)"
    }

    private func startDecrypt() {
        guard let path = selectedPath else { return }
        let name = candidates.first(where: { $0.localFilePath == path })?.name
            ?? (path as NSString).lastPathComponent
        Task { await runner.run(path: path, name: name) }
    }

    private func historySection(_ p: Palette) -> some View {
        DSection(L("decrypt_history", "Decrypted")) {
            if store.records.isEmpty {
                DNote(text: L("decrypt_history_empty", "Nothing decrypted yet."))
                    .padding(.horizontal, G.gutter)
            } else {
                ForEach(store.records) { record in
                    DCard {
                        HStack(alignment: .top, spacing: 12) {
                            DTile(
                                symbol: record.isCompleted ? "checkmark" : "exclamationmark",
                                tint: record.isCompleted ? Color(hex: "#3BA55D") : Color(hex: "#E2585F"),
                                size: 32
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.appName.isEmpty ? record.name : record.appName)
                                    .font(T.medium(14))
                                    .foregroundStyle(p.text)
                                    .lineLimit(1)
                                Text(record.bundleIdentifier)
                                    .font(T.body(11))
                                    .foregroundStyle(p.muted)
                                    .lineLimit(1)
                                if let message = record.message, !message.isEmpty {
                                    Text(message)
                                        .font(T.body(11))
                                        .foregroundStyle(p.subtext)
                                        .lineLimit(3)
                                }
                                if let output = record.outputPath, !output.isEmpty {
                                    ShareLink(item: URL(fileURLWithPath: output)) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("export".localized)
                                        }
                                        .font(T.caption(11))
                                        .foregroundStyle(p.accent)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, G.gutter)
            }
        }
    }
}
