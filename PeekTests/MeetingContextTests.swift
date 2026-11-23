import XCTest
@testable import Peek

final class InvitationTextCleanerTests: XCTestCase {
    func testZoomInvitationKeepsOnlyTheAgenda() {
        let notes = """
        Agenda: review Q4 numbers
        Bring the hiring plan.

        Jane Doe is inviting you to a scheduled Zoom meeting.

        Join Zoom Meeting
        https://acme.zoom.us/j/123456789?pwd=abc

        Meeting ID: 123 4567 8901
        Passcode: 123456

        ---

        One tap mobile
        +16465588656,,123456789#,,,,*123456# US (New York)
        +13017158592,,123456789#,,,,*123456# US (Washington DC)

        ---

        Dial by your location
        • +1 646 558 8656 US (New York)
        • +39 069 480 6488 Italy

        Meeting ID: 123 4567 8901
        Passcode: 123456
        Find your local number: https://acme.zoom.us/u/abc

        Join by SIP
        • 123456789@zoomcrc.com

        Join by H.323
        • 162.255.37.11 (US West)
        """

        XCTAssertEqual(InvitationTextCleaner.clean(notes), "Agenda: review Q4 numbers\nBring the hiring plan.")
    }

    func testGoogleMeetBlockIsRemoved() {
        let notes = """
        Weekly sync on the launch.
        -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-
        Join with Google Meet: https://meet.google.com/abc-defg-hij
        Or dial: (US) +1 234-567-8900 PIN: 123456789#
        More phone numbers: https://tel.meet/abc-defg-hij?pin=123
        Learn more about Meet at: https://support.google.com/a/users/answer/9282720
        Please do not edit this section.
        -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-
        """

        XCTAssertEqual(InvitationTextCleaner.clean(notes), "Weekly sync on the launch.")
    }

    func testTeamsBlockIsRemovedButOtherRulesStay() {
        let notes = """
        Topics
        __________________
        1. Budget
        __________________
        ________________________________________________________________________________
        Microsoft Teams meeting
        Join on your computer, mobile app or room device
        Click here to join the meeting<https://teams.microsoft.com/l/meetup-join/abc>
        Meeting ID: 123 456 789 012
        Passcode: abc123
        Download Teams<https://www.microsoft.com/microsoft-teams/download-app> | Join on the web<https://www.microsoft.com/microsoft-teams/join-a-meeting>
        Learn More<https://aka.ms/JoinTeamsMeeting> | Meeting options<https://teams.microsoft.com/meetingOptions/>
        ________________________________________________________________________________
        """

        XCTAssertEqual(InvitationTextCleaner.clean(notes), "Topics\n__________________\n1. Budget\n__________________")
    }

    func testOnlyBoilerplateBecomesNil() {
        XCTAssertNil(InvitationTextCleaner.clean("Join Zoom Meeting\nhttps://zoom.us/j/123\nMeeting ID: 123 456 7890"))
        XCTAssertNil(InvitationTextCleaner.clean("   \n\n "))
        XCTAssertNil(InvitationTextCleaner.clean(nil))
    }

    func testDatesAndFiguresInTheAgendaAreKept() {
        let notes = "Deadline 2026-11-23\nBudget 1.250.000\nCall +39 06 1234 5678 if late"
        XCTAssertEqual(InvitationTextCleaner.clean(notes), notes)
    }

    func testHTMLNotesBecomeText() {
        let notes = "<p>Agenda:</p><ul><li>Pricing</li><li>Hiring &amp; budget</li></ul><br>Join: <a href=\"https://meet.google.com/abc-defg-hij\">https://meet.google.com/abc-defg-hij</a>"
        let cleaned = InvitationTextCleaner.clean(notes)

        XCTAssertEqual(cleaned?.components(separatedBy: "\n").prefix(3).map { $0 }, ["Agenda:", "• Pricing", "• Hiring & budget"])
        XCTAssertFalse(cleaned?.contains("<") ?? true)
    }
}

final class MeetingContextBuilderTests: XCTestCase {
    private struct FakeContacts: ContactLookup {
        let cards: [String: ContactCard]
        func card(forEmail email: String) -> ContactCard? { cards[email] }
    }

    private let marco = ContactCard(givenName: "Marco", fullName: "Ada Lovelace", jobTitle: "CEO", organization: "Northwind")

