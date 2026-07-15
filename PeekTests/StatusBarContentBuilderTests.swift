import XCTest
@testable import Peek

final class StatusBarContentBuilderTests: XCTestCase {
    func testTimeUntilIncludesAdditionalEventCount() {
        let content = StatusBarContentBuilder.make(
            eventTitle: "Planning",
            startDate: Date(timeIntervalSince1970: 4_900),
            eventCount: 3,
            mode: .timeUntil,
            showCount: true,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(content.title, "1h 5m - Planning (+2)")
        XCTAssertEqual(content.urgency, .normal)
    }

    func testLongTitleIsTruncatedAndPreservedInTooltip() {
        let content = StatusBarContentBuilder.make(
            eventTitle: "A very long calendar event title",
            startDate: Date(timeIntervalSince1970: 1_300),
            eventCount: 1,
            mode: .timeUntil,
            showCount: false,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertTrue(content.title.contains("A very long calendar..."))
        XCTAssertEqual(content.tooltip, "5m - A very long calendar event title")
    }
}
