import XCTest
@testable import Peek

final class MeetingUrgencyTests: XCTestCase {
    func testMeetingUrgencyThresholds() {
        XCTAssertEqual(MeetingUrgency.from(minutesUntil: -1), .critical)
        XCTAssertEqual(MeetingUrgency.from(minutesUntil: 0), .critical)
        XCTAssertEqual(MeetingUrgency.from(minutesUntil: 1), .critical)
        XCTAssertEqual(MeetingUrgency.from(minutesUntil: 2), .urgent)
        XCTAssertEqual(MeetingUrgency.from(minutesUntil: 9), .urgent)
        XCTAssertEqual(MeetingUrgency.from(minutesUntil: 10), .normal)
    }
}
