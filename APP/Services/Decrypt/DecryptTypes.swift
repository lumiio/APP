import Foundation

// MARK: - Status

enum DecryptStatus: String, Codable {
    case completed
    case pending
    case blocked
    case failed
}

// MARK: - Phase

/// Ordered pipeline phases. The UI only needs to know which stage is running.
enum DecryptPhase: String, Sendable {
    case prepare
    case extract
    case scan
    case decrypt
    case package
    case done

    var label: String {
        switch self {
        case .prepare: return L("dc_phase_prepare", "准备")
        case .extract: return L("dc_phase_extract", "解包")
        case .scan: return L("dc_phase_scan", "扫描")
        case .decrypt: return L("dc_phase_decrypt", "解密")
        case .package: return L("dc_phase_package", "打包")
        case .done: return L("dc_phase_done", "完成")
        }
    }
}

// MARK: - Events

enum DecryptEvent: Sendable {
    case phase(DecryptPhase)
    case log(String)
    case progress(processed: Int, total: Int)
    case failedEntry(String)
}

// MARK: - Errors

enum DecryptError: LocalizedError {
    case missingSource
    case noWorkspace
    case lowSpace(free: Int64, needed: Int64)
    case archive(String)
    case noAppBundle
    case badInfoPlist
    case packFailed(String)
    case notDecryptable(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingSource:
            return L("dc_err_missing", "找不到源安装包")
        case .noWorkspace:
            return L("dc_err_nowork", "无法创建临时工作目录")
        case .lowSpace(let free, let needed):
            let f = DecryptFormat.bytes(free)
            let n = DecryptFormat.bytes(needed)
            return L("dc_err_space", "空间不足：可用 \(f)，需要 \(n)")
        case .archive(let detail):
            return L("dc_err_unzip", "解包失败") + (detail.isEmpty ? "" : "（\(detail)）")
        case .noAppBundle:
            return L("dc_err_no_binary", "安装包里没有 Payload/*.app")
        case .badInfoPlist:
            return L("dc_err_plist", "Info.plist 读取失败")
        case .packFailed(let detail):
            return L("dc_err_copy", "打包失败") + (detail.isEmpty ? "" : "（\(detail)）")
        case .notDecryptable(let detail):
            let base = L("dc_err_not_decryptable", "主二进制被 FairPlay 拒绝，无法解密")
            return detail.isEmpty ? base : base + "（\(detail)）"
        case .cancelled:
            return L("dc_err_cancelled", "已取消")
        }
    }
}

// MARK: - Cancel token

final class DecryptCancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

// MARK: - Result

struct DecryptResult: Sendable {
    let appName: String
    let bundleIdentifier: String
    let version: String
    let binaryCount: Int
    let encryptedCount: Int
    let decryptedCount: Int
    let plainCount: Int
    let failedCount: Int
    let outputURL: URL
    let duration: TimeInterval

    var wasPlainCopy: Bool { decryptedCount == 0 && failedCount == 0 }
}

// MARK: - Record

struct DecryptRecord: Identifiable, Codable {
    let id: UUID
    let name: String
    var appName: String
    var bundleIdentifier: String
    var version: String?
    var binaryCount: Int
    var encryptedCount: Int
    var status: DecryptStatus
    var message: String?
    var outputPath: String?
    var sourcePath: String?
    let createdAt: Date

    var isCompleted: Bool { status == .completed }

    init(result: DecryptResult, sourcePath: String) {
        self.id = UUID()
        self.name = result.outputURL.lastPathComponent
        self.appName = result.appName
        self.bundleIdentifier = result.bundleIdentifier
        self.version = result.version
        self.binaryCount = result.binaryCount
        self.encryptedCount = result.encryptedCount
        self.status = .completed
        self.message = result.wasPlainCopy
            ? L("dc_done_plain", "该包未加密，已原样导出")
            : L("dc_done_detail", "解密 \(result.decryptedCount) 个，失败 \(result.failedCount) 个")
        self.outputPath = result.outputURL.path
        self.sourcePath = sourcePath
        self.createdAt = Date()
    }

    init(failure message: String, sourcePath: String) {
        let url = URL(fileURLWithPath: sourcePath)
        self.id = UUID()
        self.name = url.lastPathComponent
        self.appName = url.deletingPathExtension().lastPathComponent
        self.bundleIdentifier = ""
        self.version = nil
        self.binaryCount = 0
        self.encryptedCount = 0
        self.status = .failed
        self.message = message
        self.outputPath = nil
        self.sourcePath = sourcePath
        self.createdAt = Date()
    }
}

// MARK: - Formatting

enum DecryptFormat {
    static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: value)
    }

    static func seconds(_ value: TimeInterval) -> String {
        value < 1 ? String(format: "%.0f ms", value * 1000) : String(format: "%.1f s", value)
    }
}
