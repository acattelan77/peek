import EventKit
import Foundation

struct CalendarExportPayload: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: String
    let timeZone: String
    let window: Window
    let events: [Event]

    struct Window: Codable, Equatable {
        let from: String
        let toExclusive: String
    }

    struct Event: Codable, Equatable {
        let id: String
        let title: String
        let startAt: String
        let endAt: String
        let allDay: Bool
        let calendar: CalendarInfo
        let location: String?
        let organizer: Organizer
        let attendees: [Attendee]
        let notes: String?
        let links: [Link]
        let currentUserResponse: Response
    }

    struct CalendarInfo: Codable, Equatable {
        let id: String
        let title: String
    }

    struct Organizer: Codable, Equatable {
        let name: String?
    }

    struct Attendee: Codable, Equatable {
        let name: String
        let response: Response
        let isOrganizer: Bool
    }

    struct Link: Codable, Equatable {
        let kind: LinkKind
        let url: String
    }

    enum LinkKind: String, Codable, Equatable {
        case join
        case document
        case other
    }

    enum Response: String, Codable, Equatable {
        case accepted
        case declined
        case tentative
        case pending
        case unknown
    }

    static func make(
        generatedAt: Date,
        timeZone: TimeZone,
        window: CalendarExportWindow,
        events: [EKEvent]
    ) -> CalendarExportPayload {
        let formatter = CalendarExportDateFormatter(timeZone: timeZone)
        let exportedEvents = events.map { CalendarExportEventMapper.make($0, formatter: formatter) }
            .sorted(by: CalendarExportEventMapper.stableOrder)
        return CalendarExportPayload(
            schemaVersion: 1,
            generatedAt: formatter.string(from: generatedAt),
            timeZone: timeZone.identifier,
            window: Window(
                from: formatter.string(from: window.from),
                toExclusive: formatter.string(from: window.toExclusive)
            ),
            events: exportedEvents
        )
    }

    func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

struct CalendarExportDateFormatter {
    private let formatter: DateFormatter

    init(timeZone: TimeZone) {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
    }

    func string(from date: Date) -> String {
        let value = formatter.string(from: date)
        return value.hasSuffix("Z") ? String(value.dropLast()) + "+00:00" : value
    }
}

enum CalendarExportEventMapper {
    private static let urlPattern = "https?://[^\\s<>()\\[\\]{}\\\"']+"

    static func make(_ event: EKEvent, formatter: CalendarExportDateFormatter) -> CalendarExportPayload.Event {
        let detail = EventDetailBuilder.make(from: event)
        let organizerURL = event.organizer?.url
        let attendees = (event.attendees ?? []).map { attendee in
            makeAttendee(
                name: attendee.name,
                participantURL: attendee.url,
                status: attendee.participantStatus,
                isOrganizer: organizerURL != nil && attendee.url == organizerURL
            )
        }
        let currentUserResponse = currentUserResponse(
            status: (event.attendees ?? []).first(where: { $0.isCurrentUser })?.participantStatus
        )
        let calendar = event.calendar
        return CalendarExportPayload.Event(
            id: stableIdentifier(for: event),
            title: normalized(event.title) ?? "",
            startAt: formatter.string(from: event.startDate),
            endAt: formatter.string(from: event.endDate),
            allDay: event.isAllDay,
            calendar: .init(
                id: calendar?.calendarIdentifier ?? "",
                title: normalized(calendar?.title) ?? ""
            ),
            location: normalized(event.location),
            organizer: .init(name: normalized(event.organizer?.name)),
            attendees: attendees,
            notes: truncatedNotes(detail.notes),
            links: links(notes: event.notes, location: event.location, eventURL: event.url),
            currentUserResponse: currentUserResponse
        )
    }

    static func stableOrder(_ lhs: CalendarExportPayload.Event, _ rhs: CalendarExportPayload.Event) -> Bool {
        if lhs.startAt != rhs.startAt { return lhs.startAt < rhs.startAt }
        if lhs.endAt != rhs.endAt { return lhs.endAt < rhs.endAt }
        if lhs.title != rhs.title { return lhs.title < rhs.title }
        return lhs.id < rhs.id
    }

    static func response(from status: EKParticipantStatus) -> CalendarExportPayload.Response {
        switch EventDetailBuilder.response(from: status) {
        case .accepted: return .accepted
        case .declined: return .declined
        case .tentative: return .tentative
        case .pending: return .pending
        case .unknown: return .unknown
        }
    }

    static func makeAttendee(
        name: String?,
        participantURL: URL?,
        status: EKParticipantStatus,
        isOrganizer: Bool
    ) -> CalendarExportPayload.Attendee {
        CalendarExportPayload.Attendee(
            name: EventDetailBuilder.attendeeDisplayName(name: name, participantURL: participantURL),
            response: response(from: status),
            isOrganizer: isOrganizer
        )
    }

    static func currentUserResponse(status: EKParticipantStatus?) -> CalendarExportPayload.Response {
        status.map(response(from:)) ?? .unknown
    }

    static func truncatedNotes(_ notes: String?) -> String? {
        guard let cleaned = EventDetailBuilder.cleanedNotes(notes) else { return nil }
        return String(cleaned.prefix(500))
    }

    /// URLs are scanned in notes, then location, then `event.url`. The first
    /// occurrence wins after normalization. Trusted HTTPS meeting URLs are
    /// `join`; non-meeting URLs from notes or `event.url` are `document`, and
    /// location URLs are `other` because they usually describe a place or route.
    static func links(notes: String?, location: String?, eventURL: URL?) -> [CalendarExportPayload.Link] {
        var links: [CalendarExportPayload.Link] = []
        var seen = Set<String>()
        appendURLs(from: notes, fallbackKind: .document, to: &links, seen: &seen)
        appendURLs(from: location, fallbackKind: .other, to: &links, seen: &seen)
        if let eventURL {
            append(url: eventURL, fallbackKind: .document, to: &links, seen: &seen)
        }
        return links
    }

    private static func appendURLs(
        from text: String?,
        fallbackKind: CalendarExportPayload.LinkKind,
        to links: inout [CalendarExportPayload.Link],
        seen: inout Set<String>
    ) {
        guard let text,
              let regex = try? NSRegularExpression(pattern: urlPattern) else { return }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let matchRange = Range(match.range, in: text) else { continue }
            let value = String(text[matchRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)]}>'\\\""))
            guard let url = URL(string: value) else { continue }
            append(url: url, fallbackKind: fallbackKind, to: &links, seen: &seen)
        }
    }

    private static func append(
        url: URL,
        fallbackKind: CalendarExportPayload.LinkKind,
        to links: inout [CalendarExportPayload.Link],
        seen: inout Set<String>
    ) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        let value = url.absoluteString
        guard seen.insert(value).inserted else { return }
        links.append(.init(kind: MeetingURLDetector.isURLSafe(url) ? .join : fallbackKind, url: value))
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private static func stableIdentifier(for event: EKEvent) -> String {
        if let eventIdentifier = event.eventIdentifier, !eventIdentifier.isEmpty {
            return eventIdentifier
        }
        let calendarIdentifier = event.calendar?.calendarIdentifier ?? "unknown-calendar"
        return "\(calendarIdentifier):\(event.calendarItemIdentifier):\(event.startDate.timeIntervalSince1970)"
    }
}
