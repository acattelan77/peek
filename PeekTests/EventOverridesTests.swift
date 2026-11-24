import XCTest
import EventKit
@testable import Peek

/// Per-event mute, hide and ignore (PEEK-273).
final class EventOverridesTests: XCTestCase {
    private struct TestEvent: EventCandidate {
        let candidateStartDate: Date?
        let candidateEndDate: Date?
        let isAllDay: Bool = false
        let candidateTitle: String?
        let candidateNotes: String? = nil
        let currentUserDeclined: Bool = false
        let candidateIdentity: EventIdentity?
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let weekly = "series-weekly"
    private let oneOff = "one-off"

    private func occurrence(_ week: Int, series: String? = nil) -> EventIdentity {
        EventIdentity(
            seriesID: series ?? weekly,
            occurrenceDate: now.addingTimeInterval(TimeInterval(week) * 7 * 86_400 + 3_600),
            isRecurring: true
        )
    }

    private var oneOffIdentity: EventIdentity {
        EventIdentity(seriesID: oneOff, occurrenceDate: now.addingTimeInterval(1_800), isRecurring: false)
    }

    private func event(_ identity: EventIdentity, title: String) -> TestEvent {
        TestEvent(
            candidateStartDate: identity.occurrenceDate,
            candidateEndDate: identity.occurrenceDate.addingTimeInterval(1_800),
            candidateTitle: title,
            candidateIdentity: identity
        )
    }

    // MARK: Occurrence against series

    func testMutingOneOccurrenceLeavesTheNextOneAlerting() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now.addingTimeInterval(5_400))

