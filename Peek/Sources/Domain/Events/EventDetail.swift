import Foundation
import EventKit

/// Response status of an event attendee, mapped from `EKParticipantStatus`.
enum AttendeeResponse: Equatable {
    case accepted
    case declined
    case tentative
    case pending
    case unknown
}

/// A display-ready attendee. `displayName` always has a value (name, then
/// email from the participant URL, then a localized fallback).
struct EventAttendee: Equatable {
    let displayName: String
    let response: AttendeeResponse
    let isOrganizer: Bool
}

/// Everything the expanded event row shows beyond the collapsed row. Built
/// from an `EKEvent` by `EventDetailBuilder`; kept as plain values so the
/// logic is testable without EventKit (attendees are read-only on `EKEvent`,
/// so fakes cannot populate them). Attachments are not included: macOS
/// EventKit does not expose `EKAttachment` (it is iOS-only).
struct EventDetail: Equatable {
    /// Maximum number of attendees rendered before a "+N more" summary.
    static let maxVisibleAttendees = 5

    let notes: String?
    let attendees: [EventAttendee]
    let meetingProvider: String?
    let meetingURL: URL?

    var isEmpty: Bool {
        notes == nil && attendees.isEmpty && meetingURL == nil
    }

    var visibleAttendees: [EventAttendee] {
        Array(attendees.prefix(Self.maxVisibleAttendees))
    }

    var hiddenAttendeeCount: Int {
        max(0, attendees.count - Self.maxVisibleAttendees)
    }
}

enum EventDetailBuilder {
    /// Thin mapping shim over EventKit; all decisions live in the pure
    /// helpers below.
    static func make(from event: EKEvent) -> EventDetail {
        let meetingURL = MeetingURLDetector.extract(from: event)
        return EventDetail(
            notes: cleanedNotes(event.notes),
            attendees: (event.attendees ?? []).map {
                EventAttendee(
                    displayName: attendeeDisplayName(name: $0.name, participantURL: $0.url),
                    response: response(from: $0.participantStatus),
                    isOrganizer: event.organizer != nil && $0.url == event.organizer?.url
                )
            },
            meetingProvider: meetingURL.map { MeetingProvider.label(for: $0) },
            meetingURL: meetingURL
        )
    }

    /// Whitespace-only notes are treated as absent.
    static func cleanedNotes(_ notes: String?) -> String? {
        guard let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// EventKit participants often lack a name; the participant URL is usually
    /// a `mailto:` carrying the email address.
    static func attendeeDisplayName(name: String?, participantURL: URL?) -> String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let url = participantURL {
            if url.scheme?.lowercased() == "mailto" {
                let email = String(url.absoluteString.dropFirst("mailto:".count))
                if !email.isEmpty { return email }
            } else if !url.absoluteString.isEmpty {
                return url.absoluteString
            }
        }
        return NSLocalizedString("Unknown attendee", comment: "Fallback for attendee without name or email")
    }

    static func response(from status: EKParticipantStatus) -> AttendeeResponse {
        switch status {
        case .accepted: return .accepted
        case .declined: return .declined
        case .tentative: return .tentative
        case .pending, .delegated: return .pending
        default: return .unknown
        }
    }
}
