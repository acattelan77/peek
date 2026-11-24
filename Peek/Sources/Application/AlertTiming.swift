import Foundation

// PEEK-271 and PEEK-272: the pure rules that keep alerts on time across sleep,
// time zone and clock changes, and within the system's pending-notification
// limit. Everything here takes `now` and a time zone explicitly so tests can
// drive it without the system clock.

/// When the start alert may still show after the start time (PEEK-271).
enum LateStartPolicy {
    /// After a wake or a launch, a meeting that started less than this long
    /// ago still gets its start alert, worded "started N min ago".
    static let window: TimeInterval = 300

    enum Timing: Equatable {
        case notYet
        /// The first minute after the start time.
        case startingNow
        /// Between one and five minutes after the start time.
        case startedMinutesAgo(Int)
        case tooLate
    }

    static func timing(secondsSinceStart seconds: TimeInterval) -> Timing {
        if seconds < 0 { return .notYet }
        if seconds < 60 { return .startingNow }
        if seconds <= window { return .startedMinutesAgo(max(1, Int(seconds / 60))) }
        return .tooLate
    }
}

/// A snoozed start alert keeps its due time on the wall clock, so a snooze
/// that runs out while the Mac sleeps fires at the wake (PEEK-271). A
/// monotonic `asyncAfter` deadline stops counting during sleep.
struct PendingSnooze: Equatable {
    let eventKey: String
    let presentation: StartAlertPresentation
    let dueAt: Date

    init(eventKey: String, presentation: StartAlertPresentation, snoozedAt: Date) {
        self.eventKey = eventKey
        self.presentation = presentation
        self.dueAt = snoozedAt.addingTimeInterval(StartAlertPolicy.snoozeDelay(for: presentation))
    }

    /// One second of tolerance: the wall-clock timer may fire a hair early.
    func isDue(now: Date) -> Bool {
        now >= dueAt.addingTimeInterval(-1)
    }
}

/// One occurrence that may get a lead-time notification.
struct NotificationPlanCandidate: Equatable {
    /// The EventKit identifier, shared by every occurrence of a recurring event.
    let eventID: String
    let startDate: Date
    /// A join link or attendees: the notification may be time-sensitive.
    let isMeeting: Bool
}

struct NotificationPlanEntry: Equatable {
    let identifier: String
    let eventID: String
    let startDate: Date
    let fireDate: Date
    let isTimeSensitive: Bool
}

enum NotificationPlanner {
    /// macOS keeps at most 64 pending requests per app and silently drops the rest.
    static let systemPendingLimit = 64
    /// Room left for snoozed notifications, which are added outside the plan.
    static let snoozeReserve = 4
    static var eventLimit: Int { systemPendingLimit - snoozeReserve }

    static let identifierPrefix = "event:"

    /// The nearest lead-time notifications, at most `limit`, ordered by fire
    /// date. Occurrences beyond the limit enter at a later reschedule.
    static func plan(
        _ candidates: [NotificationPlanCandidate],
        leadTime: TimeInterval,
        now: Date,
        limit: Int = eventLimit
    ) -> [NotificationPlanEntry] {
        var seen = Set<String>()
        let entries: [NotificationPlanEntry] = candidates.compactMap { candidate in
            guard candidate.startDate > now else { return nil }
            let fireDate = candidate.startDate.addingTimeInterval(-leadTime)
            guard fireDate > now else { return nil }
            let identifier = Self.identifier(eventID: candidate.eventID, startDate: candidate.startDate)
            guard seen.insert(identifier).inserted else { return nil }
            return NotificationPlanEntry(
                identifier: identifier,
                eventID: candidate.eventID,
                startDate: candidate.startDate,
                fireDate: fireDate,
                isTimeSensitive: candidate.isMeeting
            )
        }
        return Array(entries.sorted { $0.fireDate < $1.fireDate }.prefix(max(0, limit)))
    }

    /// One identifier per occurrence. Recurring events share an EventKit
    /// identifier, and a request with an existing identifier replaces it, so
    /// the start time is part of the identifier.
    static func identifier(eventID: String, startDate: Date) -> String {
        "\(identifierPrefix)\(eventID)@\(Int(startDate.timeIntervalSince1970))"
    }

    /// Trigger components pinned to one absolute instant: with the time zone
    /// inside the components, a later time zone change does not move the
    /// notification to the same wall-clock time somewhere else.
    static func triggerComponents(for fireDate: Date, timeZone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        components.calendar = calendar
        components.timeZone = timeZone
        return components
    }

    /// A delivered reminder is stale once its meeting started more than the
    /// late-start window ago: the start alert and the menu bar have taken over.
    static func isStale(eventStart: Date, now: Date) -> Bool {
        now.timeIntervalSince(eventStart) > LateStartPolicy.window
    }
}

/// The same meeting on two calendars (a shared invite, a subscribed copy)
/// shows, notifies and alerts once (PEEK-272).
enum EventDeduplicator {
    struct Key: Hashable {
        let title: String
        let start: Date
        let end: Date
        let link: String?
    }

    static func key(title: String?, start: Date?, end: Date?, link: String?) -> Key? {
        guard let start, let end else { return nil }
        return Key(title: normalizedTitle(title), start: start, end: end, link: link)
    }

    static func normalizedTitle(_ title: String?) -> String {
        (title ?? "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Keeps one event per key: the one on a calendar that alerts, otherwise
    /// the one on the calendar listed first. Order is otherwise unchanged.
    static func deduplicate<T>(
        _ events: [T],
        key: (T) -> Key?,
        alerts: (T) -> Bool,
        calendarRank: (T) -> Int
    ) -> [T] {
        var chosen: [Key: (index: Int, alerts: Bool, rank: Int)] = [:]
        let keys = events.map(key)
        for (index, event) in events.enumerated() {
            guard let eventKey = keys[index] else { continue }
            let candidate = (index: index, alerts: alerts(event), rank: calendarRank(event))
            guard let current = chosen[eventKey] else {
                chosen[eventKey] = candidate
                continue
            }
            if isPreferred(candidate, over: current) {
                chosen[eventKey] = candidate
            }
        }
        return events.enumerated().compactMap { index, event in
            guard let eventKey = keys[index] else { return event }
            return chosen[eventKey]?.index == index ? event : nil
        }
    }

    private static func isPreferred(
        _ candidate: (index: Int, alerts: Bool, rank: Int),
        over current: (index: Int, alerts: Bool, rank: Int)
    ) -> Bool {
        if candidate.alerts != current.alerts { return candidate.alerts }
        if candidate.rank != current.rank { return candidate.rank < current.rank }
        return candidate.index < current.index
    }
}
