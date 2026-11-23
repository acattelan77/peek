import XCTest
@testable import Peek

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
        let lookalike = URL(string: "https://zoom.us.evil.example/j/123")!

        XCTAssertFalse(MeetingURLDetector.isURLSafe(insecure))
        XCTAssertFalse(MeetingURLDetector.isURLSafe(untrusted))
        XCTAssertFalse(MeetingURLDetector.isURLSafe(lookalike))
    }

    func testFindURLInTextFindsMeetingURL() {
        let text = "Join via https://meet.google.com/abc-defg-hij today"
        let found = MeetingURLDetector.findURL(in: text)

        XCTAssertEqual(found?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    /// A corpus of join links in the shapes providers actually send. Each entry is
    /// embedded in invitation-like text and must come back exactly.
    func testCorpusOfProviderLinks() {
        let corpus = [
            "https://zoom.us/j/123456789",
            "https://acme.zoom.us/j/123456789?pwd=abcDEF123",
            "https://us02web.zoom.us/j/87654321012",
            "https://acme.zoom.us/my/jane.doe",
            "https://acme.zoom.us/s/123456789",
            "https://acme.zoom.us/w/123456789?tk=abc",
            "https://app.zoom.us/wc/join/123456789",
            "https://acme.zoomgov.com/j/1612345678",
            "https://meet.google.com/abc-defg-hij",
            "https://meet.google.com/abc-defg-hij?authuser=1",
            "https://meet.google.com/lookup/abcdef1234",
            "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%22Tid%22%3a%22x%22%7d",
            "https://teams.microsoft.com/meet/1234567890?p=abcdef",
            "https://teams.live.com/meet/9876543210",
            "https://acme.webex.com/acme/j.php?MTID=m123",
            "https://global.gotomeeting.com/join/123456789",
            "https://meet.goto.com/123456789",
            "https://app.slack.com/huddle/T0123ABC/C0456DEF",
            "https://chime.aws/1234567890",
            "https://meet.jit.si/PeekWeeklySync",
            "https://facetime.apple.com/join#v=1&p=abc&k=def",
            "https://v.ringcentral.com/join/123456789",
            "https://whereby.com/peek-team",
            "https://discord.gg/abc123"
        ]

        for link in corpus {
            let text = "Hi all,\nJoin the meeting: \(link)\nDial-in: +1 555 0100"
            XCTAssertEqual(MeetingURLDetector.findURL(in: text)?.absoluteString, link, "Not detected: \(link)")
        }
    }

    func testLinksInsideAngleBracketsAndPunctuation() {
        let teams = "Click here to join <https://teams.microsoft.com/l/meetup-join/abc%40thread.v2/0>."
        XCTAssertEqual(
            MeetingURLDetector.findURL(in: teams)?.absoluteString,
            "https://teams.microsoft.com/l/meetup-join/abc%40thread.v2/0"
        )

        let zoom = "(https://acme.zoom.us/j/123456789)"
        XCTAssertEqual(MeetingURLDetector.findURL(in: zoom)?.absoluteString, "https://acme.zoom.us/j/123456789")
    }

    func testEarliestLinkInTextWins() {
        let text = "Main room https://meet.google.com/abc-defg-hij, backup https://acme.zoom.us/j/123456789"

        XCTAssertEqual(MeetingURLDetector.findURL(in: text)?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testIgnoresUntrustedAndNonMeetingLinks() {
        XCTAssertNil(MeetingURLDetector.findURL(in: "Docs: https://example.com/agenda"))
        XCTAssertNil(MeetingURLDetector.findURL(in: "Zoom support https://support.zoom.us/hc/en-us"))
        XCTAssertNil(MeetingURLDetector.findURL(in: "Insecure http://zoom.us/j/123"))
    }

    func testExtractFromPrioritizesURLThenLocationThenNotes() {
        let notes = "Agenda: https://meet.google.com/abc-defg-hij"
        let location = "https://acme.zoom.us/j/123456"
        let url = URL(string: "https://teams.microsoft.com/l/meetup-join/xyz")

        XCTAssertEqual(
            MeetingURLDetector.extractFrom(notes: notes, location: location, url: url)?.absoluteString,
            "https://teams.microsoft.com/l/meetup-join/xyz"
        )
        XCTAssertEqual(
            MeetingURLDetector.extractFrom(notes: notes, location: location, url: nil)?.absoluteString,
            "https://acme.zoom.us/j/123456"
        )
        XCTAssertEqual(
            MeetingURLDetector.extractFrom(notes: notes, location: "Room 4", url: URL(string: "https://example.com")),
            URL(string: "https://meet.google.com/abc-defg-hij")
        )
    }

    func testExtractFromFallsBackToNotesWhenLocationUnsafe() {
        let notes = "https://acme.zoom.us/j/123456"
        let location = "http://zoom.us/j/123"

        let result = MeetingURLDetector.extractFrom(notes: notes, location: location, url: nil)

        XCTAssertEqual(result?.absoluteString, "https://acme.zoom.us/j/123456")
    }

    func testZoomPasswordQueryIsPreserved() {
        let text = "Join https://acme.zoom.us/j/123456789?pwd=abcDEF123."

        let result = MeetingURLDetector.findURL(in: text)

        XCTAssertEqual(result?.absoluteString, "https://acme.zoom.us/j/123456789?pwd=abcDEF123")
    }

    func testExportV1JoinClassificationIsFrozen() {
        XCTAssertTrue(MeetingURLDetector.isExportV1JoinURL(URL(string: "https://acme.zoom.us/j/1")!))
        XCTAssertTrue(MeetingURLDetector.isExportV1JoinURL(URL(string: "https://meet.google.com/abc-defg-hij")!))
        // Providers added after export v1 stay out of the v1 join classification.
        XCTAssertFalse(MeetingURLDetector.isExportV1JoinURL(URL(string: "https://teams.live.com/meet/1")!))
        XCTAssertFalse(MeetingURLDetector.isExportV1JoinURL(URL(string: "https://meet.jit.si/room")!))
        XCTAssertFalse(MeetingURLDetector.isExportV1JoinURL(URL(string: "https://acme.zoomgov.com/j/1")!))
    }

    // MARK: - Providers and native apps

    func testProviderLabelsForNewProviders() {
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://teams.live.com/meet/1")!), "Teams")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://app.slack.com/huddle/T/C")!), "Slack")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://chime.aws/123")!), "Chime")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://meet.jit.si/room")!), "Jitsi")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://facetime.apple.com/join#v=1")!), "FaceTime")
        XCTAssertEqual(MeetingProvider.label(for: URL(string: "https://meet.goto.com/123")!), "GoTo")
    }

    func testZoomNativeAppURLCarriesMeetingAndPassword() {
        let url = URL(string: "https://acme.zoom.us/j/123456789?pwd=abcDEF123")!
        let native = MeetingProvider.nativeAppURL(for: url)

        XCTAssertEqual(native?.scheme, "zoommtg")
        XCTAssertEqual(native?.host, "acme.zoom.us")
        let items = native.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "confno", value: "123456789")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "pwd", value: "abcDEF123")))
    }

    func testZoomPersonalRoomHasNoNativeURL() {
        XCTAssertNil(MeetingProvider.nativeAppURL(for: URL(string: "https://acme.zoom.us/my/jane.doe")!))
    }

    func testTeamsNativeAppURLKeepsPath() {
        let url = URL(string: "https://teams.microsoft.com/l/meetup-join/abc%40thread.v2/0?context=x")!
        let native = MeetingProvider.nativeAppURL(for: url)

        XCTAssertEqual(native?.scheme, "msteams")
        XCTAssertEqual(native?.absoluteString, "msteams:/l/meetup-join/abc%40thread.v2/0?context=x")
    }

    func testProvidersWithoutAppHaveNoNativeURL() {
        XCTAssertNil(MeetingProvider.nativeAppURL(for: URL(string: "https://meet.google.com/abc-defg-hij")!))
        XCTAssertNil(MeetingProvider.nativeAppURL(for: URL(string: "https://evil.example.com/j/1")!))
    }

    func testOpenerPrefersInstalledNativeApp() {
        let zoom = URL(string: "https://acme.zoom.us/j/123")!

        let native = MeetingLinkOpener.destination(for: zoom, preferNativeApp: true, canOpen: { _ in true })
        XCTAssertEqual(native?.scheme, "zoommtg")

        let notInstalled = MeetingLinkOpener.destination(for: zoom, preferNativeApp: true, canOpen: { _ in false })
        XCTAssertEqual(notInstalled, zoom)

        let browser = MeetingLinkOpener.destination(for: zoom, preferNativeApp: false, canOpen: { _ in true })
        XCTAssertEqual(browser, zoom)
    }

    func testOpenerRefusesUntrustedLinks() {
        let untrusted = URL(string: "https://evil.example.com/j/1")!
        XCTAssertNil(MeetingLinkOpener.destination(for: untrusted, preferNativeApp: true, canOpen: { _ in true }))
    }
}