        XCTAssertEqual(overrides.action(for: occurrence(0)), .mute)
        XCTAssertNil(overrides.action(for: occurrence(1)))
        XCTAssertEqual(overrides.entries.first?.scope, .occurrence)
    }

    func testMutingTheSeriesCoversEveryOccurrence() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: true, title: "Weekly", endDate: now)

        XCTAssertEqual(overrides.action(for: occurrence(0)), .mute)
        XCTAssertEqual(overrides.action(for: occurrence(5)), .mute)
        XCTAssertNil(overrides.action(for: occurrence(0, series: "other")))
        XCTAssertNil(overrides.entries.first?.expiresAt, "A series entry is never pruned")
    }

    func testOneOffEventIgnoresTheSeriesChoice() {
        var overrides = EventOverrides.none
        overrides.set(.hide, for: oneOffIdentity, wholeSeries: true, title: "Lunch", endDate: now.addingTimeInterval(3_600))

        XCTAssertEqual(overrides.entries.first?.scope, .event)
        XCTAssertNotNil(overrides.entries.first?.expiresAt)
        // A one-off event stays matched when it is moved.
        let moved = EventIdentity(seriesID: oneOff, occurrenceDate: now.addingTimeInterval(9_000), isRecurring: false)
        XCTAssertTrue(overrides.isHidden(moved))
    }

    func testHideWinsOverMute() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)
        overrides.set(.hide, for: occurrence(0), wholeSeries: true, title: "Weekly", endDate: now)

        XCTAssertEqual(overrides.action(for: occurrence(0)), .hide)
        XCTAssertTrue(overrides.isSilenced(occurrence(0)))
    }

    func testSettingTheSameScopeReplacesTheEarlierChoice() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)
        overrides.set(.hide, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)

        XCTAssertEqual(overrides.entries.count, 1)
        XCTAssertEqual(overrides.action(for: occurrence(0)), .hide)
    }

    func testRestoreClearsOccurrenceAndSeriesEntries() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)
        overrides.set(.hide, for: occurrence(0), wholeSeries: true, title: "Weekly", endDate: now)
        overrides.set(.mute, for: oneOffIdentity, wholeSeries: false, title: "Lunch", endDate: now)

        overrides.restore(occurrence(0))

        XCTAssertNil(overrides.action(for: occurrence(0)))
        XCTAssertEqual(overrides.action(for: oneOffIdentity), .mute)
    }

    func testRemoveByIDRestoresOneEntry() throws {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)
        overrides.set(.hide, for: oneOffIdentity, wholeSeries: false, title: "Lunch", endDate: now)
        let lunch = try XCTUnwrap(overrides.entries.first { $0.title == "Lunch" })

        overrides.remove(id: lunch.id)

        XCTAssertEqual(overrides.entries.map(\.title), ["Weekly"])
    }

    func testOccurrenceMatchToleratesSubSecondDrift() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)
        let drifted = EventIdentity(
            seriesID: weekly,
            occurrenceDate: occurrence(0).occurrenceDate.addingTimeInterval(0.2),
            isRecurring: true
        )
        XCTAssertEqual(overrides.action(for: drifted), .mute)
    }

    // MARK: Pruning and persistence

    func testPruneDropsEndedEntriesAndKeepsSeries() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Past", endDate: now.addingTimeInterval(-60))
        overrides.set(.mute, for: occurrence(1), wholeSeries: false, title: "Future", endDate: now.addingTimeInterval(86_400))
        overrides.set(.hide, for: occurrence(0, series: "standup"), wholeSeries: true, title: "Standup", endDate: now.addingTimeInterval(-60))

        overrides.prune(now: now)

        XCTAssertEqual(Set(overrides.entries.map(\.title)), ["Future", "Standup"])
    }

    func testEncodingRoundTrips() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)
        overrides.set(.hide, for: oneOffIdentity, wholeSeries: false, title: "Lunch", endDate: now)

        let decoded = EventOverrides.decoded(from: overrides.encoded())

        XCTAssertEqual(decoded, overrides)
        XCTAssertEqual(EventOverrides.decoded(from: nil), .none)
        XCTAssertEqual(EventOverrides.decoded(from: Data("not json".utf8)), .none)
    }

    // MARK: Pipeline

    func testHiddenEventLeavesTheListAndTheMenuBar() {
        var overrides = EventOverrides.none
        overrides.set(.hide, for: occurrence(0), wholeSeries: false, title: "Weekly", endDate: now)
        let hidden = event(occurrence(0), title: "Weekly")
        let next = event(oneOffIdentity, title: "Lunch")
        let later = event(occurrence(1), title: "Weekly")
        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: false, filterKeywords: "", overrides: overrides)

        let result = EventPipeline.filterAndSelect(events: [hidden, next, later], now: now, settings: settings, maxEvents: 5, lateGraceMinutes: 5)

        XCTAssertEqual(result.nextEvent?.candidateTitle, "Lunch")
        XCTAssertEqual(result.upcomingEvents.compactMap(\.candidateIdentity?.occurrenceDate), [oneOffIdentity.occurrenceDate, occurrence(1).occurrenceDate])
        XCTAssertFalse(result.activeEvents.contains { $0.candidateIdentity == occurrence(0) }, "The join shortcut skips hidden events")
        XCTAssertEqual(EventPipeline.visibleEvents([hidden, next], settings: settings).map(\.candidateTitle), ["Lunch"])
    }

    func testMutedEventStaysVisible() {
        var overrides = EventOverrides.none
        overrides.set(.mute, for: occurrence(0), wholeSeries: true, title: "Weekly", endDate: now)
        let muted = event(occurrence(0), title: "Weekly")
        let settings = EventFilterSettings(hideAllDayEvents: false, hideDeclinedEvents: false, filterKeywords: "", overrides: overrides)

        let result = EventPipeline.filterAndSelect(events: [muted], now: now, settings: settings, maxEvents: 5, lateGraceMinutes: 5)

        XCTAssertEqual(result.nextEvent?.candidateTitle, "Weekly")
        XCTAssertEqual(result.activeEvents.count, 1, "The join shortcut still offers muted events")
    }

    func testEventsWithoutIdentityAreNeverHidden() {
        var overrides = EventOverrides.none
        overrides.set(.hide, for: oneOffIdentity, wholeSeries: false, title: "Lunch", endDate: now)
        XCTAssertFalse(overrides.isHidden(nil))
        XCTAssertNil(overrides.action(for: nil))
    }

    // MARK: Ignore

    func testIgnoreSuppressesTheRestOfTheLadder() {
        var history = StartingNowHUDPresentationHistory()
        history.suppress(eventID: "standup", eventEndDate: now.addingTimeInterval(1_800), now: now)

        XCTAssertFalse(history.shouldPresent(eventID: "standup", eventEndDate: now.addingTimeInterval(1_800), now: now.addingTimeInterval(120)))
        XCTAssertTrue(history.shouldPresent(eventID: "other", eventEndDate: now.addingTimeInterval(1_800), now: now))
    }

    // MARK: Preferences list

    func testPreferencesSubtitleNamesActionAndScope() {
        var overrides = EventOverrides.none
        overrides.set(.hide, for: occurrence(0), wholeSeries: true, title: "Weekly", endDate: now)
        overrides.set(.mute, for: oneOffIdentity, wholeSeries: false, title: "Lunch", endDate: now)

        let series = overrides.entries.first { $0.scope == .series }!
        let single = overrides.entries.first { $0.scope == .event }!

        let seriesText = EventOverrideDescription.subtitle(for: series)
        XCTAssertTrue(seriesText.contains(NSLocalizedString("Hidden", comment: "")), seriesText)
        XCTAssertTrue(seriesText.contains(NSLocalizedString("every event in the series", comment: "")), seriesText)
        XCTAssertTrue(EventOverrideDescription.subtitle(for: single).hasPrefix(NSLocalizedString("Alerts muted", comment: "")))
        XCTAssertEqual(overrides.sortedForDisplay.first?.title, "Weekly", "Series entries sort first")
    }

    func testItalianLabelsFollowThePlan() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "it", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(bundle.localizedString(forKey: "Mute Alerts", value: nil, table: nil), "Silenzia avvisi")
        XCTAssertEqual(bundle.localizedString(forKey: "Hide Event", value: nil, table: nil), "Nascondi evento")
        XCTAssertEqual(bundle.localizedString(forKey: "Ignore", value: nil, table: nil), "Ignora")
        XCTAssertEqual(bundle.localizedString(forKey: "This Event Only", value: nil, table: nil), "Solo questa")
    }
}

