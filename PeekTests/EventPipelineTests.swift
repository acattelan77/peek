import XCTest

final class EventPipelineTests: XCTestCase {
    private struct TestEvent: EventCandidate, Equatable {
        let id: String
        let candidateStartDate: Date?
        let candidateEndDate: Date?
        let isAllDay: Bool
        let candidateTitle: String?
        let candidateNotes: String?
        let currentUserDeclined: Bool
    }

    func testFiltersEndedEvents() {
        let now = Date(timeIntervalSince1970: 1000)
        let ended = TestEvent(
            id: "ended",
            candidateStartDate: now.addingTimeInterval(-3600),
            candidateEndDate: now.addingTimeInterval(-1),
            isAllDay: false,
            candidateTitle: "Past",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let upcoming = TestEvent(
            id: "upcoming",
            candidateStartDate: now.addingTimeInterval(60),
            candidateEndDate: now.addingTimeInterval(3600),
            isAllDay: false,
            candidateTitle: "Future",
            candidateNotes: nil,
            currentUserDeclined: false
        )

        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: false, filterKeywords: "")
        let result = EventPipeline.filterAndSelect(
            events: [ended, upcoming],
            now: now,
            settings: settings,
            maxEvents: 5,
            lateGraceMinutes: 5
        )

        XCTAssertEqual(result.upcomingEvents, [upcoming])
    }

    func testHideAllDayEvents() {
        let now = Date(timeIntervalSince1970: 1000)
        let allDay = TestEvent(
            id: "allDay",
            candidateStartDate: now.addingTimeInterval(60),
            candidateEndDate: now.addingTimeInterval(3600),
            isAllDay: true,
            candidateTitle: "All Day",
            candidateNotes: nil,
            currentUserDeclined: false
        )

        let settings = EventFilterSettings(hideAllDayEvents: true, hideDeclinedEvents: false, filterKeywords: "")
        let result = EventPipeline.filterAndSelect(
            events: [allDay],
            now: now,
            settings: settings,
            maxEvents: 5,
            lateGraceMinutes: 5
        )

        XCTAssertTrue(result.upcomingEvents.isEmpty)
    }

    func testHideDeclinedEvents() {
        let now = Date(timeIntervalSince1970: 1000)
        let declined = TestEvent(
            id: "declined",
            candidateStartDate: now.addingTimeInterval(60),
            candidateEndDate: now.addingTimeInterval(3600),
            isAllDay: false,
            candidateTitle: "Declined",
            candidateNotes: nil,
            currentUserDeclined: true
        )

        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: true, filterKeywords: "")
        let result = EventPipeline.filterAndSelect(
            events: [declined],
            now: now,
            settings: settings,
            maxEvents: 5,
            lateGraceMinutes: 5
        )

