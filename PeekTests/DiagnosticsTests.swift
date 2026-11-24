import XCTest
@testable import Peek

/// PEEK-275: local diagnostics never carry meeting content, and old data is pruned.
final class DiagnosticsTests: XCTestCase {
    private var directory: URL!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PeekDiagnosticsTests-\(UUID().uuidString)", isDirectory: true)
        suiteName = "com.peek.app.tests.\(UUID().uuidString)"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Text a real event could hold. None of it may reach a log line.
    private let sensitive = [
        "Board review with Marco", "Marco Rossi", "marco@example.com",
        "Via del Corso 1", "zoom.us/j/123", "obsidian://open", "/Users/someone/42"
    ]

    private func everyEvent() -> [DiagnosticEvent] {
        let ref = DiagnosticEventRef.make(identifier: "Board review with Marco")
        return [
            .appLaunched(version: "1.13.1", build: "49", system: "Version 26.1 (Build 25B78)"),
            .calendarAccess(granted: false, errorCode: 1),
            .calendarRefreshed(durationMs: 12, eventCount: 30, calendarCount: 4),
            .calendarRefreshFailed(errorCode: 17),
            .notificationPermission(granted: true, errorCode: nil),
            .notificationsRescheduled(reason: .eventsChanged, eventCount: 12),
            .notificationsRequested(requestCount: 11),
            .notificationsScheduled(result: "scheduled"),
            .notificationsCleared,
            .notificationSnoozed(minutes: 5),
            .alertShown(kind: .startFullScreen, eventRef: ref),
            .alertSkipped(kind: .startCard, reason: .badgeOnly, eventRef: ref),
            .alertSkipped(kind: .soonCard, reason: .filtered, eventRef: ref),
            .hotkeyRegistrationFailed(shortcut: HotkeyOption.cmdShiftC.rawValue),
            .contextFile(state: .stale, eventCount: 8),
            .briefFinished(source: BriefSource.cloud.rawValue, outcome: "service(503)"),
            .metricPayloadSaved(kind: "diagnostics"),
            .diagnosticsExported(entryCount: 40, payloadCount: 2)
        ]
    }

    func testMessagesCarryNoEventContent() {
        for event in everyEvent() {
            let message = event.message
            XCTAssertFalse(message.isEmpty)
            for text in sensitive {
                XCTAssertFalse(message.localizedCaseInsensitiveContains(text), "\(message) leaks \(text)")
            }
            XCTAssertFalse(message.localizedCaseInsensitiveContains("marco"), message)
        }
    }

    func testEventRefIsShortStableAndOpaque() {
        let ref = DiagnosticEventRef.make(identifier: "Board review with Marco")
        XCTAssertEqual(ref.count, 8)
        XCTAssertTrue(ref.allSatisfy { $0.isHexDigit })
        XCTAssertEqual(ref, DiagnosticEventRef.make(identifier: "Board review with Marco"))
        XCTAssertNotEqual(ref, DiagnosticEventRef.make(identifier: "Another event"))
        XCTAssertEqual(DiagnosticEventRef.make(identifier: nil), "none")
    }

    func testCategoriesAndLevels() {
        XCTAssertEqual(DiagnosticEvent.calendarRefreshed(durationMs: 1, eventCount: 1, calendarCount: 1).category, .calendar)
        XCTAssertEqual(DiagnosticEvent.notificationsCleared.category, .notifications)
        XCTAssertEqual(DiagnosticEvent.alertShown(kind: .startCard, eventRef: "x").category, .alerts)
        XCTAssertEqual(DiagnosticEvent.contextFile(state: .ready, eventCount: 1).category, .context)
        XCTAssertEqual(DiagnosticEvent.hotkeyRegistrationFailed(shortcut: "⌘⇧C").level, .error)
        XCTAssertEqual(DiagnosticEvent.notificationsScheduled(result: "failed").level, .error)
        XCTAssertEqual(DiagnosticEvent.contextFile(state: .unreadable, eventCount: 0).level, .error)
        XCTAssertEqual(DiagnosticEvent.calendarAccess(granted: true, errorCode: nil).level, .info)
    }

