import XCTest
@testable import Peek

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
        XCTAssertEqual(result.upcomingEvents, [future])
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

final class AppDelegateLogicTests: XCTestCase {
    func testUpdateIntervalMatchesUrgencyLevel() {
        XCTAssertEqual(StatusBarRefreshPolicy.interval(for: .critical), 5)
        XCTAssertEqual(StatusBarRefreshPolicy.interval(for: .urgent), 5)
        XCTAssertEqual(StatusBarRefreshPolicy.interval(for: .normal), 60)
    }
}

final class NotificationManagerSignatureTests: XCTestCase {
    func testNotificationContentSignatureChangesWhenTitleChanges() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let original = NotificationContentSignature.make(
            eventID: "event-1",
            startDate: startDate,
            title: "Team Sync",
            location: "Room A",
            meetingURLString: nil
        )
        let updated = NotificationContentSignature.make(
            eventID: "event-1",
            startDate: startDate,
            title: "Executive Sync",
            location: "Room A",
            meetingURLString: nil
        )

        XCTAssertNotEqual(original, updated)
    }

    func testNotificationContentSignatureChangesWhenLocationOrMeetingLinkChanges() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let original = NotificationContentSignature.make(
            eventID: "event-1",
            startDate: startDate,
            title: "Team Sync",
            location: "Room A",
            meetingURLString: "https://meet.google.com/abc-defg-hij"
        )
        let relocated = NotificationContentSignature.make(
            eventID: "event-1",
            startDate: startDate,
            title: "Team Sync",
            location: "Room B",
            meetingURLString: "https://meet.google.com/abc-defg-hij"
        )
        let relinked = NotificationContentSignature.make(
            eventID: "event-1",
            startDate: startDate,
            title: "Team Sync",
            location: "Room A",
            meetingURLString: "https://acme.zoom.us/j/123456789"
        )

        XCTAssertNotEqual(original, relocated)
        XCTAssertNotEqual(original, relinked)
    }
}

final class LaunchAtLoginCoordinatorTests: XCTestCase {
    private final class TestLaunchAtLoginController: LaunchAtLoginControlling {
        var currentValue: Bool
        var errorToThrow: Error?
        var mutatesCurrentValue = true

        init(currentValue: Bool) {
            self.currentValue = currentValue
        }

        func setEnabled(_ enabled: Bool) throws {
            if let errorToThrow {
                throw errorToThrow
            }

            if mutatesCurrentValue {
                currentValue = enabled
            }
        }
    }

    private struct TestError: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }

    func testLaunchAtLoginCoordinatorAppliesSuccessfulChanges() {
        let controller = TestLaunchAtLoginController(currentValue: false)

        let result = LaunchAtLoginCoordinator.apply(requestedValue: true, controller: controller)

        XCTAssertEqual(result, LaunchAtLoginUpdateResult(effectiveValue: true, errorMessage: nil))
    }

    func testLaunchAtLoginCoordinatorRollsBackWhenControllerThrows() {
        let controller = TestLaunchAtLoginController(currentValue: false)
        controller.errorToThrow = TestError(message: "Registration failed")

        let result = LaunchAtLoginCoordinator.apply(requestedValue: true, controller: controller)

        XCTAssertEqual(
            result,
            LaunchAtLoginUpdateResult(effectiveValue: false, errorMessage: "Registration failed")
        )
    }

    func testLaunchAtLoginCoordinatorReportsMismatchWhenSystemStateDoesNotChange() {
        let controller = TestLaunchAtLoginController(currentValue: false)
        controller.mutatesCurrentValue = false

        let result = LaunchAtLoginCoordinator.apply(requestedValue: true, controller: controller)

        XCTAssertEqual(result.effectiveValue, false)
        XCTAssertEqual(result.errorMessage, "macOS did not enable Launch at Login for Peek.")
    }
}
