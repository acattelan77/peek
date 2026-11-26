import EventKit
import XCTest
@testable import Peek

final class CalendarExportTests: XCTestCase {
    func testCommandLineParsesValidExport() {
        XCTAssertEqual(
            CalendarExportCommandLine.parse(arguments: ["--export", "--from", "-3", "--to", "14", "--json"]),
            .command(.export(.init(fromDays: -3, toDays: 14)))
        )
        XCTAssertEqual(CalendarExportCommandLine.parse(arguments: ["--help"]), .command(.help))
    }

    func testCommandLineRejectsMissingInvalidAndOutOfOrderArguments() {
        for arguments in [
            ["--export", "--from", "-3", "--to", "14"],
            ["--export", "--from", "tomorrow", "--to", "14", "--json"],
            ["--export", "--from", "15", "--to", "14", "--json"],
            ["--from", "-3"]
        ] {
            guard case .failure = CalendarExportCommandLine.parse(arguments: arguments) else {
                return XCTFail("Expected invalid CLI arguments: \(arguments)")
            }
        }
    }

    func testWindowUsesLocalMidnightsAcrossMonthYearAndDST() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        let yearEnd = try date("2026-12-31T18:00:00+01:00")
        let newYearWindow = try XCTUnwrap(CalendarExportWindow.make(
            request: .init(fromDays: -1, toDays: 1), now: yearEnd, calendar: calendar
        ))
        XCTAssertEqual(string(newYearWindow.from, zone), "2026-12-30T00:00:00+01:00")
        XCTAssertEqual(string(newYearWindow.toExclusive, zone), "2027-01-02T00:00:00+01:00")