        XCTAssertTrue(result.upcomingEvents.isEmpty)
    }

    func testFilterKeywordsExcludesMatches() {
        let now = Date(timeIntervalSince1970: 1000)
        let keep = TestEvent(
            id: "keep",
            candidateStartDate: now.addingTimeInterval(60),
            candidateEndDate: now.addingTimeInterval(3600),
            isAllDay: false,
            candidateTitle: "Team Sync",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let titleMatch = TestEvent(
            id: "titleMatch",
            candidateStartDate: now.addingTimeInterval(120),
            candidateEndDate: now.addingTimeInterval(3600),
            isAllDay: false,
            candidateTitle: "Canceled: review",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let notesMatch = TestEvent(
            id: "notesMatch",
            candidateStartDate: now.addingTimeInterval(180),
            candidateEndDate: now.addingTimeInterval(3600),
            isAllDay: false,
            candidateTitle: "Design",
            candidateNotes: "Optional participants",
            currentUserDeclined: false
        )

        let settings = EventFilterSettings(
            hideAllDayEvents: false,
            hideDeclinedEvents: false,
            filterKeywords: "canceled, optional"
        )
        let result = EventPipeline.filterAndSelect(
            events: [keep, titleMatch, notesMatch],
            now: now,
            settings: settings,
            maxEvents: 10,
            lateGraceMinutes: 5
        )

        XCTAssertEqual(result.upcomingEvents, [keep])
    }

    func testSortingByStartDate() {
        let now = Date(timeIntervalSince1970: 1000)
        let later = TestEvent(
            id: "later",
            candidateStartDate: now.addingTimeInterval(3600),
            candidateEndDate: now.addingTimeInterval(7200),
            isAllDay: false,
            candidateTitle: "Later",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let sooner = TestEvent(
            id: "sooner",
            candidateStartDate: now.addingTimeInterval(600),
            candidateEndDate: now.addingTimeInterval(1200),
            isAllDay: false,
            candidateTitle: "Sooner",
            candidateNotes: nil,
            currentUserDeclined: false
        )

        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: false, filterKeywords: "")
        let result = EventPipeline.filterAndSelect(
            events: [later, sooner],
            now: now,
            settings: settings,
            maxEvents: 5,
            lateGraceMinutes: 5
        )

        XCTAssertEqual(result.upcomingEvents, [sooner, later])
    }

    func testLateEventWithinGraceBecomesNextEvent() {
        let now = Date(timeIntervalSince1970: 1000)
        let ongoing = TestEvent(
            id: "ongoing",
            candidateStartDate: now.addingTimeInterval(-120),
            candidateEndDate: now.addingTimeInterval(1800),
            isAllDay: false,
            candidateTitle: "Ongoing",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let future = TestEvent(
            id: "future",
            candidateStartDate: now.addingTimeInterval(600),
            candidateEndDate: now.addingTimeInterval(1200),
            isAllDay: false,
            candidateTitle: "Future",
            candidateNotes: nil,
            currentUserDeclined: false
        )

        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: false, filterKeywords: "")
        let result = EventPipeline.filterAndSelect(
            events: [future, ongoing],
            now: now,
            settings: settings,
            maxEvents: 5,
            lateGraceMinutes: 5
        )

        XCTAssertEqual(result.nextEvent, ongoing)
    }

    func testLateEventOutsideGraceIgnored() {
        let now = Date(timeIntervalSince1970: 1000)
        let staleOngoing = TestEvent(
            id: "stale",
            candidateStartDate: now.addingTimeInterval(-600),
            candidateEndDate: now.addingTimeInterval(1800),
            isAllDay: false,
            candidateTitle: "Stale",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let future = TestEvent(
            id: "future",
            candidateStartDate: now.addingTimeInterval(300),
            candidateEndDate: now.addingTimeInterval(900),
            isAllDay: false,
            candidateTitle: "Future",
            candidateNotes: nil,
            currentUserDeclined: false
        )

        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: false, filterKeywords: "")
        let result = EventPipeline.filterAndSelect(
            events: [staleOngoing, future],
            now: now,
            settings: settings,
            maxEvents: 5,
            lateGraceMinutes: 5
        )

        XCTAssertEqual(result.nextEvent, future)
    }

    func testLimitedEventsRespectsMax() {
        let now = Date(timeIntervalSince1970: 1000)
        let first = TestEvent(
            id: "first",
            candidateStartDate: now.addingTimeInterval(60),
            candidateEndDate: now.addingTimeInterval(120),
            isAllDay: false,
            candidateTitle: "First",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let second = TestEvent(
            id: "second",
            candidateStartDate: now.addingTimeInterval(180),
            candidateEndDate: now.addingTimeInterval(240),
            isAllDay: false,
            candidateTitle: "Second",
            candidateNotes: nil,
            currentUserDeclined: false
        )
        let third = TestEvent(
            id: "third",
            candidateStartDate: now.addingTimeInterval(300),
            candidateEndDate: now.addingTimeInterval(360),
            isAllDay: false,
            candidateTitle: "Third",
            candidateNotes: nil,
            currentUserDeclined: false
        )

        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: false, filterKeywords: "")
        let result = EventPipeline.filterAndSelect(
            events: [first, second, third],
            now: now,
            settings: settings,
            maxEvents: 2,
            lateGraceMinutes: 5
        )

        XCTAssertEqual(result.limitedEvents, [first, second])
    }
}
