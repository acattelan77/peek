import Foundation

protocol EventCandidate {
    var candidateStartDate: Date? { get }
    var candidateEndDate: Date? { get }
    var isAllDay: Bool { get }
    var candidateTitle: String? { get }
    var candidateNotes: String? { get }
    var currentUserDeclined: Bool { get }
    /// Series and occurrence identity for per-event mute and hide (PEEK-273).
    var candidateIdentity: EventIdentity? { get }
}

extension EventCandidate {
    var candidateIdentity: EventIdentity? { nil }
}

struct EventFilterSettings {
    let hideAllDayEvents: Bool
    let hideDeclinedEvents: Bool
    let keywords: [String]
    /// Per-event choices: hidden events are left out (PEEK-273).
    let overrides: EventOverrides

    init(
        hideAllDayEvents: Bool,
        hideDeclinedEvents: Bool,
        filterKeywords: String,
        overrides: EventOverrides = .none
    ) {
        self.hideAllDayEvents = hideAllDayEvents
        self.hideDeclinedEvents = hideDeclinedEvents
        self.keywords = EventFilterSettings.parseKeywords(filterKeywords)
        self.overrides = overrides
    }

    static func parseKeywords(_ filterKeywords: String) -> [String] {
        let rawKeywords = filterKeywords.lowercased().split(separator: ",")
        return rawKeywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct EventSelectionResult<T> {
    let upcomingEvents: [T]
    let limitedEvents: [T]
    let nextEvent: T?
    /// Every visible event that has not ended, including ones already running.
    var activeEvents: [T] = []
}

struct EventPipeline {
    private struct Envelope<T> {
        let event: T
        let startDate: Date
        let endDate: Date
    }

    static func filterAndSelect<T: EventCandidate>(
        events: [T],
        now: Date,
        settings: EventFilterSettings,
        maxEvents: Int,
        lateGraceMinutes: Int
    ) -> EventSelectionResult<T> {
        let filtered: [Envelope<T>] = events.compactMap { event in
            guard let startDate = event.candidateStartDate, let endDate = event.candidateEndDate else {
                return nil
            }

            if settings.hideAllDayEvents && event.isAllDay {
                return nil
            }

            if settings.hideDeclinedEvents && event.currentUserDeclined {
                return nil
            }

            if settings.overrides.isHidden(event.candidateIdentity) {
                return nil
            }

            if !settings.keywords.isEmpty {
                let titleLower = (event.candidateTitle ?? "").lowercased()
                let notesLower = (event.candidateNotes ?? "").lowercased()
                for keyword in settings.keywords {
                    if titleLower.contains(keyword) || notesLower.contains(keyword) {
                        return nil
                    }
                }
            }

            guard endDate > now else {
                return nil
            }

            return Envelope(event: event, startDate: startDate, endDate: endDate)
        }.sorted { $0.startDate < $1.startDate }

        let lateGraceInterval = TimeInterval(lateGraceMinutes * 60)
        let ongoing = filtered.filter { $0.startDate <= now && $0.endDate > now }
        let lateEvent = ongoing
            .sorted { $0.startDate > $1.startDate }
            .first { now.timeIntervalSince($0.startDate) <= lateGraceInterval }
        let nextEvent = lateEvent ?? filtered.first { $0.startDate > now }
        let relevantEvents: [Envelope<T>]
        if let nextEvent,
           let nextIndex = filtered.firstIndex(where: { $0.startDate == nextEvent.startDate }) {
            relevantEvents = Array(filtered[nextIndex...])
        } else {
            relevantEvents = []
        }
        let limitedEvents = maxEvents > 0 ? Array(relevantEvents.prefix(maxEvents)) : []

        return EventSelectionResult(
            upcomingEvents: relevantEvents.map { $0.event },
            limitedEvents: limitedEvents.map { $0.event },
            nextEvent: nextEvent?.event,
            activeEvents: filtered.map { $0.event }
        )
    }

    /// Applies the user's visibility filters (all-day, declined, keywords) without
    /// any time window, sorted by start. Used for a chosen day in the month view.
    static func visibleEvents<T: EventCandidate>(_ events: [T], settings: EventFilterSettings) -> [T] {
        events.filter { event in
            guard event.candidateStartDate != nil, event.candidateEndDate != nil else { return false }
            if settings.hideAllDayEvents && event.isAllDay { return false }
            if settings.hideDeclinedEvents && event.currentUserDeclined { return false }
            if settings.overrides.isHidden(event.candidateIdentity) { return false }
            if !settings.keywords.isEmpty {
                let titleLower = (event.candidateTitle ?? "").lowercased()
                let notesLower = (event.candidateNotes ?? "").lowercased()
                if settings.keywords.contains(where: { titleLower.contains($0) || notesLower.contains($0) }) {
                    return false
                }
            }
            return true
        }
        .sorted { ($0.candidateStartDate ?? .distantPast) < ($1.candidateStartDate ?? .distantPast) }
    }
}
