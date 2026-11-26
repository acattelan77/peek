import XCTest
@testable import Peek

final class StatusBarSpacePolicyTests: XCTestCase {
    func testAlwaysShowIconStartsAndStaysIconOnly() {
        var policy = StatusBarSpacePolicy(mode: .alwaysShowIcon)

        XCTAssertEqual(policy.update(availableWidth: 1000, requiredWidth: 10, notchMargin: 0), .iconOnly)
        XCTAssertEqual(policy.update(availableWidth: 0, requiredWidth: 1000, notchMargin: 0), .iconOnly)
    }

    func testAlwaysShowTextStartsAndStaysText() {
        var policy = StatusBarSpacePolicy(mode: .alwaysShowText)

        XCTAssertEqual(policy.update(availableWidth: 0, requiredWidth: 1000, notchMargin: 0), .text)
        XCTAssertEqual(policy.update(availableWidth: 1000, requiredWidth: 10, notchMargin: 0), .text)
    }

    func testAutomaticSwitchesToIconWhenSpaceIsTight() {
        var policy = StatusBarSpacePolicy(mode: .automatic)

        XCTAssertEqual(policy.update(availableWidth: 200, requiredWidth: 100, notchMargin: 0), .text)
        XCTAssertEqual(policy.update(availableWidth: 90, requiredWidth: 100, notchMargin: 0), .iconOnly)
    }

    func testAutomaticHysteresisPreventsRapidSwitching() {
        var policy = StatusBarSpacePolicy(mode: .automatic, hysteresis: 10)

        // Start with plenty of space -> text
        XCTAssertEqual(policy.update(availableWidth: 200, requiredWidth: 100, notchMargin: 0), .text)

        // Cross below the cramped threshold -> icon
        XCTAssertEqual(policy.update(availableWidth: 95, requiredWidth: 100, notchMargin: 0), .iconOnly)

        // Rise back above the cramped threshold but below the relaxed threshold -> stay icon
        XCTAssertEqual(policy.update(availableWidth: 105, requiredWidth: 100, notchMargin: 0), .iconOnly)

        // Rise above the relaxed threshold (required + hysteresis) -> text again
        XCTAssertEqual(policy.update(availableWidth: 111, requiredWidth: 100, notchMargin: 0), .text)
    }

    func testNotchMarginCausesEarlierFallback() {
        var policy = StatusBarSpacePolicy(mode: .automatic)

        // Without a notch margin, available width equal to required width keeps text.
        XCTAssertEqual(policy.update(availableWidth: 100, requiredWidth: 100, notchMargin: 0), .text)

        // With a notch margin, the same available width is treated as cramped.
        XCTAssertEqual(policy.update(availableWidth: 100, requiredWidth: 100, notchMargin: 20), .iconOnly)
    }

    func testInitializesFromMenuBarSpacePolicy() {
        let iconPolicy = StatusBarSpacePolicy(policy: .alwaysShowIcon)
        XCTAssertEqual(iconPolicy.presentation, .iconOnly)

        let textPolicy = StatusBarSpacePolicy(policy: .alwaysShowText)
        XCTAssertEqual(textPolicy.presentation, .text)

        let autoPolicy = StatusBarSpacePolicy(policy: .automatic)
        XCTAssertEqual(autoPolicy.presentation, .text)
    }
}

/// Regression coverage for secondary-screen popover anchoring.
final class PopoverMultiDisplayRegressionTests: XCTestCase {
    func testStatusItemWidthCanBeLockedOnlyAfterLayout() {
        XCTAssertTrue(PopoverPresentationPolicy.canLockStatusItemWidth(38))
        XCTAssertTrue(PopoverPresentationPolicy.canLockStatusItemWidth(273))
        XCTAssertFalse(PopoverPresentationPolicy.canLockStatusItemWidth(0))
        XCTAssertFalse(PopoverPresentationPolicy.canLockStatusItemWidth(-1))
        XCTAssertFalse(PopoverPresentationPolicy.canLockStatusItemWidth(.infinity))
        XCTAssertFalse(PopoverPresentationPolicy.canLockStatusItemWidth(.nan))
    }

    func testVisiblePopoverKeepsOpeningAnchorAcrossSameAndDifferentScreenDrift() {
        let initial = NSRect(x: -150, y: 1050, width: 38, height: 24)
        let sameDisplayDrift = NSRect(x: -225, y: 1050, width: 38, height: 24)
        let otherDisplay = NSRect(x: 1300, y: 1050, width: 38, height: 24)
        XCTAssertEqual(PopoverPresentationPolicy.anchorFrame(
            initial: initial, candidate: sameDisplayDrift, popoverIsShown: true), initial)
        XCTAssertEqual(PopoverPresentationPolicy.anchorFrame(
            initial: initial, candidate: otherDisplay, popoverIsShown: true), initial)
        XCTAssertEqual(PopoverPresentationPolicy.anchorFrame(
            initial: initial, candidate: sameDisplayDrift, popoverIsShown: false), sameDisplayDrift)
    }

    func testAnchorRefreshCannotCrossToDifferentDisplay() {
        let leftScreen = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let leftStatusButton = NSRect(x: -150, y: 1050, width: 38, height: 24)
        let primaryStatusButton = NSRect(x: 1300, y: 1050, width: 38, height: 24)
        XCTAssertTrue(PopoverPresentationPolicy.shouldAcceptAnchorRefresh(
            candidate: leftStatusButton, presentationScreenFrame: leftScreen))
        XCTAssertFalse(PopoverPresentationPolicy.shouldAcceptAnchorRefresh(
            candidate: primaryStatusButton, presentationScreenFrame: leftScreen))
    }

    func testAnchorRefreshAllowsFallbackWhenNoScreenWasCaptured() {
        let button = NSRect(x: 150, y: 800, width: 40, height: 24)
        XCTAssertTrue(PopoverPresentationPolicy.shouldAcceptAnchorRefresh(
            candidate: button, presentationScreenFrame: nil))
    }
}
