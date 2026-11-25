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

    private let ada = ContactCard(givenName: "Ada", fullName: "Ada Lovelace", jobTitle: "CEO", organization: "Northwind")

    func testHeadlineForOnePersonFromContacts() {
        let attendees = [
            AttendeeInput(name: "Me", email: "me@example.org", isCurrentUser: true),
            AttendeeInput(name: nil, email: "ADA@northwind.example", isOrganizer: true)
        ]
        let context = MeetingContextBuilder.make(
            attendees: attendees,
            notes: nil,
            contacts: FakeContacts(cards: ["ada@northwind.example": ada]),
            external: nil
        )

        XCTAssertEqual(context.people.count, 1)
        XCTAssertEqual(context.people.first?.name, "Ada Lovelace")
        XCTAssertEqual(context.people.first?.descriptor, "CEO at Northwind")
        XCTAssertEqual(context.headline, "You're about to meet Ada, CEO at Northwind")
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
            AttendeeInput(name: "Ada", email: "ada@northwind.example"),
            AttendeeInput(name: "Ada", email: "mailto:ada@northwind.example"),
            AttendeeInput(name: "Paolo Bianchi", email: "paolo@example.org")
        ]
        let context = MeetingContextBuilder.make(
            attendees: attendees,
            notes: nil,
            contacts: FakeContacts(cards: ["ada@northwind.example": ada]),
            external: nil
        )

        XCTAssertEqual(context.people.map(\.shortName), ["Ada", "Anna", "Paolo"])
        XCTAssertEqual(context.headline, "You're about to meet Ada, CEO at Northwind, and 2 others")
    }

    func testSeveralPeopleWithoutRoleUseTheShortForm() {
        let attendees = [
            AttendeeInput(name: "Anna Rossi", email: "anna@northwind.example"),
            AttendeeInput(name: "Paolo Bianchi", email: "paolo@northwind.example"),
            AttendeeInput(name: "Luca Verdi", email: "luca@northwind.example")
        ]
        let context = MeetingContextBuilder.make(attendees: attendees, notes: nil, contacts: nil, external: nil)
        XCTAssertEqual(context.headline, "You're about to meet Anna and 2 others")
    }

    func testAnEmailInTheNameFieldBecomesAName() {
        let attendees = [
            AttendeeInput(name: "grace.hopper@northwind.example", email: "grace.hopper@northwind.example"),
            AttendeeInput(name: nil, email: "info@example.org"),
            AttendeeInput(name: nil, email: "j2@example.org")
        ]
        let context = MeetingContextBuilder.make(attendees: attendees, notes: nil, contacts: nil, external: nil)
        XCTAssertEqual(context.people.map(\.name), ["Grace Hopper", "info@example.org", "j2@example.org"])
        XCTAssertEqual(context.people.first?.shortName, "Grace")
        XCTAssertEqual(context.headline, "You're about to meet Grace and 2 others")
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
            people: [MeetingContextFile.Person(email: "ada@northwind.example", name: nil, role: "Founder", company: nil, note: "Prefers short calls")],
            links: []
        )
        let context = MeetingContextBuilder.make(
            attendees: [AttendeeInput(name: "Ada", email: "ada@northwind.example")],
            notes: nil,
            contacts: FakeContacts(cards: ["ada@northwind.example": ada]),
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
         "events": [{"id": "ABC:123", "headline": " Meet Ada ", "summary": "Renewal",
                     "bullets": ["One", "", "Two"],
                     "people": [{"email": "ada@northwind.example", "role": "CEO", "extra": true}],
                     "links": [{"title": "Deck", "url": "https://example.com/deck"},
                               {"title": "Local", "url": "file:///etc/passwd"},
                               {"url": "zoommtg://zoom.us/join"}],
                     "futureField": {"nested": 1}}]}
        """)

        XCTAssertNotNil(file.generatedAt)
        let entry = try XCTUnwrap(file.entry(forEventID: "ABC:123", start: nil))
        XCTAssertEqual(entry.headline, "Meet Ada")
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

// MARK: - Day priorities, links, prep count, stale context (PEEK-261..264)

final class ContextDayTests: XCTestCase {
    private func decode(_ json: String) throws -> MeetingContextFile {
        try MeetingContextFile.decode(Data(json.utf8))
    }

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        MeetingContextFile.parseDate(value)!
    }

    private let sample = """
    {"schemaVersion": 1, "generatedAt": "2026-11-25T08:52:00+01:00",
     "day": {"date": "2026-11-25", "headline": "Square call with Ada moved to today",
             "priorities": [{"text": "Talking points for Ada", "done": false},
                            {"text": "Ask which price was sent", "done": true},
                            {"text": "Approve the objectives"}],
             "links": [{"title": "Day log", "url": "obsidian://open?vault=Notes&file=today"}]},
     "events": [{"id": "evt-1", "bullets": ["Confirm the renewal position"]}]}
    """

    func testDayIsDecoded() throws {
        let file = try decode(sample)
        let day = try XCTUnwrap(file.day)
        XCTAssertEqual(day.headline, "Square call with Ada moved to today")
        XCTAssertEqual(day.priorities.map(\.text), ["Talking points for Ada", "Ask which price was sent", "Approve the objectives"])
        XCTAssertEqual(day.priorities.map(\.done), [false, true, false])
        XCTAssertEqual(day.links.map(\.title), ["Day log"])
        XCTAssertEqual(day.links.first?.url.scheme, "obsidian")
        XCTAssertEqual(file.entries.count, 1)
    }

    func testMissingDayIsNil() throws {
        let file = try decode("{\"schemaVersion\": 1, \"events\": [{\"id\": \"a\"}]}")
        XCTAssertNil(file.day)
        XCTAssertNil(file.visibleDay())
        XCTAssertEqual(file.entries.count, 1)
    }

    func testMalformedDayIsDroppedAndTheRestWorks() throws {
        let cases = [
            "\"day\": \"today\"",
            "\"day\": 42",
            "\"day\": {\"date\": 20261125}",
            "\"day\": {\"headline\": \"No date\"}",
            "\"day\": {\"date\": \"25/11/2026\"}",
            "\"day\": {\"date\": \"2026-02-30\"}",
            "\"day\": {\"date\": \"2026-11-25\", \"priorities\": \"not a list\"}",
            "\"day\": null"
        ]
        for fragment in cases {
            let file = try decode("{\"schemaVersion\": 1, \(fragment), \"events\": [{\"id\": \"a\", \"bullets\": [\"One\"]}]}")
            XCTAssertNil(file.day, fragment)
            XCTAssertEqual(file.entry(forEventID: "a", start: nil)?.bullets, ["One"], fragment)
        }
    }

    func testMalformedPrioritiesAndLinksAreSkipped() throws {
        let file = try decode("""
        {"schemaVersion": 1, "day": {"date": "2026-11-25",
          "priorities": [{"text": "Good"}, {"done": true}, "bare string", {"text": 7}, {"text": "  "}, {"text": "Also good", "done": "yes"}],
          "links": [{"url": 3}, {"title": "Ok", "url": "https://example.com"}]}}
        """)
        let day = try XCTUnwrap(file.day)
        XCTAssertEqual(day.priorities.map(\.text), ["Good"])
        XCTAssertEqual(day.links.map(\.title), ["Ok"])
    }

    func testLimitsAreApplied() throws {
        let long = String(repeating: "b", count: 400)
        let priorities = (1...8).map { "{\"text\": \"P\($0) \(long)\"}" }.joined(separator: ",")
        let links = (1...5).map { "{\"title\": \"L\($0)\", \"url\": \"https://example.com/\($0)\"}" }.joined(separator: ",")
        let file = try decode("""
        {"schemaVersion": 1, "day": {"date": "2026-11-25", "headline": "\(long)", "priorities": [\(priorities)], "links": [\(links)]}}
        """)
        let day = try XCTUnwrap(file.day)
        XCTAssertEqual(day.priorities.count, MeetingContextFile.Limits.maxDayPriorities)
        XCTAssertEqual(day.shownPriorities.count, 3)
        XCTAssertEqual(day.shownPriorities.first?.text.hasPrefix("P1 "), true)
        XCTAssertTrue(day.priorities.allSatisfy { $0.text.count == MeetingContextFile.Limits.maxDayPriority && $0.text.hasSuffix("…") })
        XCTAssertEqual(day.headline?.count, MeetingContextFile.Limits.maxDayHeadline)
        XCTAssertEqual(day.links.map(\.title), ["L1", "L2", "L3"])
    }

    func testOnlyTodaysDateIsShown() throws {
        let rome = calendar("Europe/Rome")
        let file = try decode(sample)
        XCTAssertNotNil(file.visibleDay(now: date("2026-11-25T09:00:00+01:00"), calendar: rome))
        XCTAssertNil(file.visibleDay(now: date("2026-11-26T09:00:00+01:00"), calendar: rome), "Tomorrow")
        XCTAssertNil(file.visibleDay(now: date("2026-11-24T20:00:00+01:00"), calendar: rome), "Yesterday")
    }

    func testDateMatchingAcrossMidnight() throws {
        let rome = calendar("Europe/Rome")
        // generatedAt omitted so freshness doesn't depend on the test instant.
        let file = try decode("{\"schemaVersion\": 1, \"day\": {\"date\": \"2026-11-25\", \"headline\": \"H\"}}")
        XCTAssertNil(file.visibleDay(now: date("2026-11-24T23:59:30+01:00"), calendar: rome))
        XCTAssertNotNil(file.visibleDay(now: date("2026-11-25T00:00:30+01:00"), calendar: rome))
        XCTAssertNotNil(file.visibleDay(now: date("2026-11-25T23:59:30+01:00"), calendar: rome))
        XCTAssertNil(file.visibleDay(now: date("2026-11-26T00:00:30+01:00"), calendar: rome))
    }

    func testDateMatchingFollowsTheTimeZone() throws {
        let file = try decode("{\"schemaVersion\": 1, \"day\": {\"date\": \"2026-11-25\", \"headline\": \"H\"}}")
        // 02:00 in Rome on the 25th is still the 24th in New York.
        let instant = date("2026-11-25T02:00:00+01:00")
        XCTAssertNotNil(file.visibleDay(now: instant, calendar: calendar("Europe/Rome")))
        XCTAssertNil(file.visibleDay(now: instant, calendar: calendar("America/New_York")))
        // 23:00 in New York on the 24th is the 25th in Tokyo.
        let evening = date("2026-11-24T23:00:00-05:00")
        XCTAssertNotNil(file.visibleDay(now: evening, calendar: calendar("Asia/Tokyo")))
    }

    func testDayWithNothingToShowIsHidden() throws {
        let rome = calendar("Europe/Rome")
        let file = try decode("{\"schemaVersion\": 1, \"day\": {\"date\": \"2026-11-25\", \"priorities\": [], \"links\": [{\"url\": \"http://example.com\"}]}}")
        XCTAssertNotNil(file.day)
        XCTAssertNil(file.visibleDay(now: date("2026-11-25T09:00:00+01:00"), calendar: rome))
    }
}

final class ContextLinkPolicyTests: XCTestCase {
    private let accepted = [
        "https://example.com/notes",
        "obsidian://open?vault=Notes&file=today",
        "OBSIDIAN://open?vault=Notes"
    ]
    private let rejected = [
        "http://example.com",
        "file:///etc/passwd",
        "javascript:alert(1)",
        "x-apple.systempreferences:com.apple.preference.security",
        "zoommtg://zoom.us/join",
        "//example.com/no-scheme",
        "example.com/no-scheme",
        "https://",
        "obsidian://"
    ]

    private func file(_ urls: [String]) throws -> MeetingContextFile {
        let links = urls.map { "{\"title\": \"T\", \"url\": \"\($0)\"}" }.joined(separator: ",")
        return try MeetingContextFile.decode(Data("""
        {"schemaVersion": 1, "day": {"date": "2026-11-25", "links": [\(links)]},
         "events": [{"id": "e", "links": [\(links)]}]}
        """.utf8))
    }

    func testAllowlistIsFixed() {
        XCTAssertEqual(ContextLinkPolicy.allowedSchemes, ["https", "obsidian"])
    }

    func testAcceptedSchemes() throws {
        for url in accepted {
            let decoded = try file([url])
            XCTAssertEqual(decoded.day?.links.count, 1, "day link \(url)")
            XCTAssertEqual(decoded.entry(forEventID: "e", start: nil)?.links.count, 1, "event link \(url)")
        }
    }

    func testRejectedSchemes() throws {
        for url in rejected {
            let decoded = try file([url])
            XCTAssertEqual(decoded.day?.links.count ?? 0, 0, "day link \(url)")
            XCTAssertEqual(decoded.entry(forEventID: "e", start: nil)?.links.count, 0, "event link \(url)")
        }
        XCTAssertEqual(try file([""]).day?.links.count ?? 0, 0, "empty url")
    }

    func testOpenerChecksThePolicyAgain() {
        XCTAssertFalse(ContextLinkOpener.open(URL(string: "file:///etc/passwd")!))
        XCTAssertFalse(ContextLinkOpener.open(URL(string: "http://example.com")!))
    }
}

final class PrepSummaryTests: XCTestCase {
    private let languages = ["en", "it", "de", "fr", "es"]

    private func bundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), language)
        return try XCTUnwrap(Bundle(path: path), language)
    }

    func testNoBulletsNoText() throws {
        for language in languages {
            XCTAssertNil(PrepSummary.text(for: [], bundle: try bundle(language)), language)
        }
    }

    func testOneAndSeveralBulletsInEveryLanguage() throws {
        let expected: [String: (one: String, two: String)] = [
            "en": ("1 to prepare: Confirm the renewal position", "2 to prepare: Confirm the renewal position"),
            "it": ("1 da preparare: Confirm the renewal position", "2 da preparare: Confirm the renewal position"),
            "de": ("1 Punkt vorzubereiten: Confirm the renewal position", "2 Punkte vorzubereiten: Confirm the renewal position"),
            "fr": ("1 à préparer : Confirm the renewal position", "2 à préparer : Confirm the renewal position"),
            "es": ("1 por preparar: Confirm the renewal position", "2 por preparar: Confirm the renewal position")
        ]
        for language in languages {
            let bundle = try bundle(language)
            let first = "Confirm the renewal position"
            XCTAssertEqual(PrepSummary.text(for: [first], bundle: bundle), expected[language]?.one, language)
            XCTAssertEqual(PrepSummary.text(for: [first, "Bring the usage report"], bundle: bundle), expected[language]?.two, language)
            XCTAssertEqual(
                PrepSummary.text(for: [first, "b", "c", "d", "e"], bundle: bundle),
                expected[language]?.two.replacingOccurrences(of: "2", with: "5"),
                language
            )
        }
    }

    func testNotificationBody() {
        XCTAssertEqual(NotificationManager.body(details: "Starts at 10:00", prepText: nil), "Starts at 10:00")
        XCTAssertEqual(
            NotificationManager.body(details: "Starts at 10:00", prepText: "2 to prepare: Confirm"),
            "Starts at 10:00\n2 to prepare: Confirm"
        )
    }

    func testChangedPrepListChangesTheNotificationSignature() {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let before = NotificationContentSignature.make(eventID: "e", startDate: start, title: "T", location: nil, meetingURLString: nil, prepText: "2 to prepare: A")
        let after = NotificationContentSignature.make(eventID: "e", startDate: start, title: "T", location: nil, meetingURLString: nil, prepText: "1 to prepare: B")
        XCTAssertNotEqual(before, after)
    }
}

final class StaleContextTests: XCTestCase {
    private let generated = MeetingContextFile.parseDate("2026-11-25T08:00:00+01:00")!

    private func file(generatedAt: String?) throws -> MeetingContextFile {
        let stamp = generatedAt.map { "\"generatedAt\": \"\($0)\"," } ?? ""
        return try MeetingContextFile.decode(Data("""
        {"schemaVersion": 1, \(stamp) "day": {"date": "2026-11-26", "headline": "H"}, "events": [{"id": "e", "summary": "S"}]}
        """.utf8))
    }

    private var rome: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }

    func testFreshAt35Hours() throws {
        let file = try file(generatedAt: "2026-11-25T08:00:00+01:00")
        let now = generated.addingTimeInterval(35 * 3600) // 2026-11-26 19:00 Rome
        XCTAssertFalse(file.isStale(now: now))
        XCTAssertNotNil(file.visibleDay(now: now, calendar: rome))
    }

    func testStaleAt37Hours() throws {
        let file = try file(generatedAt: "2026-11-25T08:00:00+01:00")
        let now = generated.addingTimeInterval(37 * 3600) // 2026-11-26 21:00 Rome
        XCTAssertTrue(file.isStale(now: now))
        XCTAssertNil(file.visibleDay(now: now, calendar: rome))
        // Meetings keep their context, with the date it came from.
        XCTAssertEqual(file.entry(forEventID: "e", start: nil)?.summary, "S")
    }

    func testMissingGeneratedAtIsFresh() throws {
        let file = try file(generatedAt: nil)
        XCTAssertFalse(file.isStale(now: generated.addingTimeInterval(30 * 24 * 3600)))
        XCTAssertNotNil(file.visibleDay(now: MeetingContextFile.parseDate("2026-11-26T09:00:00+01:00")!, calendar: rome))
    }

    func testMeetingContextCarriesTheStaleDateOnlyWithExternalContext() {
        let entry = MeetingContextFile.Entry(id: "e", startAt: nil, headline: nil, summary: "S", bullets: [], people: [], links: [])
        let stale = MeetingContextBuilder.make(attendees: [], notes: nil, contacts: nil, external: entry, externalStaleSince: generated)
        XCTAssertEqual(stale.staleContextDate, generated)
        let fresh = MeetingContextBuilder.make(attendees: [], notes: nil, contacts: nil, external: entry, externalStaleSince: nil)
        XCTAssertNil(fresh.staleContextDate)
        let none = MeetingContextBuilder.make(attendees: [], notes: nil, contacts: nil, external: nil, externalStaleSince: generated)
        XCTAssertNil(none.staleContextDate)
    }

    func testPreferencesShowWhenTheFileWasGenerated() {
        let now = generated.addingTimeInterval(3600)
        let fresh = CalendarManager.message(for: .ready(eventCount: 3, generatedAt: generated), now: now)
        XCTAssertEqual(fresh?.contains("3"), true)
        XCTAssertNotEqual(fresh, CalendarManager.message(for: .ready(eventCount: 3, generatedAt: nil), now: now))
        let stale = CalendarManager.message(for: .ready(eventCount: 3, generatedAt: generated), now: generated.addingTimeInterval(37 * 3600))
        XCTAssertNotEqual(stale, fresh)
    }
}

final class DayNeverReachesBriefTests: XCTestCase {
    func testBriefInputHoldsNothingFromDay() throws {
        let file = try MeetingContextFile.decode(Data("""
        {"schemaVersion": 1,
         "day": {"date": "2026-11-25", "headline": "DAY-HEADLINE-SECRET",
                 "priorities": [{"text": "DAY-PRIORITY-SECRET"}],
                 "links": [{"title": "DAY-LINK-SECRET", "url": "obsidian://open?vault=Notes&file=day"}]},
         "events": [{"id": "e", "summary": "Event summary", "bullets": ["Event bullet"]}]}
        """.utf8))
        XCTAssertNotNil(file.day)
        let context = MeetingContextBuilder.make(
            attendees: [AttendeeInput(name: "Giulia Rossi", email: "giulia@northwind.example")],
            notes: "Agenda",
            contacts: nil,
            external: file.entry(forEventID: "e", start: nil)
        )
        let input = BriefInput(title: "Review", start: Date(timeIntervalSince1970: 1_900_000_000), context: context)

        // The fields are exactly the ADR 0005 list.
        let fields = Mirror(reflecting: input).children.compactMap(\.label)
        XCTAssertEqual(fields, ["title", "start", "people", "agenda", "contextSummary", "contextPoints"])
        XCTAssertEqual(input.contextSummary, "Event summary")
        XCTAssertEqual(input.contextPoints, ["Event bullet"])

        let everything = String(describing: input) + BriefPrompt.prompt(for: input, now: input.start)
        for secret in ["DAY-HEADLINE-SECRET", "DAY-PRIORITY-SECRET", "DAY-LINK-SECRET", "obsidian"] {
            XCTAssertFalse(everything.contains(secret), secret)
        }
    }
}

/// A context file whose fields are labelled values copied from notes, as
/// Northwind Notes writes them: a lower-case goal as `headline`, an "open with them"
/// fragment as `summary`, and the open "to prepare" boxes as `bullets`.
final class ContextFileFormattingTests: XCTestCase {
    private let json = """
    {"schemaVersion": 1,
     "events": [{"id": "jane",
                 "headline": "uscire con il dato per Ada verificato.",
                 "summary": "report di una pagina sull’EPT. iPhone resta minuscolo solo come prima parola.",
                 "bullets": ["farti spiegare metodo e perimetro.", "Chiedere falsi positivi.", "iOS build da verificare.",
                             "Uno", "Due", "Tre", "Sette"],
                 "people": [{"email": "jane@northwind.example", "name": "jane doe", "note": "riporta a Grace"}]}],
     "day": {"date": "2026-11-25", "headline": "giornata piena", "priorities": [{"text": "block/Square"}]}}
    """

    private func entry() throws -> MeetingContextFile.Entry {
        let file = try MeetingContextFile.decode(Data(json.utf8))
        return try XCTUnwrap(file.entry(forEventID: "jane", start: nil))
    }

    func testProseFieldsStartWithACapitalLetter() throws {
        let entry = try entry()
        XCTAssertEqual(entry.headline, "Uscire con il dato per Ada verificato.")
        XCTAssertEqual(entry.summary, "Report di una pagina sull’EPT. iPhone resta minuscolo solo come prima parola.")
        XCTAssertEqual(Array(entry.bullets.prefix(3)), ["Farti spiegare metodo e perimetro.", "Chiedere falsi positivi.", "iOS build da verificare."])
        XCTAssertEqual(entry.people.first?.note, "Riporta a Grace")
        // Names are data, not sentences: left as written.
        XCTAssertEqual(entry.people.first?.name, "jane doe")

        let day = try XCTUnwrap(try MeetingContextFile.decode(Data(json.utf8)).day)
        XCTAssertEqual(day.headline, "Giornata piena")
        XCTAssertEqual(day.priorities.first?.text, "Block/Square")
    }

    func testSentenceStart() {
        XCTAssertEqual(MeetingContextFile.sentenceStart("report"), "Report")
        XCTAssertEqual(MeetingContextFile.sentenceStart("Report"), "Report")
        XCTAssertEqual(MeetingContextFile.sentenceStart("eBay call"), "eBay call")
        XCTAssertEqual(MeetingContextFile.sentenceStart("block/Square"), "Block/Square")
        XCTAssertEqual(MeetingContextFile.sentenceStart("è tardi"), "È tardi")
        XCTAssertEqual(MeetingContextFile.sentenceStart("16:35 call"), "16:35 call")
        XCTAssertEqual(MeetingContextFile.sentenceStart(""), "")
    }

    func testHeadlineFromTheFileIsMarkedSoThePageKeepsTheEventTitle() throws {
        let fromFile = MeetingContextBuilder.make(
            attendees: [AttendeeInput(name: "Jane", email: "jane@northwind.example")],
            notes: nil,
            contacts: nil,
            external: try entry()
        )
        XCTAssertTrue(fromFile.headlineIsFromContextFile)
        XCTAssertEqual(fromFile.contextFileHeadline, "Uscire con il dato per Ada verificato.")
        XCTAssertNil(fromFile.ownHeadline)

        let own = MeetingContextBuilder.make(
            attendees: [AttendeeInput(name: "Jane", email: "jane@northwind.example")],
            notes: nil,
            contacts: nil,
            external: nil
        )
        XCTAssertFalse(own.headlineIsFromContextFile)
        XCTAssertNil(own.contextFileHeadline)
        XCTAssertEqual(own.ownHeadline, own.headline)
        XCTAssertEqual(own.headline, "You're about to meet Jane, from northwind.example")
    }

    func testContextDoesNotRepeatTheBulletsShownUnderWhatToPrepare() throws {
        let context = MeetingContextBuilder.make(attendees: [], notes: nil, contacts: nil, external: try entry())
        let input = BriefInput(title: "Jane : Ada", start: Date(), context: context)
        let brief = try XCTUnwrap(BriefPolicy.contextFolderBrief(for: input, generatedAt: Date()))

        // The brief takes the first five bullets; only the sixth is left for Context.
        XCTAssertEqual(context.contextBullets(excludingBriefPoints: brief.points), ["Tre"])
        XCTAssertEqual(context.contextBullets(excludingBriefPoints: []), context.bullets)
    }
}
