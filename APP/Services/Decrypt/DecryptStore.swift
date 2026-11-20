import Foundation

/// Persists the history list next to the exported archives.
@MainActor
final class DecryptStore: ObservableObject {
    static let shared = DecryptStore()

    @Published private(set) var records: [DecryptRecord] = []

    private let manager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? manager.createDirectory(at: DecryptEngine.outputDirectory, withIntermediateDirectories: true)
        load()
        pruneMissingOutputs()
    }

    // MARK: - Mutation

    func upsert(_ record: DecryptRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.insert(record, at: 0)
        }
        save()
    }

    func remove(id: UUID) {
        if let record = records.first(where: { $0.id == id }),
           let path = record.outputPath {
            try? manager.removeItem(atPath: path)
        }
        records.removeAll { $0.id == id }
        save()
    }

    func record(forOutput path: String) -> DecryptRecord? {
        records.first { $0.outputPath == path && $0.isCompleted }
    }

    // MARK: - Persistence

    private var indexURL: URL {
        DecryptEngine.outputDirectory.appendingPathComponent("index.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? decoder.decode([DecryptRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// Drops entries whose archive was removed outside the app.
    private func pruneMissingOutputs() {
        let alive = records.filter { record in
            guard let path = record.outputPath else { return false }
            return manager.fileExists(atPath: path)
        }
        guard alive.count != records.count else { return }
        records = alive
        save()
    }
}
