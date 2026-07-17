import XCTest
import EventKit
import Combine
@testable import Peek

final class CalendarManagerIntegrationTests: XCTestCase {
    private var eventStore: FakeCalendarEventStore!
    private var notificationScheduler: FakeNotificationScheduler!
    private var calendarManager: CalendarManager!
    private var preferencesSuiteName: String!

    override func setUp() {
        super.setUp()
        // Use an isolated UserDefaults suite so the host app or previous runs cannot
        // pollute the test's calendar-selection state.
        preferencesSuiteName = "com.peek.app.tests.\(UUID().uuidString)"
        let preferencesStore = UserDefaults(suiteName: preferencesSuiteName)!
        eventStore = FakeCalendarEventStore()
        notificationScheduler = FakeNotificationScheduler()
        calendarManager = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )
    }

    override func tearDown() {
        calendarManager.stopObservingChanges()
        calendarManager = nil
        notificationScheduler = nil
        eventStore = nil
        if let suiteName = preferencesSuiteName {
            UserDefaults().removeSuite(named: suiteName)
            preferencesSuiteName = nil
        }
        super.tearDown()
    }

    // MARK: - Authorization

    func testRequestAccessUpdatesHasCalendarAccessWhenGranted() {
        eventStore.requestAccessResult = (granted: true, error: nil)
        eventStore.requestFullAccessResult = (granted: true, error: nil)

        let expectation = self.expectation(description: "access granted")
        var cancellable: AnyCancellable?
        cancellable = calendarManager.$hasCalendarAccess
            .dropFirst()
            .sink { isGranted in
                XCTAssertTrue(isGranted)
                cancellable?.cancel()
                expectation.fulfill()
            }

        calendarManager.requestAccess { granted, error in
            XCTAssertTrue(granted)
            XCTAssertNil(error)
        }

        waitForExpectations(timeout: 1)
    }

    func testRequestAccessUpdatesHasCalendarAccessWhenDenied() {
        eventStore.requestAccessResult = (granted: false, error: nil)

        let expectation = self.expectation(description: "access denied")
        var cancellable: AnyCancellable?
        cancellable = calendarManager.$hasCalendarAccess
            .dropFirst()
            .sink { isGranted in
                XCTAssertFalse(isGranted)
                cancellable?.cancel()
                expectation.fulfill()
            }

        calendarManager.requestAccess { granted, error in
            XCTAssertFalse(granted)
            XCTAssertNil(error)
        }

        waitForExpectations(timeout: 1)
    }

    func testRefreshAuthorizationStatusReflectsFakeAuthorizedAccess() {
        eventStore.authorizationStatus = .authorized

        let granted = calendarManager.refreshAuthorizationStatus()

        XCTAssertTrue(granted)
        XCTAssertTrue(calendarManager.hasCalendarAccess)
    }

    func testRefreshAuthorizationStatusReflectsFakeFullAccess() throws {
        guard #available(macOS 14.0, *) else {
            throw XCTSkip("Full Access authorization status requires macOS 14 or later.")
        }

        eventStore.authorizationStatus = .fullAccess

        let granted = calendarManager.refreshAuthorizationStatus()

        XCTAssertTrue(granted)
        XCTAssertTrue(calendarManager.hasCalendarAccess)
    }

    func testRefreshAuthorizationStatusReflectsFakeDeniedAccess() {
        eventStore.authorizationStatus = .denied

        let granted = calendarManager.refreshAuthorizationStatus()

        XCTAssertFalse(granted)
        XCTAssertFalse(calendarManager.hasCalendarAccess)
    }

    // MARK: - Refresh

    func testFetchNextEventReturnsNextEventFromFakeStore() {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        let sooner = eventStore.addEvent(
            title: "Sooner",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            calendar: calendar
        )
        let later = eventStore.addEvent(
            title: "Later",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(7200),
            calendar: calendar
        )

        let expectation = self.expectation(description: "fetch completed")
        calendarManager.hasCalendarAccess = true
        calendarManager.fetchNextEvent { event in
            XCTAssertEqual(event?.title, sooner.title)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(calendarManager.upcomingEvents.map(\.title), [sooner.title, later.title])
    }

    func testFetchNextEventUsesAllCalendarsWhenNoCustomSelection() {
        let workCalendar = eventStore.addCalendar(title: "Work")
        let personalCalendar = eventStore.addCalendar(title: "Personal")
        let now = Date()
        let workEvent = eventStore.addEvent(
            title: "Work Event",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            calendar: workCalendar
        )
        let personalEvent = eventStore.addEvent(
            title: "Personal Event",
            startDate: now.addingTimeInterval(120),
            endDate: now.addingTimeInterval(180),
            calendar: personalCalendar
        )

        calendarManager.hasCalendarAccess = true

        let expectation = self.expectation(description: "fetch completed")
        calendarManager.fetchNextEvent { event in
            XCTAssertEqual(event?.title, workEvent.title)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(calendarManager.upcomingEvents.map(\.title), [workEvent.title, personalEvent.title])
    }

    func testFetchNextEventReturnsNoEventsWhenCustomSelectionIsEmpty() {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        eventStore.addEvent(
            title: "Work Event",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            calendar: calendar
        )

        // Seed an isolated preferences store so the manager treats the empty
        // enabled-calendar set as a deliberate custom selection.
        let suiteName = "com.peek.app.tests.empty-selection"
        let preferencesStore = UserDefaults(suiteName: suiteName)!
        preferencesStore.set([], forKey: "enabledCalendarIDs")
        preferencesStore.removeObject(forKey: "hasCustomCalendarSelection")
        let configuredManager = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )
        configuredManager.hasCalendarAccess = true

        let expectation = self.expectation(description: "fetch completed")
        configuredManager.fetchNextEvent { event in
            XCTAssertNil(event)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertTrue(configuredManager.upcomingEvents.isEmpty)
        UserDefaults().removeSuite(named: suiteName)
    }

    func testFetchNextEventFiltersAllDayEvents() {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        eventStore.addEvent(
            title: "All Day",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            calendar: calendar,
            isAllDay: true
        )
        let normalEvent = eventStore.addEvent(
            title: "Normal",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            calendar: calendar
        )

        calendarManager.hasCalendarAccess = true
        calendarManager.hideAllDayEvents = true

        let expectation = self.expectation(description: "fetch completed")
        calendarManager.fetchNextEvent { event in
            XCTAssertEqual(event?.title, normalEvent.title)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(calendarManager.upcomingEvents.map(\.title), [normalEvent.title])
    }

    func testEventStoreChangedNotificationTriggersRefresh() {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        calendarManager.hasCalendarAccess = true

        let refreshExpectation = self.expectation(description: "refresh after change")
        calendarManager.startObservingChanges { [weak self] in
            self?.calendarManager.fetchNextEvent { _ in
                refreshExpectation.fulfill()
            }
        }

        eventStore.addEvent(
            title: "New Event",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            calendar: calendar
        )
        NotificationCenter.default.post(
            name: .EKEventStoreChanged,
            object: eventStore.notificationObject
        )

        waitForExpectations(timeout: 1)
        XCTAssertEqual(calendarManager.upcomingEvents.map(\.title), ["New Event"])
    }

    // MARK: - Notifications

    func testFakeNotificationSchedulerRecordsScheduleCalls() {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        let event = eventStore.addEvent(
            title: "Meeting",
            startDate: now.addingTimeInterval(600),
            endDate: now.addingTimeInterval(1200),
            calendar: calendar
        )

        notificationScheduler.scheduleNotifications(for: [event], timing: .fifteenMinutes)

        XCTAssertEqual(notificationScheduler.scheduledEvents.map(\.title), [event.title])
        XCTAssertEqual(notificationScheduler.lastTiming, .fifteenMinutes)
    }

    func testFakeNotificationSchedulerRecordsPermissionRequest() {
        notificationScheduler.permissionGranted = true

        let expectation = self.expectation(description: "permission request")
        notificationScheduler.requestPermission { granted in
            XCTAssertTrue(granted)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssertTrue(notificationScheduler.requestedPermission)
    }
}
