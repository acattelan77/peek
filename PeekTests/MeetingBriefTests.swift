import XCTest
@testable import Peek

/// Fictional meetings only; no real people or companies (PEEK-224).
private enum BriefFixtures {
    static let start = Date(timeIntervalSince1970: 1_900_000_000)

    static let partnerReview = BriefInput(
        title: "Quarterly review with Northwind",
        start: start,
        people: [
            .init(name: "Giulia Rossi", descriptor: "COO at Northwind", note: "Prefers numbers before slides"),
            .init(name: "Tom Becker", descriptor: nil, note: nil)
        ],
        agenda: "Review Q3 volumes\nAgree on the renewal date",
        contextSummary: "Renewal is due in December.",
        contextPoints: []
    )

    static let titleOnly = BriefInput(title: "Focus time", start: start, people: [], agenda: nil, contextSummary: nil, contextPoints: [])

    static let fromContextFile = BriefInput(
        title: "Board prep",
        start: start,
        people: [],
        agenda: nil,
        contextSummary: nil,
        contextPoints: ["Bring the cash forecast", "Confirm the hiring plan", "Check the audit dates", "Ask about the office move", "Review the risk list", "Extra point"]
    )
}

final class BriefPromptTests: XCTestCase {
    func testPromptHoldsOnlyTheAllowedFields() {
        let prompt = BriefPrompt.prompt(for: BriefFixtures.partnerReview, now: BriefFixtures.start.addingTimeInterval(-600))
        XCTAssertTrue(prompt.contains("Meeting: Quarterly review with Northwind"))
        XCTAssertTrue(prompt.contains("Starts in: 10 minutes"))
        XCTAssertTrue(prompt.contains("- Giulia Rossi, COO at Northwind. Note: Prefers numbers before slides"))
        XCTAssertTrue(prompt.contains("- Tom Becker"))
        XCTAssertTrue(prompt.contains("Agree on the renewal date"))
        XCTAssertTrue(prompt.contains("Renewal is due in December."))
        XCTAssertFalse(prompt.contains("@"), "No email addresses may reach a model")
        XCTAssertFalse(prompt.contains("http"), "No links may reach a model")
    }

    func testPromptOmitsCountdownForPastStart() {
        let prompt = BriefPrompt.prompt(for: BriefFixtures.partnerReview, now: BriefFixtures.start.addingTimeInterval(120))
        XCTAssertFalse(prompt.contains("Starts in"))
    }

    func testInstructionsNameTheLanguage() {
        XCTAssertTrue(BriefPrompt.instructions(language: "Italian").contains("Write in Italian."))
    }

    func testInputClipsAgendaAndPeople() {
        let people = (0..<12).map { BriefInput.Person(name: "Person \($0)", descriptor: nil, note: nil) }
        let input = BriefInput(title: "Big call", start: BriefFixtures.start, people: people, agenda: String(repeating: "a", count: 4000), contextSummary: nil, contextPoints: [])
        XCTAssertEqual(input.people.count, BriefInput.maxPeople)
        XCTAssertEqual(input.agenda?.count, BriefInput.maxAgendaLength)
    }

    func testFingerprintIsStableAndChangesWithInput() {
        let a = BriefPrompt.fingerprint(for: BriefFixtures.partnerReview, source: .onDevice)
        XCTAssertEqual(a, BriefPrompt.fingerprint(for: BriefFixtures.partnerReview, source: .onDevice))
        XCTAssertEqual(a.count, 64)
        XCTAssertNotEqual(a, BriefPrompt.fingerprint(for: BriefFixtures.partnerReview, source: .cloud))
        let edited = BriefInput(
            title: BriefFixtures.partnerReview.title,
            start: BriefFixtures.start,
            people: BriefFixtures.partnerReview.people,
            agenda: "New agenda",
            contextSummary: BriefFixtures.partnerReview.contextSummary,
            contextPoints: []
        )
        XCTAssertNotEqual(a, BriefPrompt.fingerprint(for: edited, source: .onDevice))
    }
}