        let dstDay = try date("2026-03-29T12:00:00+02:00")
        let dstWindow = try XCTUnwrap(CalendarExportWindow.make(
            request: .init(fromDays: 0, toDays: 0), now: dstDay, calendar: calendar
        ))
        XCTAssertEqual(string(dstWindow.from, zone), "2026-03-29T00:00:00+01:00")
        XCTAssertEqual(string(dstWindow.toExclusive, zone), "2026-03-30T00:00:00+02:00")
        XCTAssertEqual(
            CalendarExportDateFormatter(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0))).string(from: dstDay),
            "2026-03-29T10:00:00+00:00"
        )
    }

    func testPayloadEventsUseStableSortAndSchemaJSON() throws {
        let first = makeEvent(id: "b", title: "Same", startAt: "2026-08-13T09:00:00+02:00", endAt: "2026-08-13T10:00:00+02:00")
        let second = makeEvent(id: "a", title: "Same", startAt: "2026-08-13T09:00:00+02:00", endAt: "2026-08-13T10:00:00+02:00")
        let later = makeEvent(id: "c", title: "Later", startAt: "2026-08-13T11:00:00+02:00", endAt: "2026-08-13T12:00:00+02:00")
        XCTAssertEqual([first, second, later].sorted(by: CalendarExportEventMapper.stableOrder).map(\.id), ["a", "b", "c"])

        let payload = CalendarExportPayload(
            schemaVersion: 1,
            generatedAt: "2026-08-13T06:45:00+02:00",
            timeZone: "Europe/Rome",
            window: .init(from: "2026-08-10T00:00:00+02:00", toExclusive: "2026-08-28T00:00:00+02:00"),
            events: [second]
        )
        let data = try payload.encodedJSON()
        let decoded = try JSONDecoder().decode(CalendarExportPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertNotNil(object["events"] as? [[String: Any]])
    }

    func testNotesNormalizeWhitespaceAndTruncateUnicodeWithoutSplittingCharacters() {
        XCTAssertNil(CalendarExportEventMapper.truncatedNotes(" \n\t "))
        let notes = "  " + String(repeating: "👩🏽‍💻", count: 600) + "  "
        let result = CalendarExportEventMapper.truncatedNotes(notes)
        XCTAssertEqual(result?.count, 500)
        XCTAssertTrue(result?.hasPrefix("👩🏽‍💻") == true)
    }

    func testAttendeeAndCurrentUserResponsesReuseEventDetailMapping() {
        let attendee = CalendarExportEventMapper.makeAttendee(
            name: "  ",
            participantURL: URL(string: "mailto:ada@example.com"),
            status: .tentative,
            isOrganizer: true
        )
        XCTAssertEqual(attendee, .init(name: "ada@example.com", response: .tentative, isOrganizer: true))
        XCTAssertEqual(CalendarExportEventMapper.currentUserResponse(status: .declined), .declined)
        XCTAssertEqual(CalendarExportEventMapper.currentUserResponse(status: nil), .unknown)
    }

    func testLinksDeduplicateAndOnlyTrustSafeHTTPSMeetingURLsAsJoin() {
        let links = CalendarExportEventMapper.links(
            notes: "Join https://meet.google.com/abc-defg-hij and read https://example.com/doc.",
            location: "Map https://example.com/doc and https://zoom.us/j/123456789",
            eventURL: URL(string: "http://zoom.us/j/123456789")
        )
        XCTAssertEqual(links, [
            .init(kind: .join, url: "https://meet.google.com/abc-defg-hij"),
            .init(kind: .document, url: "https://example.com/doc"),
            .init(kind: .join, url: "https://zoom.us/j/123456789"),
            .init(kind: .document, url: "http://zoom.us/j/123456789")
        ])
    }

    func testCalendarSelectionHonorsExplicitSelectionFirstLaunchAndExplicitEmptySelection() {
        let store = FakeCalendarEventStore()
        let work = store.addCalendar(title: "Work")
        let personal = store.addCalendar(title: "Personal")
        let suiteName = "com.peek.calendar-export.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { TestDefaults.remove(suiteName) }

        XCTAssertEqual(CalendarExportCalendarSelection.resolve(allCalendars: [work, personal], preferences: defaults).count, 2)
        defaults.set([work.calendarIdentifier], forKey: CalendarExportCalendarSelection.enabledCalendarIDsKey)
        defaults.set(true, forKey: CalendarExportCalendarSelection.hasCustomCalendarSelectionKey)
        XCTAssertEqual(CalendarExportCalendarSelection.resolve(allCalendars: [work, personal], preferences: defaults).map(\.calendarIdentifier), [work.calendarIdentifier])
        defaults.set([], forKey: CalendarExportCalendarSelection.enabledCalendarIDsKey)
        XCTAssertTrue(CalendarExportCalendarSelection.resolve(allCalendars: [work, personal], preferences: defaults).isEmpty)
    }

    func testServiceDoesNotProducePayloadWhenAccessIsMissingOrEventKitFails() throws {
        let store = FakeCalendarEventStore()
        let suiteName = "com.peek.calendar-export.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { TestDefaults.remove(suiteName) }
        let service = CalendarExportService(eventStore: store, preferences: defaults)
        XCTAssertThrowsError(try service.makePayload(request: .init(fromDays: 0, toDays: 0))) { error in
            XCTAssertEqual(error.localizedDescription, CalendarExportServiceError.calendarAccessRequired.localizedDescription)
        }

        store.authorizationStatus = .authorized
        let calendar = store.addCalendar(title: "Work")
        _ = store.addEvent(title: "Event", startDate: Date(), endDate: Date().addingTimeInterval(60), calendar: calendar)
        store.eventsError = ExportTestError.failed
        XCTAssertThrowsError(try service.makePayload(request: .init(fromDays: 0, toDays: 0)))
    }

    private func makeEvent(id: String, title: String, startAt: String, endAt: String) -> CalendarExportPayload.Event {
        .init(
            id: id, title: title, startAt: startAt, endAt: endAt, allDay: false,
            calendar: .init(id: "work", title: "Work"), location: nil, organizer: .init(name: nil),
            attendees: [], notes: nil, links: [], currentUserResponse: .unknown
        )
    }

    private func date(_ string: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: string) else { throw ExportTestError.invalidDate }
        return date
    }

    private func string(_ date: Date, _ zone: TimeZone) -> String {
        CalendarExportDateFormatter(timeZone: zone).string(from: date)
    }

}

private enum ExportTestError: Error {
    case failed
    case invalidDate
}
