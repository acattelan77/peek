import Foundation

/// Reads `peek-context.json` from the folder the user chose (PEEK-213). The
/// folder is kept as an app-scoped security bookmark, so the sandboxed App
/// Store build keeps read access across launches. Read-only: Peek never
/// writes, moves or deletes anything in that folder.
final class ContextFolderStore {
    static let shared = ContextFolderStore()

    static let bookmarkKey = "contextFolderBookmark"

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cachedFile: MeetingContextFile?
    private var cachedModificationDate: Date?
    private var lastCheck: Date?
    /// How often the file's modification date is checked at most.
    private let recheckInterval: TimeInterval = 30

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasFolder: Bool {
        defaults.data(forKey: Self.bookmarkKey) != nil
    }

    /// The folder's display name, or nil when none is set or it can't be resolved.
    var folderName: String? {
        resolveFolder()?.url.lastPathComponent
    }

    /// Saves a folder the user picked in an open panel.
    @discardableResult
    func setFolder(_ url: URL) -> Bool {
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return false }
        defaults.set(data, forKey: Self.bookmarkKey)
        invalidate()
        return true
    }

    func removeFolder() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        invalidate()
    }

    /// The context entry for an event occurrence, or nil when no folder is set,
    /// the file is missing or unreadable, or it has no entry for the event.
    func entry(forEventID id: String?, start: Date?) -> MeetingContextFile.Entry? {
        guard let id, !id.isEmpty else { return nil }
        return currentFile()?.entry(forEventID: id, start: start)
    }

    /// The day block to show now, or nil (PEEK-261): no folder or file, no
    /// `day`, another date, nothing to show, or a stale file. Held in memory
    /// only, like the rest of the file; never logged or written anywhere.
    func day(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> MeetingContextFile.Day? {
        currentFile()?.visibleDay(now: now, calendar: calendar)
    }

    /// The file's `generatedAt` when it is stale (PEEK-264), else nil.
    func staleSince(now: Date = Date()) -> Date? {
        guard let file = currentFile(), file.isStale(now: now) else { return nil }
        return file.generatedAt
    }

    /// Why the file isn't being used, for a Preferences footnote.
    func status() -> Status {
        guard hasFolder else { return .noFolder }
        guard let folder = resolveFolder() else { return .folderUnavailable }
        let accessing = folder.url.startAccessingSecurityScopedResource()
        defer { if accessing { folder.url.stopAccessingSecurityScopedResource() } }
        let fileURL = folder.url.appendingPathComponent(MeetingContextFile.fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return .fileMissing }
        do {
            let file = try MeetingContextFile.decode(data)
            return .ready(eventCount: file.entries.count, generatedAt: file.generatedAt)
        } catch MeetingContextFile.DecodeError.unsupportedVersion(let version) {
            return .unsupportedVersion(version)
        } catch {
            return .unreadable
        }
    }

    enum Status: Equatable {
        case noFolder
        case folderUnavailable
        case fileMissing
        case unreadable
        case unsupportedVersion(Int)
        case ready(eventCount: Int, generatedAt: Date?)
    }

    // MARK: Private

    private func invalidate() {
        lock.lock()
        cachedFile = nil
        cachedModificationDate = nil
        lastCheck = nil
        lock.unlock()
    }

    private func currentFile() -> MeetingContextFile? {
        let now = Date()
        lock.lock()
        if let lastCheck, now.timeIntervalSince(lastCheck) < recheckInterval {
            let file = cachedFile
            lock.unlock()
            return file
        }
        lock.unlock()

        let loaded = loadIfChanged()
        lock.lock()
        lastCheck = now
        if let loaded {
            cachedFile = loaded.file
            cachedModificationDate = loaded.modificationDate
        }
        let file = cachedFile
        lock.unlock()
        return file
    }

    /// Reads the file when its modification date changed. Returns nil when it
    /// did not change; a missing or invalid file clears the cache.
    private func loadIfChanged() -> (file: MeetingContextFile?, modificationDate: Date?)? {
        guard let folder = resolveFolder() else { return (nil, nil) }
        let accessing = folder.url.startAccessingSecurityScopedResource()
        defer { if accessing { folder.url.stopAccessingSecurityScopedResource() } }

        let fileURL = folder.url.appendingPathComponent(MeetingContextFile.fileName)
        let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard let modified else { return (nil, nil) }
        lock.lock()
        let unchanged = cachedModificationDate == modified && cachedFile != nil
        lock.unlock()
        if unchanged { return nil }

        guard let data = try? Data(contentsOf: fileURL),
              let file = try? MeetingContextFile.decode(data) else { return (nil, modified) }
        return (file, modified)
    }

    private func resolveFolder() -> (url: URL, isStale: Bool)? {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale {
            // Refresh the bookmark while access still works (folder moved or renamed).
            let accessing = url.startAccessingSecurityScopedResource()
            if let fresh = try? url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                defaults.set(fresh, forKey: Self.bookmarkKey)
            }
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        return (url, isStale)
    }
}
