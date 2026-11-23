import Foundation

/// Keeps generated briefs on disk in Peek's own container, so a relaunch does
/// not call a model again (PEEK-224). Briefs are never logged.
final class BriefCacheStore {
    static let shared = BriefCacheStore()

    /// Briefs older than this are dropped on load.
    static let maxAge: TimeInterval = 3 * 24 * 3600

    private let fileURL: URL?
    private let queue = DispatchQueue(label: "peek.brief-cache")

    init(fileURL: URL? = BriefCacheStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("Peek", isDirectory: true).appendingPathComponent("briefs.json")
    }

    func load(now: Date = Date()) -> [String: MeetingBrief] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([String: MeetingBrief].self, from: data) else { return [:] }
        return stored.filter { now.timeIntervalSince($0.value.generatedAt) < Self.maxAge }
    }

    func save(_ briefs: [String: MeetingBrief]) {
        guard let fileURL else { return }
        queue.async {
            do {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(briefs)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                // A failed cache write only means the brief is generated again.
            }
        }
    }

    func clear() {
        guard let fileURL else { return }
        queue.async { try? FileManager.default.removeItem(at: fileURL) }
    }
}
