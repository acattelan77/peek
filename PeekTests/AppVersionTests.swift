import XCTest
@testable import Peek

final class AppVersionTests: XCTestCase {
    func testDisplayTextIncludesMarketingVersionAndBuild() {
        let version = AppVersion(marketingVersion: "1.1.0", buildNumber: "5")

        XCTAssertEqual(version.displayText, "Version 1.1.0 (5)")
    }
}
