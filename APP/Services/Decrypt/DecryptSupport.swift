import Foundation

// MARK: - Workspace

/// A throwaway directory for one job: unpack, patch, repack, then delete.
struct DecryptWorkspace {
    let root: URL

    static func create() -> DecryptWorkspace? {
        let manager = FileManager.default
        guard let base = try? manager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let workBase = base.appendingPathComponent(".decrypt-work", isDirectory: true)
        try? manager.createDirectory(at: workBase, withIntermediateDirectories: true)
        let root = workBase.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            return DecryptWorkspace(root: root)
        } catch {
            return nil
        }
    }

    func destroy() {
        try? FileManager.default.removeItem(at: root)
    }

    var payloadURL: URL {
        root.appendingPathComponent("Payload", isDirectory: true)
    }

    func appBundle() throws -> URL {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: payloadURL.path)) ?? []
        guard let name = entries.first(where: { $0.hasSuffix(".app") }) else {
            throw DecryptError.noAppBundle
        }
        return payloadURL.appendingPathComponent(name, isDirectory: true)
    }

    func hasCapacity(for source: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int64) ?? 0
        // Unpacked payload plus the repacked archive.
        let needed = size * 3
        guard let capacity = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage else { return true }
        return capacity >= needed
    }

    func freeSpaceDescription(neededFor source: URL) -> (free: Int64, needed: Int64) {
        let size = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int64) ?? 0
        let capacity = (try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage) ?? 0
        return (capacity, size * 3)
    }
}

// MARK: - Bundle metadata

struct DecryptBundleInfo {
    let bundleName: String
    let identifier: String
    let version: String

    init(bundle: URL) throws {
        let infoURL = bundle.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let info = plist as? [String: Any] else {
            throw DecryptError.badInfoPlist
        }
        bundleName = bundle.deletingPathExtension().lastPathComponent
        identifier = info["CFBundleIdentifier"] as? String ?? ""
        let short = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        version = short.isEmpty ? build : (build.isEmpty ? short : "\(short) (\(build))")
    }
}

// MARK: - Sinf replication

/// Encrypted App Store bundles ship one `SC_Info/*.sinf` and a Manifest that
/// lists paths needing the same file. Frameworks and extensions fail decryption
/// without those copies, so they are materialised before walking the tree.
enum DecryptSinf {

    @discardableResult
    static func replicate(in bundle: URL) -> Int {
        let manager = FileManager.default
        let manifestURL = bundle.appendingPathComponent("SC_Info/Manifest.plist")
        guard let data = try? Data(contentsOf: manifestURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let manifest = plist as? [String: Any] else { return 0 }

        let sources = manifest["SinfPaths"] as? [String] ?? []
        let targets = manifest["SinfReplicationPaths"] as? [String] ?? []
        guard let first = sources.first else { return 0 }
        let sourceURL = bundle.appendingPathComponent(first)
        guard manager.fileExists(atPath: sourceURL.path) else { return 0 }

        var copied = 0
        for relative in targets {
            let destination = bundle.appendingPathComponent(relative)
            guard !manager.fileExists(atPath: destination.path) else { continue }
            try? manager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if (try? manager.copyItem(at: sourceURL, to: destination)) != nil {
                copied += 1
            }
        }
        return copied
    }
}

// MARK: - Mach-O scan

enum DecryptMachO {

    struct Entry {
        let path: String
        let encrypted: Bool
        let byteCount: Int64
    }

    static func scan(bundle: URL) -> [Entry] {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: bundle,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var entries: [Entry] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            let size = Int64(values?.fileSize ?? 0)
            guard size > 4096 else { continue }
            guard isMachOHead(url) else { continue }
            entries.append(
                Entry(
                    path: relativePath(url, in: bundle),
                    encrypted: isEncrypted(url),
                    byteCount: size
                )
            )
        }
        return entries
    }

    // MARK: Header parsing

    private static let magic32: UInt32 = 0xFEEDFACE
    private static let magic64: UInt32 = 0xFEEDFACF
    private static let magicFatBE: UInt32 = 0xCAFEBABE
    private static let magicFatLE: UInt32 = 0xBEBAFECA
    private static let lcEncryptionInfo: UInt32 = 0x21
    private static let lcEncryptionInfo64: UInt32 = 0x2C

    static func isMachOHead(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 4), head.count == 4 else { return false }
        let raw = u32(head, 0)
        return raw == magic32 || raw == magic64 || raw == magicFatBE || raw == magicFatLE
            || raw.byteSwapped == magic32 || raw.byteSwapped == magic64
    }

    /// True when any slice carries `LC_ENCRYPTION_INFO[_64]` with cryptid != 0.
    static func isEncrypted(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 8), head.count == 8 else { return false }

        let magic = u32(head, 0)
        if magic == magicFatBE || magic.byteSwapped == magicFatBE {
            return fatContainsEncryption(handle: handle, bigEndian: magic == magicFatBE)
        }
        let thinBigEndian = magic.byteSwapped == magic32 || magic.byteSwapped == magic64
        let is64 = (magic == magic64) || (magic.byteSwapped == magic64)
        return thinContainsEncryption(handle: handle, offset: 0, is64: is64, bigEndian: thinBigEndian)
    }

    private static func fatContainsEncryption(handle: FileHandle, bigEndian: Bool) -> Bool {
        guard let countData = try? handle.read(upToCount: 4), countData.count == 4 else { return false }
        var archCount = Int(u32(countData, 0).byteSwapped)
        if archCount <= 0 || archCount > 32 {
            archCount = Int(u32(countData, 0))
        }
        guard archCount > 0, archCount <= 32 else { return false }

        for _ in 0..<archCount {
            guard let entry = try? handle.read(upToCount: 20), entry.count == 20 else { return false }
            let offset = UInt64(u32(entry, 8).byteSwapped)
            if thinContainsEncryption(handle: handle, offset: offset, is64: true, bigEndian: false) {
                return true
            }
        }
        return false
    }

    private static func thinContainsEncryption(
        handle: FileHandle,
        offset: UInt64,
        is64: Bool,
        bigEndian: Bool
    ) -> Bool {
        guard (try? handle.seek(toOffset: offset)) != nil else { return false }
        let headerSize = is64 ? 32 : 28
        guard let header = try? handle.read(upToCount: headerSize), header.count == headerSize else {
            return false
        }

        var ncmds = u32(header, 16)
        if bigEndian { ncmds = ncmds.byteSwapped }
        guard ncmds > 0, ncmds < 4096 else { return false }

        var position = offset + UInt64(headerSize)
        for _ in 0..<ncmds {
            guard (try? handle.seek(toOffset: position)) != nil,
                  let command = try? handle.read(upToCount: 8),
                  command.count == 8 else { return false }

            var cmd = u32(command, 0)
            var cmdSize = u32(command, 4)
            if bigEndian {
                cmd = cmd.byteSwapped
                cmdSize = cmdSize.byteSwapped
            }
            guard cmdSize >= 8, cmdSize < 65536 else { return false }

            if cmd == lcEncryptionInfo || cmd == lcEncryptionInfo64 {
                guard let body = try? handle.read(upToCount: 12), body.count == 12 else { return false }
                var cryptid = u32(body, 8)
                if bigEndian { cryptid = cryptid.byteSwapped }
                return cryptid != 0
            }

            position += UInt64(cmdSize)
        }
        return false
    }

    // MARK: Helpers

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }

    static func relativePath(_ url: URL, in bundle: URL) -> String {
        let base = bundle.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        guard full.hasPrefix(base) else { return url.lastPathComponent }
        return String(full.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