    func testContextStatusMapsToStateWithoutPayload() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(
            CalendarManager.diagnostic(for: .ready(eventCount: 3, generatedAt: now.addingTimeInterval(-3600)), now: now),
            .contextFile(state: .ready, eventCount: 3)
        )
        XCTAssertEqual(
            CalendarManager.diagnostic(for: .ready(eventCount: 3, generatedAt: now.addingTimeInterval(-40 * 3600)), now: now),
            .contextFile(state: .stale, eventCount: 3)
        )
        XCTAssertEqual(CalendarManager.diagnostic(for: .unsupportedVersion(9), now: now), .contextFile(state: .unsupportedVersion, eventCount: 0))
    }

    func testThrottleWritesOncePerInterval() {
        var throttle = DiagnosticThrottle()
        let now = Date()
        XCTAssertTrue(throttle.shouldLog(key: "a", minInterval: 60, now: now))
        XCTAssertFalse(throttle.shouldLog(key: "a", minInterval: 60, now: now.addingTimeInterval(30)))
        XCTAssertTrue(throttle.shouldLog(key: "b", minInterval: 60, now: now.addingTimeInterval(30)))
        XCTAssertTrue(throttle.shouldLog(key: "a", minInterval: 60, now: now.addingTimeInterval(61)))
    }

    func testThrottleStaysBounded() {
        var throttle = DiagnosticThrottle(capacity: 10)
        let now = Date()
        for index in 0..<100 {
            XCTAssertTrue(throttle.shouldLog(key: "k\(index)", minInterval: 60, now: now.addingTimeInterval(Double(index))))
        }
        // The most recent key is still remembered.
        XCTAssertFalse(throttle.shouldLog(key: "k99", minInterval: 60, now: now.addingTimeInterval(100)))
    }

    func testJournalPersistsAndPrunesByAgeAndCount() {
        let url = directory.appendingPathComponent("journal.jsonl")
        let now = Date()
        let log = DiagnosticsLog(journalURL: url)
        log.record(.notificationsCleared, now: now.addingTimeInterval(-20 * 24 * 3600))
        log.record(.notificationSnoozed(minutes: 5), now: now)

        // A new instance reads the file back, without the 20-day-old line.
        let reloaded = DiagnosticsLog(journalURL: url).journal(now: now)
        XCTAssertEqual(reloaded.map(\.message), ["snoozed minutes=5"])
        XCTAssertEqual(reloaded.first?.category, .notifications)

        let many = (0..<(DiagnosticsRetention.journalMaxEntries + 50)).map {
            DiagnosticEntry(date: now.addingTimeInterval(Double($0)), category: .app, level: .info, message: "m\($0)")
        }
        let pruned = DiagnosticsRetention.prune(many, now: now.addingTimeInterval(10_000))
        XCTAssertEqual(pruned.count, DiagnosticsRetention.journalMaxEntries)
        XCTAssertEqual(pruned.last?.message, "m\(DiagnosticsRetention.journalMaxEntries + 49)")
    }

    func testThrottledRecordWritesOnce() {
        let log = DiagnosticsLog(journalURL: directory.appendingPathComponent("journal.jsonl"))
        let now = Date()
        for second in 0..<10 {
            log.record(.notificationsCleared, throttleKey: "cleared", minInterval: 300, now: now.addingTimeInterval(Double(second)))
        }
        XCTAssertEqual(log.journal(now: now.addingTimeInterval(10)).count, 1)
    }

    func testMetricPayloadsOlderThanThirtyDaysArePruned() throws {
        let store = MetricPayloadStore(directory: directory.appendingPathComponent("MetricKit"))
        XCTAssertTrue(store.save(Data(#"{"a":1}"#.utf8), kind: .metrics))
        XCTAssertTrue(store.save(Data(#"{"b":2}"#.utf8), kind: .diagnostics))
        XCTAssertFalse(store.save(Data(), kind: .metrics))

        let saved = store.all()
        XCTAssertEqual(saved.count, 2)
        let oldURL = directory.appendingPathComponent("MetricKit").appendingPathComponent(saved[0].fileName)
        try FileManager.default.setAttributes(
            [.creationDate: Date().addingTimeInterval(-31 * 24 * 3600)],
            ofItemAtPath: oldURL.path
        )

        XCTAssertEqual(store.pruneExpired(), 1)
        XCTAssertEqual(store.all().count, 1)
    }

    func testExpiredPayloadPolicy() {
        let now = Date()
        let fresh = URL(fileURLWithPath: "/tmp/fresh.json")
        let old = URL(fileURLWithPath: "/tmp/old.json")
        let expired = DiagnosticsRetention.expiredPayloads(
            [(fresh, now.addingTimeInterval(-29 * 24 * 3600)), (old, now.addingTimeInterval(-31 * 24 * 3600))],
            now: now
        )
        XCTAssertEqual(expired, [old])
    }

    func testReportHoldsNoMeetingContent() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set("Board review with Marco", forKey: "filterKeywords")
        let manager = CalendarManager(eventStore: FakeCalendarEventStore(), preferencesStore: defaults)
        manager.filterKeywords = "Board review with Marco"
        manager.worldClockZones = ["Europe/Rome", "America/New_York"]

        let log = DiagnosticsLog(journalURL: directory.appendingPathComponent("journal.jsonl"))
        for event in everyEvent() { log.record(event) }
        let payloads = MetricPayloadStore(directory: directory.appendingPathComponent("MetricKit"))
        payloads.save(Data(#"{"crashDiagnostics":[]}"#.utf8), kind: .diagnostics)

        let report = DiagnosticsExporter.makeReport(
            calendarManager: manager,
            notificationAuthorization: "authorized",
            pendingNotificationCount: 7,
            log: log,
            payloadStore: payloads
        )
        let data = try report.jsonData()
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        for value in sensitive {
            XCTAssertFalse(text.localizedCaseInsensitiveContains(value), "report leaks \(value)")
        }

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["formatVersion"] as? Int, 1)
        XCTAssertEqual(object["pendingNotificationCount"] as? Int, 7)
        XCTAssertEqual((object["journal"] as? [Any])?.count, everyEvent().count)
        XCTAssertEqual((object["metricKit"] as? [Any])?.count, 1)
        let settings = try XCTUnwrap(object["settings"] as? [String: Any])
        XCTAssertEqual(settings["worldClockCount"] as? Int, 2)
        XCTAssertNil(settings["filterKeywords"])

        let url = try DiagnosticsExporter.write(report, to: directory.appendingPathComponent("Exports"))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Peek-diagnostics-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testFileNameUsesLocalMinute() {
        let date = Date(timeIntervalSince1970: 1_795_558_500) // 2026-11-24 22:15 UTC
        XCTAssertEqual(
            DiagnosticsReport.fileName(for: date, timeZone: TimeZone(identifier: "Europe/Rome")!),
            "Peek-diagnostics-2026-11-24-2315.json"
        )
    }
}