final class BriefParserTests: XCTestCase {
    func testStripsMarkersHeadingsAndEmphasis() {
        let text = """
        Here is your brief:
        - **Bring** the Q3 volume report
        2) Confirm the renewal date
        • Ask Giulia about numbers first

        * Decide on the discount
        """
        XCTAssertEqual(BriefParser.points(from: text), [
            "Bring the Q3 volume report",
            "Confirm the renewal date",
            "Ask Giulia about numbers first",
            "Decide on the discount"
        ])
    }

    func testCapsPointsAndLength() {
        let text = (1...8).map { "- Point \($0)" }.joined(separator: "\n") + "\n- " + String(repeating: "x", count: 400)
        let points = BriefParser.points(from: text)
        XCTAssertEqual(points.count, BriefPrompt.maxPoints)
        let long = BriefParser.points(from: "- " + String(repeating: "x", count: 400))
        XCTAssertEqual(long.first?.count, BriefParser.maxPointLength)
        XCTAssertTrue(long.first?.hasSuffix("…") ?? false)
    }

    func testEmptyTextGivesNoPoints() {
        XCTAssertTrue(BriefParser.points(from: "\n  \nSummary:\n").isEmpty)
    }
}

final class BriefPolicyTests: XCTestCase {
    func testEligibility() {
        let input = BriefFixtures.partnerReview
        XCTAssertTrue(BriefPolicy.isEligible(input: input, notes: nil, isAllDay: false, isDeclined: false, excludedKeywords: []))
        XCTAssertFalse(BriefPolicy.isEligible(input: input, notes: nil, isAllDay: true, isDeclined: false, excludedKeywords: []))
        XCTAssertFalse(BriefPolicy.isEligible(input: input, notes: nil, isAllDay: false, isDeclined: true, excludedKeywords: []))
        XCTAssertFalse(BriefPolicy.isEligible(input: BriefFixtures.titleOnly, notes: nil, isAllDay: false, isDeclined: false, excludedKeywords: []))
    }

    func testExcludedKeywordsMatchTitleAndNotes() {
        let input = BriefFixtures.partnerReview
        XCTAssertFalse(BriefPolicy.isEligible(input: input, notes: nil, isAllDay: false, isDeclined: false, excludedKeywords: ["northwind"]))
        XCTAssertFalse(BriefPolicy.isEligible(input: input, notes: "Private: therapy", isAllDay: false, isDeclined: false, excludedKeywords: ["private"]))
        XCTAssertTrue(BriefPolicy.isEligible(input: input, notes: "Open agenda", isAllDay: false, isDeclined: false, excludedKeywords: ["private"]))
    }

    func testDueWindow() {
        let start = BriefFixtures.start
        XCTAssertFalse(BriefPolicy.isDue(start: start, now: start.addingTimeInterval(-16 * 60)))
        XCTAssertTrue(BriefPolicy.isDue(start: start, now: start.addingTimeInterval(-15 * 60)))
        XCTAssertTrue(BriefPolicy.isDue(start: start, now: start.addingTimeInterval(4 * 60)))
        XCTAssertFalse(BriefPolicy.isDue(start: start, now: start.addingTimeInterval(6 * 60)))
    }

    func testContextFolderBriefWinsWithoutAModel() {
        let brief = BriefPolicy.contextFolderBrief(for: BriefFixtures.fromContextFile, generatedAt: BriefFixtures.start)
        XCTAssertEqual(brief?.source, .contextFolder)
        XCTAssertEqual(brief?.points.count, BriefPrompt.maxPoints)
        XCTAssertNil(BriefPolicy.contextFolderBrief(for: BriefFixtures.partnerReview, generatedAt: BriefFixtures.start))
    }
}

