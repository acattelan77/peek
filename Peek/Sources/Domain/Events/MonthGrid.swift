import Foundation

/// A six-week month grid that starts on the user's first weekday. Pure and
/// calendar-injected so it is testable across locales and time zones.
struct MonthGrid: Equatable {
    struct Day: Hashable {
        let date: Date
        let dayNumber: Int
        let isInMonth: Bool
        let isToday: Bool
        let isPast: Bool
    }

    static let weekCount = 6

    let monthStart: Date
    let weeks: [[Day]]
    /// The interval the grid covers: from its first day's midnight to the
    /// midnight after its last day.
    let interval: DateInterval

    /// Every day the grid shows, first to last.
    var days: [Day] { weeks.flatMap { $0 } }

    static func make(containing date: Date, today: Date = Date(), calendar: Calendar = .current) -> MonthGrid {
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: today)
        let month = calendar.component(.month, from: monthStart)

        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart

        var weeks: [[Day]] = []
        for week in 0..<weekCount {
            var row: [Day] = []
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: week * 7 + offset, to: gridStart) else { continue }
                let start = calendar.startOfDay(for: date)
                row.append(Day(
                    date: start,
                    dayNumber: calendar.component(.day, from: start),
                    isInMonth: calendar.component(.month, from: start) == month,
                    isToday: start == todayStart,
                    isPast: start < todayStart
                ))
            }
            weeks.append(row)
        }

        let gridStartDay = calendar.startOfDay(for: gridStart)
        let gridEnd = calendar.date(byAdding: .day, value: weekCount * 7, to: gridStartDay) ?? gridStartDay
        return MonthGrid(monthStart: monthStart, weeks: weeks, interval: DateInterval(start: gridStartDay, end: gridEnd))
    }

    /// Weekday initials in grid order, starting at the calendar's first weekday.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Short uppercase weekday labels ("MON", "LUN") in grid order, as the
    /// Peek 2.0 month header shows them.
    static func shortWeekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols.map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")).uppercased(with: calendar.locale)
        }
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The start-of-day dates an event occupies inside `interval`. An event
    /// ending exactly at midnight does not mark the next day.
    static func daysCovered(start: Date, end: Date, within interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        let clampedStart = max(start, interval.start)
        let lastMoment = max(clampedStart, min(end, interval.end).addingTimeInterval(-1))
        guard clampedStart < interval.end, end > interval.start || (start == end && start >= interval.start) else {
            return []
        }

        var days: [Date] = []
        var cursor = calendar.startOfDay(for: clampedStart)
        let lastDay = calendar.startOfDay(for: lastMoment)
        while cursor <= lastDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
}
