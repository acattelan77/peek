import Foundation

/// The calendar identity of one event as Peek sees it (PEEK-273): the series
/// it belongs to and, for a recurring event, which occurrence it is.
struct EventIdentity: Equatable {
    /// `EKEvent.calendarItemIdentifier`: shared by every occurrence of a series.
    let seriesID: String
    /// The occurrence's original start (`EKEvent.occurrenceDate`), stable when
    /// one occurrence is moved.
    let occurrenceDate: Date
    let isRecurring: Bool
}

/// What the user chose for one event or series.
enum EventOverrideAction: String, Codable, CaseIterable {
    /// Stays visible; no notification, heads-up card or full-screen alert.
    case mute
    /// Gone from the popover and the menu bar.
    case hide
}

/// Whether a choice covers one occurrence or the whole series.
enum EventOverrideScope: String, Codable {
    /// A one-off event: matched by its identifier alone.
    case event
    /// One occurrence of a recurring event.
    case occurrence
    /// Every occurrence of a recurring event.
    case series
}

/// One per-event choice, persisted with a title snapshot so Preferences can
/// list it without reading the calendar.
struct EventOverride: Codable, Equatable, Identifiable {
    let action: EventOverrideAction
    let scope: EventOverrideScope
    let seriesID: String
    /// The event's or occurrence's original start, in whole seconds; matched
    /// only for `.occurrence`, shown in Preferences for both. Nil for `.series`.
    let occurrenceDate: Date?
    let title: String
    /// When the event (or occurrence) ends. Entries past it are pruned; series
    /// entries have none and stay until restored.
    let expiresAt: Date?

    var id: String { "\(action.rawValue)|\(EventOverrides.key(scope: scope, seriesID: seriesID, occurrenceDate: occurrenceDate))" }

    func matches(_ identity: EventIdentity) -> Bool {
        guard identity.seriesID == seriesID else { return false }
        switch scope {
        case .event, .series:
            return true
        case .occurrence:
            guard let occurrenceDate else { return false }
            return EventOverrides.wholeSeconds(occurrenceDate) == EventOverrides.wholeSeconds(identity.occurrenceDate)
        }
    }
}

/// The user's mute and hide choices (PEEK-273). Pure value type: the
/// application layer persists it and applies it to the event pipeline.
struct EventOverrides: Equatable {
    private(set) var entries: [EventOverride]

    static let none = EventOverrides(entries: [])

    init(entries: [EventOverride] = []) {
        self.entries = entries
    }

    var isEmpty: Bool { entries.isEmpty }

    /// Hide wins over mute: a hidden event never alerts either.
    func action(for identity: EventIdentity?) -> EventOverrideAction? {
        guard let identity else { return nil }
        let matching = entries.filter { $0.matches(identity) }
        if matching.contains(where: { $0.action == .hide }) { return .hide }
        if matching.contains(where: { $0.action == .mute }) { return .mute }
        return nil
    }

    func isHidden(_ identity: EventIdentity?) -> Bool { action(for: identity) == .hide }

    /// Muted or hidden: neither may notify or interrupt.
    func isSilenced(_ identity: EventIdentity?) -> Bool { action(for: identity) != nil }

    /// The scope a choice takes: a one-off event is always `.event`.
    static func scope(for identity: EventIdentity, wholeSeries: Bool) -> EventOverrideScope {
        guard identity.isRecurring else { return .event }
        return wholeSeries ? .series : .occurrence
    }

    /// Records `action` for the event, replacing any choice that covers the
    /// same event at the same scope.
    mutating func set(
        _ action: EventOverrideAction,
        for identity: EventIdentity,
        wholeSeries: Bool,
        title: String,
        endDate: Date
    ) {
        let scope = Self.scope(for: identity, wholeSeries: wholeSeries)
        let entry = EventOverride(
            action: action,
            scope: scope,
            seriesID: identity.seriesID,
            occurrenceDate: scope == .series ? nil : Self.normalized(identity.occurrenceDate),
            title: title,
            expiresAt: scope == .series ? nil : endDate
        )
        let key = Self.key(scope: entry.scope, seriesID: entry.seriesID, occurrenceDate: entry.occurrenceDate)
        entries.removeAll { Self.key(scope: $0.scope, seriesID: $0.seriesID, occurrenceDate: $0.occurrenceDate) == key }
        entries.append(entry)
    }

    /// Removes every choice that applies to the event: restoring it from the
    /// popover clears both its occurrence and its series entries.
    mutating func restore(_ identity: EventIdentity) {
        entries.removeAll { $0.matches(identity) }
    }

    mutating func remove(id: String) {
        entries.removeAll { $0.id == id }
    }

    /// Drops one-off and occurrence entries whose event has ended.
    mutating func prune(now: Date) {
        entries.removeAll { entry in
            guard let expiresAt = entry.expiresAt else { return false }
            return expiresAt <= now
        }
    }

    /// Entries for Preferences: series first, then by date.
    var sortedForDisplay: [EventOverride] {
        entries.sorted { lhs, rhs in
            let lhsDate = lhs.occurrenceDate ?? lhs.expiresAt ?? .distantPast
            let rhsDate = rhs.occurrenceDate ?? rhs.expiresAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: Persistence

    func encoded() -> Data? {
        try? JSONEncoder().encode(entries)
    }

    static func decoded(from data: Data?) -> EventOverrides {
        guard let data, let entries = try? JSONDecoder().decode([EventOverride].self, from: data) else {
            return .none
        }
        return EventOverrides(entries: entries)
    }

    // MARK: Keys

    static func key(scope: EventOverrideScope, seriesID: String, occurrenceDate: Date?) -> String {
        switch scope {
        case .event, .series:
            return "\(scope.rawValue)|\(seriesID)"
        case .occurrence:
            return "\(scope.rawValue)|\(seriesID)|\(occurrenceDate.map(wholeSeconds) ?? 0)"
        }
    }

    static func wholeSeconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded())
    }

    static func normalized(_ date: Date) -> Date {
        Date(timeIntervalSince1970: TimeInterval(wholeSeconds(date)))
    }
}
