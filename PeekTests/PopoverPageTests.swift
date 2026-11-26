import XCTest
@testable import Peek

/// PEEK-285: settings replace the calendar as the popover's only page.
final class PopoverPageTests: XCTestCase {
    func testCalendarIsTheDefaultPage() {
        XCTAssertEqual(PopoverPagePolicy.page(showingSettings: false, hasMeeting: false), .calendar)
    }

    func testMeetingPageReplacesTheCalendar() {
        XCTAssertEqual(PopoverPagePolicy.page(showingSettings: false, hasMeeting: true), .meeting)
    }

    func testSettingsAreTheOnlyPageEvenOverAnOpenMeeting() {
        XCTAssertEqual(PopoverPagePolicy.page(showingSettings: true, hasMeeting: false), .settings)
        XCTAssertEqual(PopoverPagePolicy.page(showingSettings: true, hasMeeting: true), .settings)
    }

    func testCalendarKeysAreOffOnTheSettingsPage() {
        XCTAssertTrue(PopoverPagePolicy.calendarHandlesKeys(on: .calendar))
        XCTAssertTrue(PopoverPagePolicy.calendarHandlesKeys(on: .meeting))
        XCTAssertFalse(PopoverPagePolicy.calendarHandlesKeys(on: .settings))
    }
}