    func testHeadlineForOnePersonFromContacts() {
        let attendees = [
            AttendeeInput(name: "Me", email: "me@example.org", isCurrentUser: true),
            AttendeeInput(name: nil, email: "MARCO@northwind.example", isOrganizer: true)
        ]
        let context = MeetingContextBuilder.make(
            attendees: attendees,
            notes: nil,
            contacts: FakeContacts(cards: ["marco@northwind.example": marco]),
            external: nil
        )

        XCTAssertEqual(context.people.count, 1)
        XCTAssertEqual(context.people.first?.name, "Ada Lovelace")
        XCTAssertEqual(context.people.first?.descriptor, "CEO at Northwind")
        XCTAssertEqual(context.headline, "You're about to meet Marco, CEO at Northwind")
    }

    func testWithoutContactsTheEmailDomainIsUsed() {
        let attendees = [AttendeeInput(name: "Anna Rossi", email: "anna@northwind.example")]
        let context = MeetingContextBuilder.make(attendees: attendees, notes: nil, contacts: nil, external: nil)

        XCTAssertEqual(context.people.first?.descriptor, "from northwind.example")
        XCTAssertEqual(context.headline, "You're about to meet Anna, from northwind.example")
    }

    func testPersonalMailDomainsAndRoomsAreNotShown() {
        let attendees = [
            AttendeeInput(name: "Luca", email: "luca@gmail.com"),
            AttendeeInput(name: "Room 4", email: "room4@resource.calendar.google.com", isPerson: false)
        ]
        let context = MeetingContextBuilder.make(attendees: attendees, notes: nil, contacts: nil, external: nil)

        XCTAssertEqual(context.people.map(\.name), ["Luca"])
        XCTAssertNil(context.people.first?.descriptor)
        XCTAssertEqual(context.headline, "You're about to meet Luca")
    }

    func testSeveralPeopleKnownFirstAndDeduplicated() {
        let attendees = [
            AttendeeInput(name: "Anna Rossi", email: "anna@example.org"),
            AttendeeInput(name: "Marco", email: "marco@northwind.example"),
            AttendeeInput(name: "Marco", email: "mailto:marco@northwind.example"),
            AttendeeInput(name: "Paolo Bianchi", email: "paolo@example.org")
        ]
        let context = MeetingContextBuilder.make(
            attendees: attendees,
            notes: nil,
            contacts: FakeContacts(cards: ["marco@northwind.example": marco]),
            external: nil
        )

        XCTAssertEqual(context.people.map(\.shortName), ["Marco", "Anna", "Paolo"])
        XCTAssertEqual(context.headline, "You're about to meet Marco and 2 others")
    }

    func testTwoPeopleHeadline() {
        let people = [
            AttendeeInput(name: "Anna Rossi", email: "anna@example.org"),
            AttendeeInput(name: "Paolo Bianchi", email: "paolo@example.org")
        ]
        let context = MeetingContextBuilder.make(attendees: people, notes: nil, contacts: nil, external: nil)
        XCTAssertEqual(context.headline, "You're about to meet Anna and Paolo")
    }

    func testNobodyToMeetHasNoHeadline() {
        let context = MeetingContextBuilder.make(
            attendees: [AttendeeInput(name: "Me", email: "me@example.org", isCurrentUser: true)],
            notes: "Focus time",
            contacts: nil,
            external: nil
        )
        XCTAssertNil(context.headline)
        XCTAssertTrue(context.people.isEmpty)
        XCTAssertEqual(context.agenda, "Focus time")
        XCTAssertFalse(context.isEmpty)
    }

    func testContextFolderWinsOverContacts() throws {
        let entry = MeetingContextFile.Entry(
            id: "evt-1",
            startAt: nil,
            headline: "Renewal call with Northwind",
            summary: "They want a two-year deal.",
            bullets: ["Bring the usage report"],
            people: [MeetingContextFile.Person(email: "marco@northwind.example", name: nil, role: "Founder", company: nil, note: "Prefers short calls")],
            links: []
        )
        let context = MeetingContextBuilder.make(
            attendees: [AttendeeInput(name: "Marco", email: "marco@northwind.example")],
            notes: nil,
            contacts: FakeContacts(cards: ["marco@northwind.example": marco]),
            external: entry
        )

        let person = try XCTUnwrap(context.people.first)
        XCTAssertEqual(person.role, "Founder")
        XCTAssertEqual(person.company, "Northwind")
        XCTAssertEqual(person.note, "Prefers short calls")
        XCTAssertEqual(context.headline, "Renewal call with Northwind")
        XCTAssertTrue(context.hasExternalContext)
    }