final class ClaudeBriefEngineTests: XCTestCase {
    func testRequestShape() throws {
        let request = try ClaudeBriefEngine.makeRequest(apiKey: "test-key", instructions: "Be brief.", prompt: "Meeting: Demo")
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "anthropic-version"))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, ClaudeBriefEngine.model)
        XCTAssertEqual(body["system"] as? String, "Be brief.")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.first?["role"] as? String, "user")
        XCTAssertEqual(messages.first?["content"] as? String, "Meeting: Demo")
    }

    func testParseJoinsTextBlocks() throws {
        let body = #"{"stop_reason":"end_turn","content":[{"type":"text","text":"- One"},{"type":"text","text":"- Two"}]}"#
        XCTAssertEqual(try ClaudeBriefEngine.parse(status: 200, body: Data(body.utf8)), "- One\n- Two")
    }

    func testParseMapsErrors() {
        XCTAssertThrowsError(try ClaudeBriefEngine.parse(status: 401, body: Data())) { XCTAssertEqual($0 as? BriefError, .invalidAPIKey) }
        XCTAssertThrowsError(try ClaudeBriefEngine.parse(status: 429, body: Data())) { XCTAssertEqual($0 as? BriefError, .rateLimited) }
        XCTAssertThrowsError(try ClaudeBriefEngine.parse(status: 529, body: Data())) { XCTAssertEqual($0 as? BriefError, .service(529)) }
        let refusal = #"{"stop_reason":"refusal","content":[]}"#
        XCTAssertThrowsError(try ClaudeBriefEngine.parse(status: 200, body: Data(refusal.utf8))) { XCTAssertEqual($0 as? BriefError, .refused) }
        let empty = #"{"stop_reason":"end_turn","content":[{"type":"text","text":"  "}]}"#
        XCTAssertThrowsError(try ClaudeBriefEngine.parse(status: 200, body: Data(empty.utf8))) { XCTAssertEqual($0 as? BriefError, .emptyResponse) }
    }

    func testUnavailableWithoutKey() {
        XCTAssertFalse(ClaudeBriefEngine(apiKey: { nil }).availability().isAvailable)
        XCTAssertTrue(ClaudeBriefEngine(apiKey: { "k" }).availability().isAvailable)
    }
}

final class BriefCacheStoreTests: XCTestCase {
    func testRoundTripDropsExpiredBriefs() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("briefs.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = BriefCacheStore(fileURL: url)
        let now = BriefFixtures.start
        let fresh = MeetingBrief(points: ["Bring the report"], source: .onDevice, generatedAt: now.addingTimeInterval(-3600), fingerprint: "a")
        let stale = MeetingBrief(points: ["Old"], source: .cloud, generatedAt: now.addingTimeInterval(-BriefCacheStore.maxAge - 1), fingerprint: "b")
        store.save(["fresh": fresh, "stale": stale])

        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: url.path), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(store.load(now: now), ["fresh": fresh])
    }
}

private struct FakeEngine: BriefEngine {
    let source: BriefSource
    var available = true
    func availability() -> BriefEngineAvailability { available ? .available : .unavailable("off") }
    func generate(instructions: String, prompt: String) async throws -> String { "- Point" }
}

final class MeetingBriefServiceSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MeetingBriefServiceSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeService() -> MeetingBriefService {
        MeetingBriefService(
            defaults: defaults,
            cache: BriefCacheStore(fileURL: nil),
            onDevice: FakeEngine(source: .onDevice),
            cloud: FakeEngine(source: .cloud)
        )
    }

    func testOffByDefaultAndOnDeviceFirst() {
        let service = makeService()
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.engineChoice, .onDevice)
        XCTAssertEqual(service.activeEngine?.source, .onDevice)
    }

    func testCloudNeedsConsent() {
        let service = makeService()
        service.setEngine(.cloud)
        XCTAssertEqual(service.engineChoice, .onDevice, "Declined or missing consent keeps the on-device engine")
        service.setEngine(.cloud, consented: true)
        XCTAssertEqual(service.engineChoice, .cloud)
        XCTAssertTrue(service.hasCloudConsent)
        XCTAssertEqual(service.activeEngine?.source, .cloud)
    }

    func testOlderConsentVersionIsNotEnough() {
        defaults.set(MeetingBriefService.currentCloudConsentVersion - 1, forKey: MeetingBriefService.Keys.cloudConsentVersion)
        defaults.set(MeetingBriefService.EngineChoice.cloud.rawValue, forKey: MeetingBriefService.Keys.engine)
        XCTAssertNil(makeService().activeEngine)
    }

    func testExcludedKeywordsAreParsed() {
        let service = makeService()
        service.setExcludedKeywords("Private, 1:1 ,  ")
        XCTAssertEqual(service.excludedKeywords, ["private", "1:1"])
    }
}
