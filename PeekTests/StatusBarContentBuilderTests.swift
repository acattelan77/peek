import XCTest
import AppKit
@testable import Peek

/// The five menu bar states of the Peek 2.0 mockup.
final class StatusBarContentBuilderTests: XCTestCase {
    private let locale = Locale(identifier: "en_GB")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    /// 2026-11-23 14:36 UTC, the time in the mockup.
    private let now = Date(timeIntervalSince1970: 1_795_444_560)

    private func make(
        _ title: String = "Quarterly review",
        in seconds: TimeInterval,
        provider: String? = nil,
        mode: StatusBarDisplayMode = .timeUntil
    ) -> StatusBarContent {
        StatusBarContentBuilder.make(
            eventTitle: title,
            startDate: now.addingTimeInterval(seconds),
            joinProvider: provider,
            mode: mode,
            now: now,
            calendar: calendar,
            locale: locale
        )
    }

    func testCalmShowsTitleAndStartTime() {
        let content = make(in: 24 * 60)
        XCTAssertEqual(content.title, "Quarterly review · 15:00")
        XCTAssertEqual(content.phase, .calm)
        XCTAssertEqual(content.urgency, .normal)
    }

    func testCalmOnAnotherDayNamesTheDay() {
        let content = make(in: 24 * 3600)
        XCTAssertEqual(content.phase, .calm)
        XCTAssertTrue(content.title.hasPrefix("Quarterly review · "))
        XCTAssertNotEqual(content.title, "Quarterly review · 14:36")
    }

    func testSoonCountsDownInMinutes() {
        let content = make(in: 5 * 60 + 30)
        XCTAssertEqual(content.title, "Quarterly review · 6 min")
        XCTAssertEqual(content.phase, .soon)
        XCTAssertTrue(content.phase.isFilled)
    }

    func testSoonShowsStartTimeInClockMode() {
        let content = make(in: 6 * 60, mode: .actualTime)
        XCTAssertEqual(content.title, "Quarterly review · 14:42")
        XCTAssertEqual(content.phase, .soon)
    }

    func testNowWithLinkInvitesToJoin() {
        let content = make(in: 60, provider: "Zoom")
        XCTAssertEqual(content.title, "Join now · Zoom")
        XCTAssertEqual(content.phase, .now)
        XCTAssertEqual(content.urgency, .critical)
    }

    func testNowWithoutLinkKeepsTheTitle() {
        let content = make(in: -90)
        XCTAssertEqual(content.title, "Quarterly review · now")
        XCTAssertEqual(content.phase, .now)
    }

    func testInProgressShowsMinutesLeft() {
        let content = StatusBarContentBuilder.inProgress(title: "Standup", endDate: now.addingTimeInterval(17 * 60 + 10), now: now)
        XCTAssertEqual(content.title, "18 min left")
        XCTAssertEqual(content.phase, .inProgress)
        XCTAssertFalse(content.phase.isFilled)
        XCTAssertEqual(content.tooltip, "Standup · 18 min left")
    }

    func testInProgressOverAnHour() {
        let content = StatusBarContentBuilder.inProgress(title: "Workshop", endDate: now.addingTimeInterval(65 * 60), now: now)
        XCTAssertEqual(content.title, "1h 5m left")
    }

    func testInProgressYieldsToAnApproachingMeeting() {
        XCTAssertTrue(StatusBarContentBuilder.showsInProgress(nextPhase: .calm, hasOngoingMeeting: true))
        XCTAssertTrue(StatusBarContentBuilder.showsInProgress(nextPhase: nil, hasOngoingMeeting: true))
        XCTAssertFalse(StatusBarContentBuilder.showsInProgress(nextPhase: .soon, hasOngoingMeeting: true))
        XCTAssertFalse(StatusBarContentBuilder.showsInProgress(nextPhase: .now, hasOngoingMeeting: true))
        XCTAssertFalse(StatusBarContentBuilder.showsInProgress(nextPhase: .calm, hasOngoingMeeting: false))
    }

    func testLongTitleIsShortenedAndKeptInTooltip() {
        let content = make("A very long calendar event title", in: 30 * 60)
        XCTAssertTrue(content.title.hasPrefix("A very long calendar eve…"))
        XCTAssertEqual(content.tooltip, "A very long calendar event title · 15:06")
    }

