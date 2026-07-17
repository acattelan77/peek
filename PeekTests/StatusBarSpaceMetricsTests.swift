import XCTest
@testable import Peek

final class StatusBarSpaceMetricsTests: XCTestCase {
    private let generousWidth: CGFloat = 1512

    func testNotYetLaidOutUsesGenerousWidth() {
        XCTAssertEqual(
            StatusBarSpaceMetrics.availableWidth(
                windowState: .notYetLaidOut,
                frontierMinX: 856,
                generousWidth: generousWidth
            ),
            generousWidth
        )
    }

    func testHiddenItemReportsZeroWidth() {
        XCTAssertEqual(
            StatusBarSpaceMetrics.availableWidth(
                windowState: .hidden,
                frontierMinX: 856,
                generousWidth: generousWidth
            ),
            0
        )
    }

    func testHiddenItemReportsZeroWidthEvenWithoutFrontier() {
        XCTAssertEqual(
            StatusBarSpaceMetrics.availableWidth(
                windowState: .hidden,
                frontierMinX: nil,
                generousWidth: generousWidth
            ),
            0
        )
    }

    func testVisibleItemWithKnownFrontierComputesBuffer() {
        XCTAssertEqual(
            StatusBarSpaceMetrics.availableWidth(
                windowState: .visible(minX: 1000),
                frontierMinX: 856,
                generousWidth: generousWidth
            ),
            144
        )
    }

    func testVisibleItemLeftOfFrontierClampsToZero() {
        XCTAssertEqual(
            StatusBarSpaceMetrics.availableWidth(
                windowState: .visible(minX: 800),
                frontierMinX: 856,
                generousWidth: generousWidth
            ),
            0
        )
    }

    func testVisibleItemWithUnknownFrontierUsesGenerousWidth() {
        XCTAssertEqual(
            StatusBarSpaceMetrics.availableWidth(
                windowState: .visible(minX: 800),
                frontierMinX: nil,
                generousWidth: generousWidth
            ),
            generousWidth
        )
    }
}
