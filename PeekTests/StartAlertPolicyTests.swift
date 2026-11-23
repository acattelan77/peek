import XCTest
@testable import Peek

final class StartAlertPolicyTests: XCTestCase {
    func testOffAndHudStylesIgnoreEventKind() {
        for link in [true, false] {
            for attendees in [true, false] {
                XCTAssertEqual(
                    StartAlertPolicy.presentation(style: .off, interruptOnlyForMeetings: true, hasJoinLink: link, hasAttendees: attendees),
                    .none
                )
                XCTAssertEqual(
                    StartAlertPolicy.presentation(style: .hud, interruptOnlyForMeetings: false, hasJoinLink: link, hasAttendees: attendees),
                    .hud
                )
            }
        }
    }

    func testFullScreenInterruptsForMeetings() {
        XCTAssertEqual(
            StartAlertPolicy.presentation(style: .fullScreen, interruptOnlyForMeetings: true, hasJoinLink: true, hasAttendees: false),
            .fullScreen
        )
        XCTAssertEqual(
            StartAlertPolicy.presentation(style: .fullScreen, interruptOnlyForMeetings: true, hasJoinLink: false, hasAttendees: true),
            .fullScreen
        )
    }

    func testFullScreenFallsBackToHudForSoloEventsWhenOnlyMeetings() {
        XCTAssertEqual(
            StartAlertPolicy.presentation(style: .fullScreen, interruptOnlyForMeetings: true, hasJoinLink: false, hasAttendees: false),
            .hud
        )
        XCTAssertEqual(
            StartAlertPolicy.presentation(style: .fullScreen, interruptOnlyForMeetings: false, hasJoinLink: false, hasAttendees: false),
            .fullScreen
        )
    }

    func testSnoozeDelays() {
        XCTAssertEqual(StartAlertPolicy.snoozeDelay(for: .fullScreen), 60)
        XCTAssertEqual(StartAlertPolicy.snoozeDelay(for: .hud), 300)
    }

    func testStartAlertStyleRawValuesAreStable() {
        // Stored in UserDefaults; renaming a case must not reset the preference.
        XCTAssertEqual(StartAlertStyle.off.rawValue, "Off")
        XCTAssertEqual(StartAlertStyle.hud.rawValue, "Heads-up card")
        XCTAssertEqual(StartAlertStyle.fullScreen.rawValue, "Full screen")
    }
}
