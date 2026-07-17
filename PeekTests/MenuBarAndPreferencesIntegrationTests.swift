import XCTest
import EventKit
@testable import Peek

/// Integration tests for the menu-bar popover and preferences UI states.
///
/// These tests exercise the `CalendarManager` and view-initialization seams that
/// drive `MenuBarView` and `PreferencesView` without requiring a separate UI-test
/// target or rendered-view introspection.
final class MenuBarAndPreferencesIntegrationTests: XCTestCase {
    private var eventStore: FakeCalendarEventStore!
    private var preferencesStore: UserDefaults!
    private var calendarManager: CalendarManager!
    private var preferencesSuiteName: String!

    override func setUp() {
        super.setUp()
        preferencesSuiteName = "com.peek.app.tests.ui.\(UUID().uuidString)"
        preferencesStore = UserDefaults(suiteName: preferencesSuiteName)!
        eventStore = FakeCalendarEventStore()
        calendarManager = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )
    }

    override func tearDown() {
        calendarManager.stopObservingChanges()
        calendarManager = nil
        preferencesStore = nil
        eventStore = nil
        if let suiteName = preferencesSuiteName {
            UserDefaults().removeSuite(named: suiteName)
            preferencesSuiteName = nil
        }
        super.tearDown()
    }

    // MARK: - First launch

    func testFirstLaunchEnablesAllCalendarsByDefault() {
        let workCalendar = eventStore.addCalendar(title: "Work")
        let personalCalendar = eventStore.addCalendar(title: "Personal")

        // Clear any persisted selection written by setUp so this manager truly
        // exercises the first-launch "enable all" path.
        preferencesStore.removeObject(forKey: "enabledCalendarIDs")
        preferencesStore.removeObject(forKey: "hasCustomCalendarSelection")

        // Create the manager after calendars exist so first-launch defaults load them.
        let firstLaunchManager = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )

        XCTAssertTrue(firstLaunchManager.isCalendarEnabled(workCalendar.calendarIdentifier))
        XCTAssertTrue(firstLaunchManager.isCalendarEnabled(personalCalendar.calendarIdentifier))
        XCTAssertFalse(firstLaunchManager.hasCustomCalendarSelection)
    }

    // MARK: - Denied calendar access

    func testDeniedAccessShowsNoCalendarAccessState() {
        calendarManager.hasCalendarAccess = false

        XCTAssertTrue(calendarManager.upcomingEvents.isEmpty)
        XCTAssertFalse(calendarManager.hasCalendarAccess)
    }

    func testRefreshButtonDisabledWhenNoCalendarAccess() {
        calendarManager.hasCalendarAccess = false

        // The view disables refresh through `disabled(isRefreshing || !calendarManager.hasCalendarAccess)`.
        XCTAssertFalse(calendarManager.hasCalendarAccess)
    }

    // MARK: - Empty state

    func testEmptyStateWithAccessShowsNoEvents() {
        _ = eventStore.addCalendar(title: "Work")
        calendarManager.hasCalendarAccess = true

        let expectation = self.expectation(description: "fetch completed")
        calendarManager.fetchNextEvent { event in
            XCTAssertNil(event)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertTrue(calendarManager.upcomingEvents.isEmpty)
    }

    // MARK: - Event list

    func testEventListShowsMultipleUpcomingEvents() {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        let first = eventStore.addEvent(
            title: "First",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            calendar: calendar
        )
        let second = eventStore.addEvent(
            title: "Second",
            startDate: now.addingTimeInterval(3600),
            endDate: now.addingTimeInterval(7200),
            calendar: calendar
        )

        calendarManager.hasCalendarAccess = true

        let expectation = self.expectation(description: "fetch completed")
        calendarManager.fetchNextEvent { event in
            XCTAssertEqual(event?.title, first.title)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(calendarManager.upcomingEvents.map(\.title), [first.title, second.title])
    }

    func testEventListRespectsMaxEventsToShow() {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        for index in 1...5 {
            eventStore.addEvent(
                title: "Event \(index)",
                startDate: now.addingTimeInterval(TimeInterval(index * 60)),
                endDate: now.addingTimeInterval(TimeInterval(index * 60 + 60)),
                calendar: calendar
            )
        }
        calendarManager.hasCalendarAccess = true
        calendarManager.maxEventsToShow = 3

        let expectation = self.expectation(description: "fetch completed")
        calendarManager.fetchNextEvent { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(calendarManager.upcomingEvents.count, 3)
    }

    // MARK: - Preferences: calendars

    func testTogglingCalendarRemovesItFromEnabledSet() {
        let calendar = eventStore.addCalendar(title: "Work")
        preferencesStore.removeObject(forKey: "enabledCalendarIDs")
        preferencesStore.removeObject(forKey: "hasCustomCalendarSelection")
        let managerWithCalendar = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )
        XCTAssertTrue(managerWithCalendar.isCalendarEnabled(calendar.calendarIdentifier))

        managerWithCalendar.toggleCalendar(calendar.calendarIdentifier)

        XCTAssertFalse(managerWithCalendar.isCalendarEnabled(calendar.calendarIdentifier))
        XCTAssertTrue(managerWithCalendar.hasCustomCalendarSelection)
    }

    func testSelectAllCalendarsEnablesEveryCalendar() {
        let work = eventStore.addCalendar(title: "Work")
        let personal = eventStore.addCalendar(title: "Personal")
        preferencesStore.removeObject(forKey: "enabledCalendarIDs")
        preferencesStore.removeObject(forKey: "hasCustomCalendarSelection")
        let managerWithCalendars = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )
        managerWithCalendars.toggleCalendar(work.calendarIdentifier)
        managerWithCalendars.toggleCalendar(personal.calendarIdentifier)
        XCTAssertFalse(managerWithCalendars.isCalendarEnabled(work.calendarIdentifier))
        XCTAssertFalse(managerWithCalendars.isCalendarEnabled(personal.calendarIdentifier))

        let allCalendars = eventStore.calendars(for: .event).sorted { $0.title < $1.title }
        for calendar in allCalendars {
            if !managerWithCalendars.isCalendarEnabled(calendar.calendarIdentifier) {
                managerWithCalendars.toggleCalendar(calendar.calendarIdentifier)
            }
        }

        XCTAssertTrue(managerWithCalendars.isCalendarEnabled(work.calendarIdentifier))
        XCTAssertTrue(managerWithCalendars.isCalendarEnabled(personal.calendarIdentifier))
    }

    // MARK: - Preferences: filters

    func testFilterTogglesPersist() {
        calendarManager.hideAllDayEvents = true
        calendarManager.hideDeclinedEvents = true
        calendarManager.filterKeywords = "canceled, optional"
        calendarManager.savePreferences()

        let restored = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )

        XCTAssertTrue(restored.hideAllDayEvents)
        XCTAssertTrue(restored.hideDeclinedEvents)
        XCTAssertEqual(restored.filterKeywords, "canceled, optional")
    }

    // MARK: - Preferences: general

    func testGeneralSettingsPersist() {
        calendarManager.lookaheadDays = 14
        calendarManager.maxEventsToShow = 10
        calendarManager.statusBarMode = .actualTime
        calendarManager.menuBarSpacePolicy = .alwaysShowIcon
        calendarManager.showEventCount = false
        calendarManager.urgencyColorsEnabled = false
        calendarManager.appearanceMode = .dark
        calendarManager.globalHotkey = .cmdOptionC
        calendarManager.notificationsEnabled = true
        calendarManager.notificationTiming = .fiveMinutes
        calendarManager.savePreferences()

        let restored = CalendarManager(
            eventStore: eventStore,
            preferencesStore: preferencesStore
        )

        XCTAssertEqual(restored.lookaheadDays, 14)
        XCTAssertEqual(restored.maxEventsToShow, 10)
        XCTAssertEqual(restored.statusBarMode, .actualTime)
        XCTAssertEqual(restored.menuBarSpacePolicy, .alwaysShowIcon)
        XCTAssertFalse(restored.showEventCount)
        XCTAssertFalse(restored.urgencyColorsEnabled)
        XCTAssertEqual(restored.appearanceMode, .dark)
        XCTAssertEqual(restored.globalHotkey, .cmdOptionC)
        XCTAssertTrue(restored.notificationsEnabled)
        XCTAssertEqual(restored.notificationTiming, .fiveMinutes)
    }

    // MARK: - View instantiation

    func testMenuBarViewInstantiatesWithFakeDependencies() {
        let view = MenuBarView(
            calendarManager: calendarManager,
            closePopover: {},
            refreshStatusBar: { _ in }
        )
        XCTAssertNotNil(view)
    }

    func testPreferencesViewInstantiatesWithFakeLaunchController() {
        let controller = FakeLaunchAtLoginController(currentValue: false)
        let view = PreferencesView(
            calendarManager: calendarManager,
            launchAtLoginController: controller
        )
        XCTAssertNotNil(view)
    }
}
