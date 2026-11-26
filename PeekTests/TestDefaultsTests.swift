import XCTest
@testable import Peek

/// Test runs must not leave preference files behind.
final class TestDefaultsTests: XCTestCase {
    func testRemoveEmptiesTheSuiteAndDeletesItsPlist() throws {
        let (defaults, name) = TestDefaults.make("cleanup")
        defaults.set(true, forKey: "written")
        XCTAssertTrue(defaults.synchronize())

        TestDefaults.remove(name)

        let reopened = try XCTUnwrap(UserDefaults(suiteName: name))
        XCTAssertNil(reopened.object(forKey: "written"))
        let url = try XCTUnwrap(TestDefaults.plistURL(for: name))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testEachSuiteNameIsUnique() {
        let first = TestDefaults.make("unique")
        let second = TestDefaults.make("unique")
        defer {
            TestDefaults.remove(first.name)
            TestDefaults.remove(second.name)
        }
        XCTAssertNotEqual(first.name, second.name)
        XCTAssertTrue(first.name.hasPrefix(TestDefaults.prefix))
    }
}
