import Foundation

protocol EventCandidate {
    var candidateStartDate: Date? { get }
    var candidateEndDate: Date? { get }
    var isAllDay: Bool { get }
    var candidateTitle: String? { get }
    var candidateNotes: String? { get }
    var currentUserDeclined: Bool { get }
}

struct EventFilterSettings {
    let hideAllDayEvents: Bool
    let hideDeclinedEvents: Bool
    let keywords: [String]

    init(hideAllDayEvents: Bool, hideDeclinedEvents: Bool, filterKeywords: String) {
        self.hideAllDayEvents = hideAllDayEvents
        self.hideDeclinedEvents = hideDeclinedEvents
        self.keywords = EventFilterSettings.parseKeywords(filterKeywords)
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
            nextEvent: nextEvent?.event
        )
    }
}
