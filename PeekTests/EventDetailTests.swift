import XCTest
import EventKit
@testable import Peek

final class EventDetailTests: XCTestCase {
    // MARK: Notes

    func testCleanedNotesTrimsWhitespace() {
        XCTAssertEqual(EventDetailBuilder.cleanedNotes("  Bring snacks.\n\n"), "Bring snacks.")
    }

    func testCleanedNotesTreatsWhitespaceOnlyAsAbsent() {
        XCTAssertNil(EventDetailBuilder.cleanedNotes("   \n\t "))
        XCTAssertNil(EventDetailBuilder.cleanedNotes(nil))
    }

    // MARK: Attendee display names

    func testAttendeeDisplayNamePrefersName() {
        let url = URL(string: "mailto:ada@example.com")
        XCTAssertEqual(
            EventDetailBuilder.attendeeDisplayName(name: "Ada Lovelace", participantURL: url),
            "Ada Lovelace"
        )
    }

    func testAttendeeDisplayNameFallsBackToMailtoEmail() {
        let url = URL(string: "mailto:ada@example.com")
        XCTAssertEqual(
            EventDetailBuilder.attendeeDisplayName(name: nil, participantURL: url),
            "ada@example.com"
        )
        XCTAssertEqual(
            EventDetailBuilder.attendeeDisplayName(name: "  ", participantURL: url),
            "ada@example.com"
        )
    }

    func testAttendeeDisplayNameFallsBackToNonMailtoURL() {
        let url = URL(string: "https://directory.example.com/people/ada")
        XCTAssertEqual(
            EventDetailBuilder.attendeeDisplayName(name: nil, participantURL: url),
            "https://directory.example.com/people/ada"
        )
    }

    func testAttendeeDisplayNameFallsBackToPlaceholder() {
        XCTAssertEqual(
            EventDetailBuilder.attendeeDisplayName(name: nil, participantURL: nil),
            NSLocalizedString("Unknown attendee", comment: "")
        )
    }

    // MARK: Response mapping

    func testResponseMapping() {
        XCTAssertEqual(EventDetailBuilder.response(from: .accepted), .accepted)
        XCTAssertEqual(EventDetailBuilder.response(from: .declined), .declined)
        XCTAssertEqual(EventDetailBuilder.response(from: .tentative), .tentative)
        XCTAssertEqual(EventDetailBuilder.response(from: .pending), .pending)
        XCTAssertEqual(EventDetailBuilder.response(from: .delegated), .pending)
        XCTAssertEqual(EventDetailBuilder.response(from: .unknown), .unknown)
        XCTAssertEqual(EventDetailBuilder.response(from: .completed), .unknown)
    }

    // MARK: EventDetail aggregation

    func testIsEmptyOnlyWhenNothingToShow() {
        let empty = EventDetail(notes: nil, attendees: [], meetingProvider: nil, meetingURL: nil)
        XCTAssertTrue(empty.isEmpty)

        let withNotes = EventDetail(notes: "Hi", attendees: [], meetingProvider: nil, meetingURL: nil)
        XCTAssertFalse(withNotes.isEmpty)

        let withMeeting = EventDetail(
            notes: nil, attendees: [],
            meetingProvider: "Zoom", meetingURL: URL(string: "https://zoom.us/j/123")
        )
        XCTAssertFalse(withMeeting.isEmpty)
    }

    func testVisibleAttendeesAreCappedWithOverflowCount() {
        let attendees = (0..<7).map {
            EventAttendee(displayName: "Person \($0)", response: .pending, isOrganizer: false)
        }
        let detail = EventDetail(notes: nil, attendees: attendees, meetingProvider: nil, meetingURL: nil)

        XCTAssertEqual(detail.visibleAttendees.count, EventDetail.maxVisibleAttendees)
        XCTAssertEqual(detail.hiddenAttendeeCount, 7 - EventDetail.maxVisibleAttendees)
    }

    func testNoOverflowWhenAttendeesFit() {
        let attendees = [
            EventAttendee(displayName: "Ada", response: .accepted, isOrganizer: true)
        ]
        let detail = EventDetail(notes: nil, attendees: attendees, meetingProvider: nil, meetingURL: nil)

        XCTAssertEqual(detail.visibleAttendees.count, 1)
        XCTAssertEqual(detail.hiddenAttendeeCount, 0)
    }

    // MARK: Meeting provider identity

    func testMeetingProviderLabels() {
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://acme.zoom.us/j/123")!), "Zoom")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://meet.google.com/abc-defg-hij")!), "Google Meet")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://teams.microsoft.com/l/meetup-join/x")!), "Teams")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://example.com")!), NSLocalizedString("Meeting", comment: ""))
    }
}
