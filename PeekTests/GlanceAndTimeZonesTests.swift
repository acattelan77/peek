import XCTest
@testable import Peek

final class JoinTargetPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    private func meeting(startsIn minutes: Double, lasts length: Double = 30, link: Bool = true) -> JoinCandidate {
        let start = now.addingTimeInterval(minutes * 60)
        return JoinCandidate(start: start, end: start.addingTimeInterval(length * 60), hasJoinLink: link)
    }

    func testPicksNextMeetingWithALink() {
        let candidates = [meeting(startsIn: 5, link: false), meeting(startsIn: 10), meeting(startsIn: 20)]
        XCTAssertEqual(JoinTargetPolicy.pick(candidates, now: now), 1)
    }

    func testIgnoresMeetingsTooFarAhead() {
        XCTAssertNil(JoinTargetPolicy.pick([meeting(startsIn: 45)], now: now))
    }

    func testPrefersTheMeetingYouAreLateFor() {
        let candidates = [meeting(startsIn: 10), meeting(startsIn: -8)]
        XCTAssertEqual(JoinTargetPolicy.pick(candidates, now: now), 1)
    }

    func testImminentMeetingBeatsOneAlreadyRunning() {
        let candidates = [meeting(startsIn: -5), meeting(startsIn: 1)]
        XCTAssertEqual(JoinTargetPolicy.pick(candidates, now: now), 1)
    }

    func testFallsBackToALongRunningMeeting() {
        let candidates = [meeting(startsIn: -40, lasts: 60)]
        XCTAssertEqual(JoinTargetPolicy.pick(candidates, now: now), 0)
    }

    func testEndedMeetingsAndNoLinksGiveNothing() {
        XCTAssertNil(JoinTargetPolicy.pick([meeting(startsIn: -40, lasts: 30), meeting(startsIn: 5, link: false)], now: now))
    }
}

final class StatusBarEventChooserTests: XCTestCase {
    func testFollowsNextEventByDefault() {
        let picked = StatusBarEventChooser.pick(next: "lunch", upcoming: ["lunch", "call"], onlyMeetings: false, hasJoinLink: { $0 == "call" })
        XCTAssertEqual(picked, "lunch")
    }

    func testSkipsEventsWithoutLinkWhenAsked() {
        let picked = StatusBarEventChooser.pick(next: "lunch", upcoming: ["lunch", "call"], onlyMeetings: true, hasJoinLink: { $0 == "call" })
        XCTAssertEqual(picked, "call")
        XCTAssertNil(StatusBarEventChooser.pick(next: "lunch", upcoming: ["lunch"], onlyMeetings: true, hasJoinLink: { _ in false }))
    }

    func testPersonLabelKeepsTitleInTooltip() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let content = StatusBarContentBuilder.make(
            eventTitle: "Marco",
            fullTitle: "Quarterly review",
            startDate: now.addingTimeInterval(8 * 60 + 5),
            eventCount: 1,
            mode: .timeUntil,
            showCount: true,
            now: now
        )
        XCTAssertTrue(content.title.contains("Marco"))
        XCTAssertTrue(content.tooltip?.contains("Quarterly review") ?? false)
    }
}

final class JoinHotkeyTests: XCTestCase {
    private final class Registrar: HotkeyRegistering {
        var registered: (UInt32, UInt32)?
        var unregistered = false
        func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
            registered = (keyCode, modifiers)
            return noErr
        }
        func unregister() { unregistered = true }
    }

    func testOffUnregisters() {
        let registrar = Registrar()
        XCTAssertEqual(GlobalHotkeyCoordinator.apply(JoinHotkeyOption.off, using: registrar), .active)
        XCTAssertTrue(registrar.unregistered)
        XCTAssertNil(registrar.registered)
    }

    func testOptionsAreDistinct() {
        let combos = JoinHotkeyOption.allCases.filter { $0 != .off }.map { "\($0.keyCode)-\($0.modifiers)" }
        XCTAssertEqual(Set(combos).count, combos.count)
        let registrar = Registrar()
        _ = GlobalHotkeyCoordinator.apply(JoinHotkeyOption.ctrlOptionJ, using: registrar)
        XCTAssertEqual(registrar.registered?.0, JoinHotkeyOption.ctrlOptionJ.keyCode)
    }

    func testJoinShortcutsDoNotCollideWithPopoverShortcuts() {
        let popover = Set(HotkeyOption.allCases.map { "\($0.keyCode)-\($0.modifiers)" })
        let join = Set(JoinHotkeyOption.allCases.filter { $0 != .off }.map { "\($0.keyCode)-\($0.modifiers)" })
        XCTAssertTrue(popover.isDisjoint(with: join))
    }
}