/// CalendarManager applies and persists per-event choices (PEEK-273).
final class EventOverridesCalendarManagerTests: XCTestCase {
    private var eventStore: FakeCalendarEventStore!
    private var suiteName: String!
    private var preferences: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.peek.app.tests.overrides.\(UUID().uuidString)"
        preferences = UserDefaults(suiteName: suiteName)!
        eventStore = FakeCalendarEventStore()
    }

    override func tearDown() {
        UserDefaults().removeSuite(named: suiteName)
        eventStore = nil
        preferences = nil
        super.tearDown()
    }

    private func fetch(_ manager: CalendarManager) {
        let done = expectation(description: "fetch")
        manager.hasCalendarAccess = true
        manager.fetchNextEvent { _ in done.fulfill() }
        waitForExpectations(timeout: 1)
    }

    func testHideMuteAndRestoreThroughTheManager() throws {
        let calendar = eventStore.addCalendar(title: "Work")
        let now = Date()
        let standup = eventStore.addEvent(title: "Standup", startDate: now.addingTimeInterval(600), endDate: now.addingTimeInterval(1_200), calendar: calendar)
        let review = eventStore.addEvent(title: "Review", startDate: now.addingTimeInterval(3_600), endDate: now.addingTimeInterval(5_400), calendar: calendar)
        try XCTSkipIf(standup.candidateIdentity == nil || review.candidateIdentity == nil, "Unsaved EKEvents have no identifier on this OS")
        try XCTSkipIf(standup.candidateIdentity?.seriesID == review.candidateIdentity?.seriesID, "Unsaved EKEvents share an identifier on this OS")

        let manager = CalendarManager(eventStore: eventStore, preferencesStore: preferences)
        XCTAssertTrue(manager.alerts(for: standup))

        manager.setOverride(.mute, for: standup, wholeSeries: false)
        XCTAssertFalse(manager.alerts(for: standup), "A muted event never notifies or interrupts")
        fetch(manager)
        XCTAssertEqual(manager.upcomingEvents.map(\.title), ["Standup", "Review"], "A muted event stays visible")

        manager.setOverride(.hide, for: review, wholeSeries: false)
        fetch(manager)
        XCTAssertEqual(manager.upcomingEvents.map(\.title), ["Standup"])

        // Persisted across launches.
        let relaunched = CalendarManager(eventStore: eventStore, preferencesStore: preferences)
        XCTAssertEqual(relaunched.overrideAction(for: standup), .mute)
        XCTAssertEqual(relaunched.overrideAction(for: review), .hide)

        relaunched.restoreEvent(review)
        fetch(relaunched)
        XCTAssertEqual(relaunched.upcomingEvents.map(\.title), ["Standup", "Review"])
    }

    func testMuteCombinesWithBadgeOnlyCalendars() throws {
        let badgeOnly = eventStore.addCalendar(title: "Family")
        let now = Date()
        let dinner = eventStore.addEvent(title: "Dinner", startDate: now.addingTimeInterval(600), endDate: now.addingTimeInterval(1_200), calendar: badgeOnly)
        try XCTSkipIf(dinner.candidateIdentity == nil, "Unsaved EKEvents have no identifier on this OS")

        let manager = CalendarManager(eventStore: eventStore, preferencesStore: preferences)
        manager.toggleBadgeOnly(badgeOnly.calendarIdentifier)
        XCTAssertFalse(manager.alerts(for: dinner))

        manager.setOverride(.mute, for: dinner, wholeSeries: false)
        manager.toggleBadgeOnly(badgeOnly.calendarIdentifier)
        XCTAssertFalse(manager.alerts(for: dinner), "Leaving badge-only keeps the event muted")

        manager.restoreEvent(dinner)
        XCTAssertTrue(manager.alerts(for: dinner))
    }

    func testEndedEntriesArePrunedAtLaunch() {
        var overrides = EventOverrides.none
        let past = EventIdentity(seriesID: "old", occurrenceDate: Date().addingTimeInterval(-7_200), isRecurring: false)
        overrides.set(.mute, for: past, wholeSeries: false, title: "Old", endDate: Date().addingTimeInterval(-3_600))
        preferences.set(overrides.encoded(), forKey: "eventOverrides")

        let manager = CalendarManager(eventStore: eventStore, preferencesStore: preferences)

        XCTAssertTrue(manager.eventOverrides.isEmpty)
    }
}
