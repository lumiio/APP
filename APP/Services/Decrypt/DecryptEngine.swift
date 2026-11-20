import Foundation

/// End-to-end FairPlay job: unpack → materialise sinf → decrypt tree → repack.
/// The engine owns no global state; every call works inside its own temporary
/// workspace and writes the finished IPA to `Documents/Decrypted`.
enum DecryptEngine {

    /// Decryption itself depends on the device, but the pipeline always has a
    /// writable workspace, so the feature is offered and failures surface as
    /// actionable messages instead of hiding the whole screen.
    static var isAvailable: Bool {
        (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) != nil
    }

    static var outputDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Decrypted", isDirectory: true)
    }

    // MARK: - Public API

    static func decrypt(
        url: URL,
        cancel: DecryptCancelToken? = nil,
        progress: (@Sendable (DecryptEvent) -> Void)? = nil
    ) async throws -> DecryptResult {
        try await Task.detached(priority: .userInitiated) {
            try run(url: url, cancel: cancel, emit: progress)
        }.value
    }

    // MARK: - Pipeline

    private static func run(
        url: URL,
        cancel: DecryptCancelToken?,
        emit: (@Sendable (DecryptEvent) -> Void)?
    ) throws -> DecryptResult {
        let started = Date()
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { throw DecryptError.missingSource }
        guard let workspace = DecryptWorkspace.create() else { throw DecryptError.noWorkspace }
        defer { workspace.destroy() }

        let space = workspace.freeSpaceDescription(neededFor: url)
        guard workspace.hasCapacity(for: url) else {
            throw DecryptError.lowSpace(free: space.free, needed: space.needed)
        }

        emit?(.phase(.extract))
        emit?(.log("source \(url.lastPathComponent) \(DecryptFormat.bytes(fileSize(of: url)))"))
        try FairPlayBridge.unpack(ipa: url, into: workspace.root)
        try checkCancelled(cancel)

        let bundle = try workspace.appBundle()
        let info = try DecryptBundleInfo(bundle: bundle)
        emit?(.log("bundle \(info.identifier) \(info.version)"))

        emit?(.phase(.scan))
        let sinfCount = DecryptSinf.replicate(in: bundle)
        if sinfCount > 0 { emit?(.log("sinf copied to \(sinfCount) paths")) }

        let binaries = DecryptMachO.scan(bundle: bundle)
        let encryptedCount = binaries.filter(\.encrypted).count
        emit?(.log("\(binaries.count) Mach-O, \(encryptedCount) encrypted"))
        emit?(.progress(processed: 0, total: binaries.count))

        emit?(.phase(.decrypt))
        var processed = 0
        let stats = try FairPlayBridge.decryptTree(
            appDirectory: bundle,
            cancel: { cancel?.isCancelled ?? false },
            onEntry: { path, status in
                processed += 1
                emit?(.progress(processed: processed, total: binaries.count))
                if status < 0 { emit?(.failedEntry(path)) }
            },
            onLog: { line in
                emit?(.log(line))
            }
        )
        try checkCancelled(cancel)

        if stats.decrypted == 0 && stats.failed > 0 {
            emit?(.log("main binary rejected by FairPlay"))
            throw DecryptError.notDecryptable
        }

        // Nothing was encrypted: keep the original archive byte for byte.
        if stats.decrypted == 0 {
            emit?(.phase(.package))
            let copy = try uniqueOutput(for: url, tag: nil)
            try? manager.removeItem(at: copy)
            try manager.copyItem(at: url, to: copy)
            emit?(.phase(.done))
            return DecryptResult(
                appName: info.bundleName,
                bundleIdentifier: info.identifier,
                version: info.version,
                binaryCount: binaries.count,
                encryptedCount: encryptedCount,
                decryptedCount: 0,
                plainCount: stats.plain,
                failedCount: 0,
                outputURL: copy,
                duration: Date().timeIntervalSince(started)
            )
        }

        emit?(.phase(.package))
        let temporary = workspace.root.appendingPathComponent("repack.ipa")
        try FairPlayBridge.pack(directory: workspace.root, to: temporary)

        let tag: String? = stats.failed > 0 ? "PARTIAL" : nil
        let output = try uniqueOutput(for: url, tag: tag)
        try? manager.removeItem(at: output)
        try manager.moveItem(at: temporary, to: output)

        let size = fileSize(of: output)
        guard size > 0 else { throw DecryptError.packFailed("empty archive") }

        emit?(.phase(.done))
        emit?(.log("wrote \(output.lastPathComponent) \(DecryptFormat.bytes(size))"))

        return DecryptResult(
            appName: info.bundleName,
            bundleIdentifier: info.identifier,
            version: info.version,
            binaryCount: binaries.count,
            encryptedCount: encryptedCount,
            decryptedCount: stats.decrypted,
            plainCount: stats.plain,
            failedCount: stats.failed,
            outputURL: output,
            duration: Date().timeIntervalSince(started)
        )
    }

    // MARK: - Helpers

    private static func checkCancelled(_ token: DecryptCancelToken?) throws {
        if token?.isCancelled == true { throw DecryptError.cancelled }
    }

    private static func fileSize(of url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    /// `Name-decrypted.ipa`, `Name-PARTIAL.ipa`, or `Name.ipa` when untouched;
    /// append `-2`, `-3` rather than overwriting an earlier export.
    private static func uniqueOutput(for source: URL, tag: String?) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let stem = source.deletingPathExtension().lastPathComponent
        let suffix = tag.map { "-\($0)" } ?? ""
        var candidate = outputDirectory.appendingPathComponent("\(stem)\(suffix).ipa")
        var index = 2
        while manager.fileExists(atPath: candidate.path), candidate != source {
            candidate = outputDirectory.appendingPathComponent("\(stem)\(suffix)-\(index).ipa")
            index += 1
        }
        return candidate
    }
}