final class WorldClockTests: XCTestCase {
    private let locale = Locale(identifier: "en_GB")
    private let rome = TimeZone(identifier: "Europe/Rome")!
    // 2026-11-23 23:30 in Rome (22:30 UTC).
    private let lateEvening = Date(timeIntervalSince1970: 1_795_473_000)

    func testCityNames() {
        XCTAssertEqual(WorldClock.cityName(for: "America/New_York"), "New York")
        XCTAssertEqual(WorldClock.cityName(for: "Asia/Kolkata"), "Kolkata")
        XCTAssertEqual(WorldClock.cityName(for: "UTC"), "UTC")
    }

    func testSanitizedDropsUnknownAndDuplicatesAndCaps() {
        let zones = ["Europe/Dublin", "Not/AZone", "Europe/Dublin"] + WorldClock.suggestedIdentifiers
        let result = WorldClock.sanitized(zones)
        XCTAssertEqual(result.first, "Europe/Dublin")
        XCTAssertFalse(result.contains("Not/AZone"))
        XCTAssertEqual(result.count, WorldClock.maxZones)
        XCTAssertEqual(Set(result).count, result.count)
    }

    func testSuggestedZonesAreAllKnown() {
        for identifier in WorldClock.suggestedIdentifiers {
            XCTAssertNotNil(TimeZone(identifier: identifier), identifier)
        }
    }

    func testEntriesShowLocalTimeAndDayOffset() {
        let entries = WorldClock.entries(
            at: lateEvening,
            zones: ["Europe/Dublin", "Asia/Tokyo", "America/New_York"],
            reference: rome,
            locale: locale
        )
        XCTAssertEqual(entries.map(\.city), ["Dublin", "Tokyo", "New York"])
        XCTAssertEqual(entries[0].time, "22:30")
        XCTAssertEqual(entries[0].dayOffset, 0)
        XCTAssertEqual(entries[1].time, "07:30")
        XCTAssertEqual(entries[1].dayOffset, 1)
        XCTAssertEqual(entries[1].text, "07:30 +1")
        XCTAssertEqual(entries[2].time, "17:30")
        XCTAssertEqual(entries[2].dayOffset, 0)
    }

    func testRangeTextForAMeeting() {
        let start = lateEvening
        let end = start.addingTimeInterval(3600)
        XCTAssertEqual(WorldClock.rangeText(start: start, end: end, in: "Asia/Kolkata", reference: rome, locale: locale), "04:00 – 05:00 +1")
        XCTAssertEqual(WorldClock.rangeText(start: start, end: end, in: "Europe/Dublin", reference: rome, locale: locale), "22:30 – 23:30")
        XCTAssertNil(WorldClock.rangeText(start: start, end: end, in: "Not/AZone", reference: rome, locale: locale))
    }

    func testNegativeDayOffset() {
        // 00:30 in Rome is still the previous day in New York.
        let earlyMorning = lateEvening.addingTimeInterval(3600)
        let entry = WorldClock.entries(at: earlyMorning, zones: ["America/New_York"], reference: rome, locale: locale)[0]
        XCTAssertEqual(entry.dayOffset, -1)
        XCTAssertEqual(entry.text, "18:30 −1")
    }
}
