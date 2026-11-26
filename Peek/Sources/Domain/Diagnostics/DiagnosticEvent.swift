import CryptoKit
import Foundation

/// Local diagnostics (PEEK-275, ADR 0006). Every log line Peek writes is built
/// from one of these typed events, never from free text, so a message can
/// carry counts, outcomes, durations and fixed reasons but no event title,
/// note, attendee, location, link or path. The formatter is the only place
/// that turns an event into text, and the tests check it.
enum DiagnosticCategory: String, CaseIterable, Codable {
    case app
    case calendar
    case notifications
    case alerts
    case context
    case brief
    case hotkey
    case metrics
}

enum DiagnosticLevel: String, Codable {
    case info
    case notice
    case error
}

enum DiagnosticAlertKind: String, Codable {
    /// The "Starting now" heads-up card.
    case startCard
    /// The full-screen start alert.
    case startFullScreen
    /// The 2-minute heads-up card of the alert ladder.
    case soonCard
}

enum DiagnosticAlertSkipReason: String, Codable {
    /// The event's calendar is set to badge only.
    case badgeOnly
    /// The alert for this event was already shown.
    case alreadyShown
    /// The start alert is off, or limited to meetings and this event is not one.
    case filtered
}

enum DiagnosticRescheduleReason: String, Codable {
    /// Calendar access or notification permission was just granted.
    case permission
    /// The events that notify changed.
    case eventsChanged
    /// A setting that affects notifications changed, or a retry ran.
    case forced
    /// A wake, or a time zone, clock or day change (PEEK-271).
    case systemTime
}

/// What the context folder looked like when Peek last read it. Mirrors
/// `ContextFolderStore.Status` without its payload.
enum DiagnosticContextState: String, Codable {
    case noFolder
    case folderUnavailable
    case fileMissing
    case unreadable
    case unsupportedVersion
    case ready
    case stale
}

enum DiagnosticEvent: Equatable {
    case appLaunched(version: String, build: String, system: String)
    case calendarAccess(granted: Bool, errorCode: Int?)
    case calendarRefreshed(durationMs: Int, eventCount: Int, calendarCount: Int)
    case calendarRefreshFailed(errorCode: Int)
    case notificationPermission(granted: Bool, errorCode: Int?)
    case notificationsRescheduled(reason: DiagnosticRescheduleReason, eventCount: Int)
    case notificationsRequested(requestCount: Int)
    case notificationsScheduled(result: String)
    case notificationsCleared
    case notificationSnoozed(minutes: Int)
    case alertShown(kind: DiagnosticAlertKind, eventRef: String)
    case alertSkipped(kind: DiagnosticAlertKind, reason: DiagnosticAlertSkipReason, eventRef: String)
    case hotkeyRegistrationFailed(shortcut: String)
    case contextFile(state: DiagnosticContextState, eventCount: Int)
    case briefFinished(source: String, outcome: String)
    case metricPayloadSaved(kind: String)
    case diagnosticsExported(entryCount: Int, payloadCount: Int)

    var category: DiagnosticCategory {
        switch self {
        case .appLaunched, .diagnosticsExported: return .app
        case .calendarAccess, .calendarRefreshed, .calendarRefreshFailed: return .calendar
        case .notificationPermission, .notificationsRescheduled, .notificationsRequested, .notificationsScheduled,
             .notificationsCleared, .notificationSnoozed: return .notifications
        case .alertShown, .alertSkipped: return .alerts
        case .contextFile: return .context
        case .briefFinished: return .brief
        case .hotkeyRegistrationFailed: return .hotkey
        case .metricPayloadSaved: return .metrics
        }
    }

    var level: DiagnosticLevel {
        switch self {
        case .appLaunched:
            // macOS keeps only default (notice) and higher in the persistent log;
            // info lines are visible to `log stream --level info` only while they
            // happen. The launch line is notice so `log show` always has a marker.
            return .notice
        case .calendarAccess(let granted, _), .notificationPermission(let granted, _):
            return granted ? .info : .notice
        case .calendarRefreshFailed, .hotkeyRegistrationFailed:
            return .error
        case .notificationsScheduled(let result):
            return result == "failed" ? .error : .info
        case .contextFile(let state, _):
            switch state {
            case .folderUnavailable, .unreadable, .unsupportedVersion: return .error
            case .fileMissing, .stale: return .notice
            case .noFolder, .ready: return .info
            }
        case .briefFinished(_, let outcome):
            return outcome == "success" ? .info : .notice
        case .alertSkipped:
            return .notice
        default:
            return .info
        }
    }

