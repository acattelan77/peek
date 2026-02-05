import XCTest

final class MeetingURLDetectorTests: XCTestCase {
    func testIsURLSafeAcceptsTrustedDomains() {
        let zoom = URL(string: "https://acme.zoom.us/j/123456")!
        let meet = URL(string: "https://meet.google.com/abc-defg-hij")!

        XCTAssertTrue(MeetingURLDetector.isURLSafe(zoom))
        XCTAssertTrue(MeetingURLDetector.isURLSafe(meet))
    }

    func testIsURLSafeRejectsNonHttpsOrUntrusted() {
        let insecure = URL(string: "http://zoom.us/j/123")!
        let untrusted = URL(string: "https://evil.example.com/j/123")!

        XCTAssertFalse(MeetingURLDetector.isURLSafe(insecure))
        XCTAssertFalse(MeetingURLDetector.isURLSafe(untrusted))
    }

    func testFindURLInTextFindsMeetingURL() {
        let text = "Join via https://meet.google.com/abc-defg-hij today"
        let found = MeetingURLDetector.findURL(in: text)

        XCTAssertEqual(found?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testExtractFromPrioritizesNotesThenLocationThenURL() {
        let notes = "Agenda: https://meet.google.com/abc-defg-hij"
        let location = "https://acme.zoom.us/j/123456"
        let url = URL(string: "https://teams.microsoft.com/l/meetup-join/xyz")

        let result = MeetingURLDetector.extractFrom(notes: notes, location: location, url: url)

        XCTAssertEqual(result?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testExtractFromFallsBackToLocationWhenNotesUnsafe() {
        let notes = "http://zoom.us/j/123"
        let location = "https://acme.zoom.us/j/123456"

        let result = MeetingURLDetector.extractFrom(notes: notes, location: location, url: nil)

        XCTAssertEqual(result?.absoluteString, "https://acme.zoom.us/j/123456")
    }
}
