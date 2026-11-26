import XCTest
import EventKit
import UserNotifications
@testable import Peek

/// PEEK-271 and PEEK-272: alerts across sleep, time zone, DST and day changes,
/// the 64-request limit and duplicate events across calendars.
final class AlertTimingTests: XCTestCase {
    private let rome = TimeZone(identifier: "Europe/Rome")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)!
    }

    private func instant(of components: DateComponents, readIn zone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: components)
    }

    // MARK: - Time zone

    func testTriggerComponentsKeepTheInstantAfterATimeZoneChange() {
        let fireDate = date("2026-12-03T09:45:00+01:00")
        let components = NotificationPlanner.triggerComponents(for: fireDate, timeZone: rome)

        XCTAssertEqual(components.timeZone, rome)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 45)
        // Read on a Mac now set to New York, the components still mean 09:45 in
        // Rome (03:45 in New York), not 09:45 in New York.
        XCTAssertEqual(instant(of: components, readIn: newYork), fireDate)
    }

    func testTriggerFiresAtTheInstantNotTheWallClockTime() throws {
        let fireDate = Date().addingTimeInterval(3600)
        let components = NotificationPlanner.triggerComponents(for: fireDate, timeZone: newYork)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let next = try XCTUnwrap(trigger.nextTriggerDate())
        XCTAssertEqual(next.timeIntervalSince1970, fireDate.timeIntervalSince1970.rounded(.down), accuracy: 1)
    }

    func testScheduleSignatureChangesWithTheTimeZone() {
        let events = ["event-a", "event-b"]
        XCTAssertNotEqual(
            NotificationContentSignature.schedule(eventSignatures: events, timeZone: rome),
            NotificationContentSignature.schedule(eventSignatures: events, timeZone: newYork)
        )
        XCTAssertEqual(
            NotificationContentSignature.schedule(eventSignatures: events, timeZone: rome),
            NotificationContentSignature.schedule(eventSignatures: events, timeZone: rome)
        )
    }

    // MARK: - DST and midnight

    func testEventAcrossTheSpringForwardChange() {
        // On 2027-03-28 Rome jumps from 02:00 CET to 03:00 CEST. A meeting at
        // 03:10 CEST with a 15-minute lead is due at 01:55 CET, 15 real minutes
        // earlier, not at a 02:55 that does not exist.
        let start = date("2027-03-28T03:10:00+02:00")
        let now = date("2027-03-27T22:00:00+01:00")
        let plan = NotificationPlanner.plan(
            [NotificationPlanCandidate(eventID: "dst", startDate: start, isMeeting: true)],
            leadTime: 15 * 60,
            now: now
        )
        let entry = try? XCTUnwrap(plan.first)
        XCTAssertEqual(entry?.fireDate, start.addingTimeInterval(-15 * 60))

        let components = NotificationPlanner.triggerComponents(for: start.addingTimeInterval(-15 * 60), timeZone: rome)
        XCTAssertEqual(components.hour, 1)
        XCTAssertEqual(components.minute, 55)
        XCTAssertEqual(instant(of: components, readIn: rome), start.addingTimeInterval(-15 * 60))
    }

    func testEventAcrossMidnight() {
        let start = date("2026-12-01T00:05:00+01:00")
        let fireDate = start.addingTimeInterval(-15 * 60)
        let components = NotificationPlanner.triggerComponents(for: fireDate, timeZone: rome)
        XCTAssertEqual(components.day, 30)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 50)
        XCTAssertEqual(instant(of: components, readIn: rome), fireDate)
    }

    // MARK: - Limit

    func testHundredEventsProduceTheSixtyNearest() {
        let now = date("2026-12-01T08:00:00+01:00")
        // Shuffled so the plan has to sort by fire time.
        let candidates = (1...100).shuffled().map {
            NotificationPlanCandidate(
                eventID: "event-\($0)",
                startDate: now.addingTimeInterval(TimeInterval($0) * 3600),
                isMeeting: false
            )
        }
        let plan = NotificationPlanner.plan(candidates, leadTime: 15 * 60, now: now)

        XCTAssertEqual(NotificationPlanner.eventLimit, 60)
        XCTAssertEqual(plan.count, 60)
        XCTAssertEqual(plan.map(\.eventID), (1...60).map { "event-\($0)" })
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    func testPlanSkipsPastStartsAndPastLeadTimes() {
        let now = date("2026-12-01T08:00:00+01:00")
        let plan = NotificationPlanner.plan(
            [
                NotificationPlanCandidate(eventID: "started", startDate: now.addingTimeInterval(-60), isMeeting: true),
                NotificationPlanCandidate(eventID: "too-close", startDate: now.addingTimeInterval(5 * 60), isMeeting: true),
                NotificationPlanCandidate(eventID: "ok", startDate: now.addingTimeInterval(30 * 60), isMeeting: true)
            ],
            leadTime: 15 * 60,
            now: now
        )
        XCTAssertEqual(plan.map(\.eventID), ["ok"])
    }

    func testRecurringOccurrencesGetTheirOwnIdentifiers() {
        let now = date("2026-12-01T08:00:00+01:00")
        let plan = NotificationPlanner.plan(
            (1...3).map {
                NotificationPlanCandidate(
                    eventID: "standup",
                    startDate: now.addingTimeInterval(TimeInterval($0) * 86_400),
                    isMeeting: true
                )
            },
            leadTime: 5 * 60,
            now: now
        )
        XCTAssertEqual(plan.count, 3)
        XCTAssertEqual(Set(plan.map(\.identifier)).count, 3)
        XCTAssertTrue(plan.allSatisfy { $0.identifier.hasPrefix(NotificationPlanner.identifierPrefix) })
    }

    func testOnlyMeetingsAreTimeSensitive() {
        let now = date("2026-12-01T08:00:00+01:00")
        let plan = NotificationPlanner.plan(
            [
                NotificationPlanCandidate(eventID: "meeting", startDate: now.addingTimeInterval(3600), isMeeting: true),
                NotificationPlanCandidate(eventID: "focus", startDate: now.addingTimeInterval(7200), isMeeting: false)
            ],
            leadTime: 15 * 60,
            now: now
        )
        XCTAssertEqual(plan.map(\.isTimeSensitive), [true, false])
    }

    // MARK: - Wake

    func testStartAlertTimingAfterAWake() {
        XCTAssertEqual(LateStartPolicy.timing(secondsSinceStart: -1), .notYet)
        XCTAssertEqual(LateStartPolicy.timing(secondsSinceStart: 0), .startingNow)
        XCTAssertEqual(LateStartPolicy.timing(secondsSinceStart: 59), .startingNow)
        XCTAssertEqual(LateStartPolicy.timing(secondsSinceStart: 60), .startedMinutesAgo(1))
        XCTAssertEqual(LateStartPolicy.timing(secondsSinceStart: 3 * 60 + 20), .startedMinutesAgo(3))
        XCTAssertEqual(LateStartPolicy.timing(secondsSinceStart: 300), .startedMinutesAgo(5))
        XCTAssertEqual(LateStartPolicy.timing(secondsSinceStart: 301), .tooLate)
    }

    func testSnoozeThatRunsOutDuringSleepIsDueAtTheWake() {
        let snoozedAt = date("2026-12-01T10:00:00+01:00")
        let snooze = PendingSnooze(eventKey: "e", presentation: .hud, snoozedAt: snoozedAt)
        XCTAssertEqual(snooze.dueAt, snoozedAt.addingTimeInterval(300))
        XCTAssertFalse(snooze.isDue(now: snoozedAt.addingTimeInterval(290)))
        // The lid closed for 20 minutes: the wake finds the snooze overdue.
        XCTAssertTrue(snooze.isDue(now: snoozedAt.addingTimeInterval(20 * 60)))

        let fullScreen = PendingSnooze(eventKey: "e", presentation: .fullScreen, snoozedAt: snoozedAt)
        XCTAssertEqual(fullScreen.dueAt, snoozedAt.addingTimeInterval(60))
    }

    func testDeliveredRemindersGoStaleFiveMinutesAfterTheStart() {
        let start = date("2026-12-01T10:00:00+01:00")
        XCTAssertFalse(NotificationPlanner.isStale(eventStart: start, now: start.addingTimeInterval(-600)))
        XCTAssertFalse(NotificationPlanner.isStale(eventStart: start, now: start.addingTimeInterval(300)))
        XCTAssertTrue(NotificationPlanner.isStale(eventStart: start, now: start.addingTimeInterval(301)))
    }

    // MARK: - Duplicates

    private struct Copy: Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let link: String?
        let alerts: Bool
        let rank: Int
    }

    private func deduplicate(_ copies: [Copy]) -> [String] {
        EventDeduplicator.deduplicate(
            copies,
            key: { EventDeduplicator.key(title: $0.title, start: $0.start, end: $0.end, link: $0.link) },
            alerts: \.alerts,
            calendarRank: \.rank
        ).map(\.id)
    }

    func testIdenticalEventsOnTwoCalendarsBecomeOne() {
        let start = date("2026-12-01T10:00:00+01:00")
        let end = start.addingTimeInterval(1800)
        let link = "https://zoom.us/j/123"
        XCTAssertEqual(
            deduplicate([
                Copy(id: "work", title: "Weekly sync", start: start, end: end, link: link, alerts: true, rank: 0),
                Copy(id: "shared", title: "  weekly   SYNC ", start: start, end: end, link: link, alerts: true, rank: 1)
            ]),
            ["work"]
        )
    }

    func testDuplicatePrefersTheCalendarThatAlerts() {
        let start = date("2026-12-01T10:00:00+01:00")
        let end = start.addingTimeInterval(1800)
        XCTAssertEqual(
            deduplicate([
                Copy(id: "badge-only", title: "Sync", start: start, end: end, link: nil, alerts: false, rank: 0),
                Copy(id: "alerting", title: "Sync", start: start, end: end, link: nil, alerts: true, rank: 1)
            ]),
            ["alerting"]
        )
    }

    func testDifferentLinksOrTimesStaySeparate() {
        let start = date("2026-12-01T10:00:00+01:00")
        let end = start.addingTimeInterval(1800)
        XCTAssertEqual(
            deduplicate([
                Copy(id: "a", title: "Sync", start: start, end: end, link: "https://zoom.us/j/1", alerts: true, rank: 0),
                Copy(id: "b", title: "Sync", start: start, end: end, link: "https://zoom.us/j/2", alerts: true, rank: 1),
                Copy(id: "c", title: "Sync", start: start, end: end.addingTimeInterval(60), link: "https://zoom.us/j/1", alerts: true, rank: 2)
            ]),
            ["a", "b", "c"]
        )
    }

    func testCalendarManagerShowsADuplicatedMeetingOnce() {
        let store = FakeCalendarEventStore()
        let work = store.addCalendar(title: "Work")
        let shared = store.addCalendar(title: "Shared")
        let start = Date().addingTimeInterval(600)
        store.addEvent(title: "Board review", startDate: start, endDate: start.addingTimeInterval(3600), calendar: work)
        store.addEvent(title: "Board review", startDate: start, endDate: start.addingTimeInterval(3600), calendar: shared)
        store.addEvent(title: "Lunch", startDate: start.addingTimeInterval(7200), endDate: start.addingTimeInterval(9000), calendar: shared)

        let suite = "com.peek.app.tests.\(UUID().uuidString)"
        defer { TestDefaults.remove(suite) }
        let manager = CalendarManager(eventStore: store, preferencesStore: UserDefaults(suiteName: suite)!)
        manager.hasCalendarAccess = true

        let fetched = expectation(description: "fetch completed")
        manager.fetchNextEvent { _ in fetched.fulfill() }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(manager.upcomingEvents.map(\.title), ["Board review", "Lunch"])
        XCTAssertEqual(manager.upcomingEvents.first?.calendar?.calendarIdentifier, work.calendarIdentifier)
    }
}