    /// The one line written to the unified log and the diagnostics journal.
    var message: String {
        switch self {
        case let .appLaunched(version, build, system):
            return "launched version=\(version) build=\(build) macOS=\(system)"
        case let .calendarAccess(granted, errorCode):
            return "access granted=\(granted)" + Self.code(errorCode)
        case let .calendarRefreshed(durationMs, eventCount, calendarCount):
            return "refresh durationMs=\(durationMs) events=\(eventCount) calendars=\(calendarCount)"
        case let .calendarRefreshFailed(errorCode):
            return "refresh failed" + Self.code(errorCode)
        case let .notificationPermission(granted, errorCode):
            return "permission granted=\(granted)" + Self.code(errorCode)
        case let .notificationsRescheduled(reason, eventCount):
            return "reschedule reason=\(reason.rawValue) events=\(eventCount)"
        case let .notificationsRequested(requestCount):
            return "requests submitted=\(requestCount)"
        case let .notificationsScheduled(result):
            return "scheduled result=\(result)"
        case .notificationsCleared:
            return "cleared pending event notifications"
        case let .notificationSnoozed(minutes):
            return "snoozed minutes=\(minutes)"
        case let .alertShown(kind, eventRef):
            return "shown kind=\(kind.rawValue) event=\(eventRef)"
        case let .alertSkipped(kind, reason, eventRef):
            return "skipped kind=\(kind.rawValue) reason=\(reason.rawValue) event=\(eventRef)"
        case let .hotkeyRegistrationFailed(shortcut):
            return "registration failed shortcut=\(shortcut)"
        case let .contextFile(state, eventCount):
            return "file state=\(state.rawValue) events=\(eventCount)"
        case let .briefFinished(source, outcome):
            return "brief source=\(source) outcome=\(outcome)"
        case let .metricPayloadSaved(kind):
            return "payload saved kind=\(kind)"
        case let .diagnosticsExported(entryCount, payloadCount):
            return "exported entries=\(entryCount) payloads=\(payloadCount)"
        }
    }

    private static func code(_ errorCode: Int?) -> String {
        errorCode.map { " code=\($0)" } ?? ""
    }
}

/// A short, stable, non-reversible reference to a calendar event, so log lines
/// about the same event can be matched without naming it.
enum DiagnosticEventRef {
    static func make(identifier: String?) -> String {
        guard let identifier, !identifier.isEmpty else { return "none" }
        let digest = SHA256.hash(data: Data(identifier.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}

/// One line of the on-disk diagnostics journal.
struct DiagnosticEntry: Codable, Equatable {
    let date: Date
    let category: DiagnosticCategory
    let level: DiagnosticLevel
    let message: String
}

/// How long diagnostics stay on this Mac.
enum DiagnosticsRetention {
    /// Journal lines older than this are dropped.
    static let journalMaxAge: TimeInterval = 14 * 24 * 60 * 60
    /// The journal never keeps more lines than this.
    static let journalMaxEntries = 2_000
    /// MetricKit payloads older than this are deleted (PEEK-275).
    static let payloadMaxAge: TimeInterval = 30 * 24 * 60 * 60

    static func prune(_ entries: [DiagnosticEntry], now: Date) -> [DiagnosticEntry] {
        let recent = entries.filter { now.timeIntervalSince($0.date) <= journalMaxAge }
        return Array(recent.suffix(journalMaxEntries))
    }

    /// The payload files to delete, given each file's creation date.
    static func expiredPayloads(_ files: [(url: URL, created: Date)], now: Date) -> [URL] {
        files.filter { now.timeIntervalSince($0.created) > payloadMaxAge }.map(\.url)
    }
}

/// Keeps repeated log lines out of the journal: the status bar ticks every
/// few seconds, and the same decision about the same event would otherwise be
/// written on every tick.
struct DiagnosticThrottle {
    private var lastLogged: [String: Date] = [:]
    private let capacity: Int

    init(capacity: Int = 256) {
        self.capacity = capacity
    }

    mutating func shouldLog(key: String, minInterval: TimeInterval, now: Date) -> Bool {
        if let last = lastLogged[key], now.timeIntervalSince(last) < minInterval {
            return false
        }
        if lastLogged.count >= capacity {
            // Drop the oldest half; the keys are cheap to re-learn.
            let keep = lastLogged.sorted { $0.value > $1.value }.prefix(capacity / 2)
            lastLogged = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        lastLogged[key] = now
        return true
    }
}