    func testPillsOnlyForSoonAndNow() {
        XCTAssertNotNil(StatusItemRenderer.pillColors(for: .soon))
        XCTAssertNotNil(StatusItemRenderer.pillColors(for: .now))
        XCTAssertNil(StatusItemRenderer.pillColors(for: .calm))
        XCTAssertNil(StatusItemRenderer.pillColors(for: .inProgress))
    }

    func testPillImageIsWiderWithText() throws {
        let glyph = NSImage(size: NSSize(width: 16, height: 16))
        let iconOnly = try XCTUnwrap(StatusItemRenderer.pillImage(glyph: glyph, title: nil, phase: .soon, barThickness: 24))
        let withText = try XCTUnwrap(StatusItemRenderer.pillImage(glyph: glyph, title: "Review · 6 min", phase: .soon, barThickness: 24))
        XCTAssertGreaterThan(withText.size.width, iconOnly.size.width)
        XCTAssertEqual(iconOnly.size.height, 20)
        XCTAssertFalse(withText.isTemplate)
    }
}

final class AlertLadderTests: XCTestCase {
    func testSoonCardIsDueInTheLastTwoMinutes() {
        XCTAssertFalse(AlertLadder.isSoonCardDue(secondsUntilStart: 121))
        XCTAssertTrue(AlertLadder.isSoonCardDue(secondsUntilStart: 120))
        XCTAssertTrue(AlertLadder.isSoonCardDue(secondsUntilStart: 1))
        XCTAssertFalse(AlertLadder.isSoonCardDue(secondsUntilStart: 0))
    }

    func testInterruptOnlyForMeetingsSkipsPlainEvents() {
        XCTAssertFalse(AlertLadder.interrupts(interruptOnlyForMeetings: true, hasJoinLink: false, hasAttendees: false))
        XCTAssertTrue(AlertLadder.interrupts(interruptOnlyForMeetings: true, hasJoinLink: true, hasAttendees: false))
        XCTAssertTrue(AlertLadder.interrupts(interruptOnlyForMeetings: true, hasJoinLink: false, hasAttendees: true))
        XCTAssertTrue(AlertLadder.interrupts(interruptOnlyForMeetings: false, hasJoinLink: false, hasAttendees: false))
    }

    func testBadgeOnlyCalendarsNeverAlert() {
        XCTAssertFalse(AlertLadder.alerts(calendarID: "personal", badgeOnlyCalendarIDs: ["personal"]))
        XCTAssertTrue(AlertLadder.alerts(calendarID: "work", badgeOnlyCalendarIDs: ["personal"]))
        XCTAssertTrue(AlertLadder.alerts(calendarID: nil, badgeOnlyCalendarIDs: ["personal"]))
    }

    func testStartLevelMapsToStartAlertStyle() {
        for style in StartAlertStyle.allCases {
            XCTAssertEqual(AlertLevel(style).startAlertStyle, style)
        }
    }

    func testShowOptionMapsToModeAndSpacePolicy() {
        XCTAssertEqual(MenuBarShowOption(mode: .timeUntil, spacePolicy: .automatic), .countdown)
        XCTAssertEqual(MenuBarShowOption(mode: .actualTime, spacePolicy: .alwaysShowText), .clock)
        XCTAssertEqual(MenuBarShowOption(mode: .actualTime, spacePolicy: .alwaysShowIcon), .iconOnly)

        let iconOnly = MenuBarShowOption.iconOnly.apply(currentPolicy: .automatic)
        XCTAssertNil(iconOnly.mode)
        XCTAssertEqual(iconOnly.policy, .alwaysShowIcon)

        let countdown = MenuBarShowOption.countdown.apply(currentPolicy: .alwaysShowIcon)
        XCTAssertEqual(countdown.mode, .timeUntil)
        XCTAssertEqual(countdown.policy, .automatic)

        let clock = MenuBarShowOption.clock.apply(currentPolicy: .alwaysShowText)
        XCTAssertEqual(clock.mode, .actualTime)
        XCTAssertEqual(clock.policy, .alwaysShowText)
    }
}
