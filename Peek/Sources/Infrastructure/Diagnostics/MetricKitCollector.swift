import Foundation
import MetricKit

/// Receives MetricKit's daily metric payloads and its crash, hang and
/// energy diagnostic payloads, and keeps them in Application Support for
/// 30 days so "Export diagnostics" can include them. MetricKit delivers
/// them to the app itself; Peek sends nothing anywhere.
final class MetricKitCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricKitCollector()

    let store: MetricPayloadStore

    init(store: MetricPayloadStore = MetricPayloadStore()) {
        self.store = store
        super.init()
    }

    func start() {
        store.pruneExpired()
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if store.save(payload.jsonRepresentation(), kind: .metrics) {
                Diagnostics.record(.metricPayloadSaved(kind: MetricPayloadStore.Kind.metrics.rawValue))
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if store.save(payload.jsonRepresentation(), kind: .diagnostics) {
                Diagnostics.record(.metricPayloadSaved(kind: MetricPayloadStore.Kind.diagnostics.rawValue))
            }
        }
    }
}

/// The folder of saved MetricKit payloads, one JSON file each.
struct MetricPayloadStore {
    enum Kind: String {
        case metrics
        case diagnostics
    }

    struct SavedPayload: Equatable {
        let fileName: String
        let created: Date
        let data: Data
    }

    let directory: URL?
    private let fileManager: FileManager

    init(directory: URL? = DiagnosticsLog.directoryURL()?.appendingPathComponent("MetricKit", isDirectory: true),
         fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    @discardableResult
    func save(_ data: Data, kind: Kind, now: Date = Date()) -> Bool {
        guard let directory, !data.isEmpty else { return false }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let stamp = Int(now.timeIntervalSince1970 * 1000)
            let url = directory.appendingPathComponent("\(kind.rawValue)-\(stamp)-\(UUID().uuidString.prefix(8)).json")
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Every saved payload, oldest first.
    func all() -> [SavedPayload] {
        files().sorted { $0.created < $1.created }.compactMap { file in
            guard let data = try? Data(contentsOf: file.url) else { return nil }
            return SavedPayload(fileName: file.url.lastPathComponent, created: file.created, data: data)
        }
    }

    /// Deletes payloads older than 30 days. Returns how many were deleted.
    @discardableResult
    func pruneExpired(now: Date = Date()) -> Int {
        let expired = DiagnosticsRetention.expiredPayloads(files(), now: now)
        for url in expired {
            try? fileManager.removeItem(at: url)
        }
        return expired.count
    }

    private func files() -> [(url: URL, created: Date)] {
        guard let directory,
              let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }
        return urls.filter { $0.pathExtension == "json" }.map { url in
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return (url, created)
        }
    }
}
