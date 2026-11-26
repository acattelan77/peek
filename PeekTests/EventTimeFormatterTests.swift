import XCTest
@testable import Peek

final class EventTimeFormatterTests: XCTestCase {
    func testTimeUntilComponentsHoursAndMinutes() {
        let now = Date(timeIntervalSince1970: 0)
        let target = now.addingTimeInterval(2 * 3600 + 5 * 60)

        let result = EventTimeFormatter.timeUntilComponents(target: target, now: now)

        XCTAssertEqual(result, .hoursMinutes(2, 5))
    }

    func testTimeUntilComponentsMinutesOnly() {
        let now = Date(timeIntervalSince1970: 0)
        let target = now.addingTimeInterval(45 * 60)

        let result = EventTimeFormatter.timeUntilComponents(target: target, now: now)

        XCTAssertEqual(result, .minutes(45))
    }

    func testRoundUpAtFractionalMinutesConsistentWithMenuBar() {
        let now = Date(timeIntervalSince1970: 10_000)
        for seconds in [1.0, 30.0, 59.9, 60.0, 60.1, 330.0, 330.5, 359.9] {
            let target = now.addingTimeInterval(seconds)
            let expected = Int((seconds / 60).rounded(.up))
            XCTAssertEqual(EventTimeFormatter.roundedUpMinutes(until: target, now: now), expected)
            XCTAssertEqual(EventTimeFormatter.timeUntilComponents(target: target, now: now), .minutes(expected))
            XCTAssertEqual(StatusBarContentBuilder.minutesText(until: target, now: now), "\(expected) min")
        }
    }

    func testRoundUpOverHourBoundaryAndAtStart() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(EventTimeFormatter.timeUntilComponents(target: now.addingTimeInterval(3600), now: now), .hoursMinutes(1, 0))
        XCTAssertEqual(EventTimeFormatter.timeUntilComponents(target: now.addingTimeInterval(3600.5), now: now), .hoursMinutes(1, 1))
        XCTAssertEqual(EventTimeFormatter.timeUntilComponents(target: now, now: now), .now)
        XCTAssertEqual(EventTimeFormatter.roundedUpMinutes(until: now.addingTimeInterval(-1), now: now), 0)
    }

    func testTimeUntilComponentsNowForPastDates() {
        let now = Date(timeIntervalSince1970: 1000)
        let target = now.addingTimeInterval(-60)

        let result = EventTimeFormatter.timeUntilComponents(target: target, now: now)

        XCTAssertEqual(result, .now)
    }
}
