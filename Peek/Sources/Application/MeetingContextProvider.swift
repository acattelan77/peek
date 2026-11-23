import Foundation
import EventKit

/// Builds the meeting context for an event from EventKit attendees, the
/// user's Contacts (when enabled and granted) and the context folder file.
/// The rules live in `MeetingContextBuilder`; this is the EventKit shim.
enum MeetingContextProvider {
    static let useContactsKey = "meetingContextUsesContacts"

    static func usesContacts(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: useContactsKey)
    }

    static func context(
        for event: EKEvent,
        defaults: UserDefaults = .standard,
        contacts: SystemContactsDirectory = .shared,
        folder: ContextFolderStore = .shared
    ) -> MeetingContext {
        let lookup: ContactLookup? = usesContacts(defaults) ? contacts : nil
        let external = folder.entry(
            forEventID: CalendarExportEventMapper.stableIdentifier(for: event),
            start: event.startDate
        )
        return MeetingContextBuilder.make(
            attendees: attendeeInputs(for: event),
            notes: event.notes,
            contacts: lookup,
            external: external
        )
    }

    static func attendeeInputs(for event: EKEvent) -> [AttendeeInput] {
        let organizerURL = event.organizer?.url
        return (event.attendees ?? []).map { participant in
            AttendeeInput(
                name: participant.name,
                email: email(from: participant.url),
                isOrganizer: organizerURL != nil && participant.url == organizerURL,
                isCurrentUser: participant.isCurrentUser,
                isPerson: participant.participantType == .person || participant.participantType == .unknown,
                response: EventDetailBuilder.response(from: participant.participantStatus)
            )
        }
    }

    private static func email(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "mailto" else { return nil }
        let value = String(url.absoluteString.dropFirst("mailto:".count))
        return value.removingPercentEncoding ?? value
    }
}
