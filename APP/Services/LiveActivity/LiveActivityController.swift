import ActivityKit
import Foundation

/// Drives the Dynamic Island / lock screen live activity for downloads and
/// decryption. Updates are throttled because the system rate-limits them.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<DeskTaskAttributes>?
    private var currentKind: DeskTaskKind?
    private var lastPush = Date.distantPast
    private var pendingWork: DispatchWorkItem?
    private var lastQueued: DeskTaskAttributes.ContentState?
    private(set) var lastError: String?

    private init() {}

    /// Human readable state, surfaced in About so a broken install is visible.
    var statusText: String {
        if !supported { return "实时活动未开启（系统设置里允许本 App 的实时活动）" }
        if let lastError { return lastError }
        if activity != nil { return "运行中" }
        return "已就绪"
    }

    var supported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Downloads

    /// Rebuilds the download activity from the live queue state.
    func syncDownloads() {
        guard supported else { return }
        let manager = UnifiedDownloadManager.shared
        let requests = manager.downloadRequests

        let active = requests.filter { $0.runtime.status == .downloading }
        let queued = requests.filter { $0.runtime.status == .waiting || $0.runtime.status == .paused }

        guard let lead = active.first else {
            if currentKind == .download {
                let finished = requests.filter { $0.runtime.status == .completed }.count
                let failed = requests.filter { $0.runtime.status == .failed }.count
                finish(
                    state: DeskTaskAttributes.ContentState(
                        title: failed > 0 ? "下载已结束" : "下载完成",
                        subtitle: "\(finished) 个已完成" + (failed > 0 ? "，\(failed) 个失败" : ""),
                        progress: 1,
                        detail: failed > 0 ? "点开 APP 查看失败原因" : "文件已保存到 APP 内",
                        kind: DeskTaskKind.download.rawValue,
                        done: true
                    )
                )
            }
            return
        }

        let state = DeskTaskAttributes.ContentState(
            title: lead.name,
            subtitle: "v\(lead.version)" + (queued.isEmpty ? "" : " · 队列 \(queued.count)"),
            progress: lead.runtime.progressValue,
            detail: detailFor(lead, queued: queued.count),
            kind: DeskTaskKind.download.rawValue,
            done: false
        )
        show(state, kind: .download)
    }

    private func detailFor(_ request: DownloadRequest, queued: Int) -> String {
        let runtime = request.runtime
        var parts: [String] = []
        if runtime.bytesPerSecond > 0 {
            parts.append("\(Self.bytes(runtime.completedBytes))/\(Self.bytes(runtime.totalBytes))")
            parts.append(Self.speed(runtime.bytesPerSecond))
        } else if runtime.totalBytes > 0 {
            parts.append("\(Self.bytes(runtime.completedBytes))/\(Self.bytes(runtime.totalBytes))")
        } else {
            parts.append("正在获取文件大小")
        }
        if runtime.remainingTime > 0 {
            parts.append("剩余 \(Self.duration(runtime.remainingTime))")
        }
        if queued > 0 {
            parts.append("后面还有 \(queued) 个")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Decrypt

    func showDecrypt(name: String, phase: DecryptPhase, fraction: Double, processed: Int, total: Int) {
        guard supported else { return }
        let detail: String
        if total > 0 {
            detail = "\(processed)/\(total) 个二进制 · \(Int((fraction * 100).rounded()))%"
        } else {
            detail = phase.label
        }
        let state = DeskTaskAttributes.ContentState(
            title: name,
            subtitle: "脱壳解密 · " + phase.label,
            progress: fraction,
            detail: detail,
            kind: DeskTaskKind.decrypt.rawValue,
            done: false
        )
        show(state, kind: .decrypt)
    }

    func finishDecrypt(name: String, success: Bool, message: String?) {
        guard supported, currentKind == .decrypt else { return }
        finish(
            state: DeskTaskAttributes.ContentState(
                title: name,
                subtitle: success ? "脱壳完成" : "脱壳失败",
                progress: success ? 1 : 0,
                detail: message ?? (success ? "已导出到 Decrypted 目录" : "点开 APP 查看原因"),
                kind: DeskTaskKind.decrypt.rawValue,
                done: success
            )
        )
    }

    // MARK: - Core

    private func show(_ state: DeskTaskAttributes.ContentState, kind: DeskTaskKind) {
        guard supported else { return }

        if activity == nil || currentKind != kind {
            if currentKind != nil { endSilently() }
            let attributes = DeskTaskAttributes(kind: kind.rawValue, startedAt: Date())
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(120)),
                    pushType: nil
                )
                currentKind = kind
                lastError = nil
                lastPush = Date()
                return
            } catch {
                lastError = "无法创建实时活动：\(error.localizedDescription)"
                return
            }
        }

        let now = Date()
        if now.timeIntervalSince(lastPush) < 1.2 {
            lastQueued = state
            pendingWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let queued = self.lastQueued else { return }
                self.lastQueued = nil
                self.push(queued)
            }
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
            return
        }
        push(state)
    }

    private func push(_ state: DeskTaskAttributes.ContentState) {
        guard let activity else { return }
        lastPush = Date()
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
        Task { await activity.update(content) }
        if state.done {
            Activity<DeskTaskAttributes>.activities
                .filter { $0.id == activity.id }
                .forEach { handle in
                    Task { await handle.end(content, dismissalPolicy: .after(Date().addingTimeInterval(6))) }
                }
            self.activity = nil
            currentKind = nil
        }
    }

    private func finish(state: DeskTaskAttributes.ContentState) {
        pendingWork?.cancel()
        pendingWork = nil
        lastQueued = nil
        lastPush = .distantPast
        show(state, kind: currentKind ?? .download)
    }

    /// Drives a fake task for ~20 seconds so the Dynamic Island can be verified.
    func startDemo() {
        guard supported else {
            lastError = "实时活动不可用"
            return
        }
        endSilently()
        lastError = nil
        runDemoStep(0)
    }

    private func runDemoStep(_ step: Int) {
        guard step <= 20 else { return }
        show(
            DeskTaskAttributes.ContentState(
                title: "灵动岛测试",
                subtitle: "下载 · APP 2.7.1",
                progress: min(1, Double(step) / 20),
                detail: "第 \(step) 步 / 20 · 测试进度显示",
                kind: DeskTaskKind.download.rawValue,
                done: false
            ),
            kind: .download
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.runDemoStep(step + 1)
        }
    }

    private func endSilently() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
        currentKind = nil
    }

    // MARK: - Formatting

    private static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, value))
    }

    private static func speed(_ value: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(max(0, value))) + "/s"
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        return String(format: "%.1fh", seconds / 3600)
    }
}
