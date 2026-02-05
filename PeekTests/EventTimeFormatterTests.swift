import XCTest

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

    func testTimeUntilComponentsNowForPastDates() {
        let now = Date(timeIntervalSince1970: 1000)
        let target = now.addingTimeInterval(-60)

        let result = EventTimeFormatter.timeUntilComponents(target: target, now: now)

        XCTAssertEqual(result, .now)
    }
}