    func testCompanyDomain() {
        XCTAssertEqual(MeetingContextBuilder.companyDomain(fromEmail: "a@northwind.example"), "northwind.example")
        XCTAssertNil(MeetingContextBuilder.companyDomain(fromEmail: "a@icloud.com"))
        XCTAssertNil(MeetingContextBuilder.companyDomain(fromEmail: "a@localhost"))
    }
}

final class MeetingContextFileTests: XCTestCase {
    private func decode(_ json: String) throws -> MeetingContextFile {
        try MeetingContextFile.decode(Data(json.utf8))
    }

    func testDecodesVersionOneAndIgnoresUnknownFields() throws {
        let file = try decode("""
        {"schemaVersion": 1, "generatedAt": "2026-11-23T08:00:00+01:00", "writer": "system-42",
         "events": [{"id": "ABC:123", "headline": " Meet Marco ", "summary": "Renewal",
                     "bullets": ["One", "", "Two"],
                     "people": [{"email": "marco@northwind.example", "role": "CEO", "extra": true}],
                     "links": [{"title": "Deck", "url": "https://example.com/deck"},
                               {"title": "Local", "url": "file:///etc/passwd"},
                               {"url": "zoommtg://zoom.us/join"}],
                     "futureField": {"nested": 1}}]}
        """)

        XCTAssertNotNil(file.generatedAt)
        let entry = try XCTUnwrap(file.entry(forEventID: "ABC:123", start: nil))
        XCTAssertEqual(entry.headline, "Meet Marco")
        XCTAssertEqual(entry.bullets, ["One", "Two"])
        XCTAssertEqual(entry.people.first?.role, "CEO")
        XCTAssertEqual(entry.links.map(\.url.absoluteString), ["https://example.com/deck"])
    }

    func testRejectsOtherVersionsAndMalformedFiles() {
        XCTAssertThrowsError(try decode("{\"schemaVersion\": 2, \"events\": []}")) { error in
            XCTAssertEqual(error as? MeetingContextFile.DecodeError, .unsupportedVersion(2))
        }
        XCTAssertThrowsError(try decode("not json")) { error in
            XCTAssertEqual(error as? MeetingContextFile.DecodeError, .malformed)
        }
        XCTAssertThrowsError(try decode("{\"events\": []}")) { error in
            XCTAssertEqual(error as? MeetingContextFile.DecodeError, .malformed)
        }
    }

    func testRejectsOversizedFiles() {
        let data = Data(repeating: 0x20, count: MeetingContextFile.Limits.maxFileBytes + 1)
        XCTAssertThrowsError(try MeetingContextFile.decode(data)) { error in
            XCTAssertEqual(error as? MeetingContextFile.DecodeError, .tooLarge)
        }
    }

    func testOccurrenceMatchWinsOverSeriesEntry() throws {
        let file = try decode("""
        {"schemaVersion": 1, "events": [
          {"id": "series", "headline": "Any week"},
          {"id": "series", "startAt": "2026-11-24T10:00:00+01:00", "headline": "This week"}
        ]}
        """)
        let thisWeek = try XCTUnwrap(MeetingContextFile.parseDate("2026-11-24T09:00:30Z"))
        let nextWeek = try XCTUnwrap(MeetingContextFile.parseDate("2026-12-01T09:00:00Z"))

        XCTAssertEqual(file.entry(forEventID: "series", start: thisWeek)?.headline, "This week")
        XCTAssertEqual(file.entry(forEventID: "series", start: nextWeek)?.headline, "Any week")
        XCTAssertNil(file.entry(forEventID: "other", start: thisWeek))
    }

    func testLongFieldsAreClipped() throws {
        let long = String(repeating: "a", count: 500)
        let file = try decode("{\"schemaVersion\": 1, \"events\": [{\"id\": \"x\", \"headline\": \"\(long)\"}]}")
        let headline = try XCTUnwrap(file.entries.first?.headline)
        XCTAssertEqual(headline.count, MeetingContextFile.Limits.maxHeadline)
        XCTAssertTrue(headline.hasSuffix("…"))
    }
}
