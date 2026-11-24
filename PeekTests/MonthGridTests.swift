import XCTest
@testable import Peek

final class MonthGridTests: XCTestCase {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testNovember2026StartsOnMondayInEurope() {
        let cal = calendar(firstWeekday: 2)
        let grid = MonthGrid.make(containing: date(2026, 11, 23, in: cal), today: date(2026, 11, 23, hour: 15, in: cal), calendar: cal)

        XCTAssertEqual(grid.weeks.count, 6)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
        // 2026-11-01 is a Sunday, so a Monday-first grid opens on 2026-10-26.
        XCTAssertEqual(grid.days.first?.dayNumber, 26)
        XCTAssertEqual(grid.days.first?.isInMonth, false)
        XCTAssertEqual(grid.weeks[0][6].dayNumber, 1)
        XCTAssertEqual(grid.weeks[0][6].isInMonth, true)
        XCTAssertEqual(grid.interval.start, date(2026, 10, 26, in: cal))
        XCTAssertEqual(grid.interval.end, date(2026, 12, 7, in: cal))
    }

    func testSundayFirstGridOpensOnFirstOfMonth() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthGrid.make(containing: date(2026, 11, 10, in: cal), today: date(2026, 11, 10, in: cal), calendar: cal)

        XCTAssertEqual(grid.days.first?.dayNumber, 1)
        XCTAssertEqual(grid.days.first?.isInMonth, true)
    }

    func testTodayAndPastFlags() {
        let cal = calendar(firstWeekday: 2)
        let grid = MonthGrid.make(containing: date(2026, 11, 23, in: cal), today: date(2026, 11, 23, hour: 15, in: cal), calendar: cal)

        let today = grid.days.filter(\.isToday)
        XCTAssertEqual(today.count, 1)
        XCTAssertEqual(today.first?.dayNumber, 23)
        XCTAssertTrue(grid.days.first { $0.isInMonth && $0.dayNumber == 22 }!.isPast)
        XCTAssertFalse(grid.days.first { $0.isInMonth && $0.dayNumber == 24 }!.isPast)
    }

    func testWeekdaySymbolsFollowFirstWeekday() {
        var cal = calendar(firstWeekday: 2)
        cal.locale = Locale(identifier: "en_US")
        XCTAssertEqual(MonthGrid.weekdaySymbols(calendar: cal), ["M", "T", "W", "T", "F", "S", "S"])
        cal.firstWeekday = 1
        XCTAssertEqual(MonthGrid.weekdaySymbols(calendar: cal).first, "S")
    }

    func testShortWeekdaySymbolsAreUppercaseAndFollowFirstWeekday() {
        var cal = calendar(firstWeekday: 2)
        cal.locale = Locale(identifier: "en_US")
        XCTAssertEqual(MonthGrid.shortWeekdaySymbols(calendar: cal), ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"])
        cal.locale = Locale(identifier: "it_IT")
        XCTAssertEqual(MonthGrid.shortWeekdaySymbols(calendar: cal).first, "LUN")
        cal.firstWeekday = 1
        XCTAssertEqual(MonthGrid.shortWeekdaySymbols(calendar: cal).first, "DOM")
    }

    func testDaysCoveredBySpanningAndMidnightEvents() {
        let cal = calendar(firstWeekday: 2)
        let interval = DateInterval(start: date(2026, 11, 1, in: cal), end: date(2026, 12, 1, in: cal))

        let afternoon = MonthGrid.daysCovered(
            start: date(2026, 11, 10, hour: 14, in: cal),
            end: date(2026, 11, 10, hour: 15, in: cal),
            within: interval,
            calendar: cal
        )
        XCTAssertEqual(afternoon, [date(2026, 11, 10, in: cal)])

        // An all-day event ends at the next midnight and must not mark that day.
        let allDay = MonthGrid.daysCovered(
            start: date(2026, 11, 12, in: cal),
            end: date(2026, 11, 13, in: cal),
            within: interval,
            calendar: cal
        )
        XCTAssertEqual(allDay, [date(2026, 11, 12, in: cal)])

        let threeDays = MonthGrid.daysCovered(
            start: date(2026, 11, 20, hour: 9, in: cal),
            end: date(2026, 11, 22, hour: 18, in: cal),
            within: interval,
            calendar: cal
        )
        XCTAssertEqual(threeDays.count, 3)

        let before = MonthGrid.daysCovered(
            start: date(2026, 10, 20, in: cal),
            end: date(2026, 10, 21, in: cal),
            within: interval,
            calendar: cal
        )
        XCTAssertTrue(before.isEmpty)

        let clamped = MonthGrid.daysCovered(
            start: date(2026, 10, 30, in: cal),
            end: date(2026, 11, 2, hour: 12, in: cal),
            within: interval,
            calendar: cal
        )
        XCTAssertEqual(clamped, [date(2026, 11, 1, in: cal), date(2026, 11, 2, in: cal)])
    }
}
