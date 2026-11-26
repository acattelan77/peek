import Foundation
import os

/// Writes diagnostic events to the unified log (one `Logger` per category) and
/// to a small journal in Application Support that "Export diagnostics" reads.
/// Most events are info level, which macOS does not keep on disk: watch them
/// live with `log stream --level info --predicate 'subsystem == "com.peek.app"'`,
/// or read the journal. `log show` afterwards finds only notice and error lines
/// (the launch line is always notice).
/// Nothing leaves the Mac. Messages are built only from `DiagnosticEvent`, so
/// they hold no meeting content and are logged as public.
final class DiagnosticsLog {
    static let shared = DiagnosticsLog()

    static let subsystem = Bundle.main.bundleIdentifier ?? "com.peek.app"

    private let loggers: [DiagnosticCategory: Logger]
    private let journalURL: URL?
    private let queue = DispatchQueue(label: "com.peek.diagnostics.journal")
    private var entries: [DiagnosticEntry] = []
    private var throttle = DiagnosticThrottle()
    private var loaded = false
    private var appendedSinceCompaction = 0

    init(journalURL: URL? = DiagnosticsLog.defaultJournalURL()) {
        self.journalURL = journalURL
        var loggers: [DiagnosticCategory: Logger] = [:]
        for category in DiagnosticCategory.allCases {
            loggers[category] = Logger(subsystem: Self.subsystem, category: category.rawValue)
        }
        self.loggers = loggers
    }

    static func directoryURL() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appendingPathComponent("Peek", isDirectory: true).appendingPathComponent("Diagnostics", isDirectory: true)
    }

    static func defaultJournalURL() -> URL? {
        directoryURL()?.appendingPathComponent("journal.jsonl")
    }

    /// Records an event. With a `throttleKey`, the same key is written at most
    /// once per `minInterval`.
    func record(
        _ event: DiagnosticEvent,
        throttleKey: String? = nil,
        minInterval: TimeInterval = 0,
        now: Date = Date()
    ) {
        queue.sync {
            if let throttleKey, !throttle.shouldLog(key: throttleKey, minInterval: minInterval, now: now) {
                return
            }
            write(event, now: now)
        }
    }

    /// The journal, oldest first, already pruned.
    func journal(now: Date = Date()) -> [DiagnosticEntry] {
        queue.sync {
            loadIfNeeded(now: now)
            return DiagnosticsRetention.prune(entries, now: now)
        }
    }

    // MARK: - Private, on `queue`

    private func write(_ event: DiagnosticEvent, now: Date) {
        let message = event.message
        let logger = loggers[event.category] ?? Logger(subsystem: Self.subsystem, category: event.category.rawValue)
        switch event.level {
        case .info: logger.info("\(message, privacy: .public)")
        case .notice: logger.notice("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }

        loadIfNeeded(now: now)
        let entry = DiagnosticEntry(date: now, category: event.category, level: event.level, message: message)
        entries.append(entry)
        append(entry)
        appendedSinceCompaction += 1
        if appendedSinceCompaction >= 200 || entries.count > DiagnosticsRetention.journalMaxEntries * 2 {
            compact(now: now)
        }
    }

    private func loadIfNeeded(now: Date) {
        guard !loaded else { return }
        loaded = true
        guard let journalURL, let data = try? Data(contentsOf: journalURL) else { return }
        let decoder = Self.decoder
        let loadedEntries = data.split(separator: UInt8(ascii: "\n")).compactMap {
            try? decoder.decode(DiagnosticEntry.self, from: Data($0))
        }
        entries = loadedEntries + entries
        compact(now: now)
    }

    private func append(_ entry: DiagnosticEntry) {
        guard let journalURL, var line = try? Self.encoder.encode(entry) else { return }
        line.append(UInt8(ascii: "\n"))
        let manager = FileManager.default
        try? manager.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: journalURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: journalURL, options: .atomic)
        }
    }

    private func compact(now: Date) {
        entries = DiagnosticsRetention.prune(entries, now: now)
        appendedSinceCompaction = 0
        guard let journalURL else { return }
        var data = Data()
        for entry in entries {
            guard let line = try? Self.encoder.encode(entry) else { continue }
            data.append(line)
            data.append(UInt8(ascii: "\n"))
        }
        try? FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: journalURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// The short form used at call sites: `Diagnostics.record(.notificationsCleared)`.
enum Diagnostics {
    static func record(
        _ event: DiagnosticEvent,
        throttleKey: String? = nil,
        minInterval: TimeInterval = 0
    ) {
        DiagnosticsLog.shared.record(event, throttleKey: throttleKey, minInterval: minInterval)
    }
}
