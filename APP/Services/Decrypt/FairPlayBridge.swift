import Foundation

/// Thin, typed layer over the C core in `Vendor/FairPlayedCore`.
/// Every call owns its error buffer and converts a non-zero return into a
/// `DecryptError`, so the rest of the app never sees C strings.
enum FairPlayBridge {

    private static let errorCapacity = 1024

    // MARK: - Archive

    static func unpack(ipa: URL, into destination: URL) throws {
        var buffer = errorBuffer()
        let status = ipa.path.withCString { source in
            destination.path.withCString { target in
                fp_zip_unpack(source, target, &buffer, Int32(errorCapacity))
            }
        }
        guard status == 0 else { throw DecryptError.archive(text(buffer)) }
    }

    static func pack(directory: URL, to output: URL) throws {
        var buffer = errorBuffer()
        let status = directory.path.withCString { source in
            output.path.withCString { target in
                fp_zip_pack(source, target, &buffer, Int32(errorCapacity))
            }
        }
        guard status == 0 else { throw DecryptError.packFailed(text(buffer)) }
    }

    // MARK: - Tree decryption

    struct TreeStats {
        let decrypted: Int
        let plain: Int
        let failed: Int
    }

    static func decryptTree(
        appDirectory: URL,
        cancel: @escaping () -> Bool,
        onEntry: @escaping (String, Int32) -> Void,
        onLog: @escaping (String) -> Void
    ) throws -> TreeStats {
        final class Context {
            let cancel: () -> Bool
            let onEntry: (String, Int32) -> Void
            let onLog: (String) -> Void

            init(cancel: @escaping () -> Bool,
                 onEntry: @escaping (String, Int32) -> Void,
                 onLog: @escaping (String) -> Void) {
                self.cancel = cancel
                self.onEntry = onEntry
                self.onLog = onLog
            }
        }

        let context = Context(cancel: cancel, onEntry: onEntry, onLog: onLog)
        var failed: Int32 = 0
        var skipped: Int32 = 0
        var buffer = errorBuffer()
        let pointer = Unmanaged.passUnretained(context).toOpaque()

        let done: Int32 = withExtendedLifetime(context) { () -> Int32 in
            appDirectory.path.withCString { path in
                fp_decrypt_tree(
                    path,
                    { rawContext, relativePath, entryStatus in
                        guard let rawContext, let relativePath else { return }
                        let context = Unmanaged<Context>.fromOpaque(rawContext).takeUnretainedValue()
                        context.onEntry(String(cString: relativePath), entryStatus)
                    },
                    { rawContext, line in
                        guard let rawContext, let line else { return }
                        let context = Unmanaged<Context>.fromOpaque(rawContext).takeUnretainedValue()
                        context.onLog(String(cString: line))
                    },
                    { rawContext in
                        guard let rawContext else { return false }
                        let context = Unmanaged<Context>.fromOpaque(rawContext).takeUnretainedValue()
                        return context.cancel()
                    },
                    pointer,
                    &failed,
                    &skipped,
                    &buffer,
                    Int32(errorCapacity)
                )
            }
        }

        if done == -2 {
            throw DecryptError.cancelled
        }
        if done < 0 {
            let detail = text(buffer)
            throw DecryptError.archive(detail.isEmpty ? "traversal failed" : detail)
        }

        return TreeStats(decrypted: Int(done), plain: Int(skipped), failed: Int(failed))
    }

    // MARK: - Probe

    /// 1 = encrypted, 0 = plain, negative = unreadable / not Mach-O.
    static func probe(path: String) -> Int32 {
        path.withCString { fp_probe_one($0) }
    }

    // MARK: - Helpers

    private static func errorBuffer() -> [CChar] {
        [CChar](repeating: 0, count: errorCapacity)
    }

    private static func text(_ buffer: [CChar]) -> String {
        String(cString: buffer)
    }
}
