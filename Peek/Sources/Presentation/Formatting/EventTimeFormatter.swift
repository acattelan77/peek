import Foundation

enum TimeUntilComponents: Equatable {
    case now
    case minutes(Int)
    case hoursMinutes(Int, Int)
}

struct EventTimeFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.timeStyle = .short
        return formatter
    }()

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    static func timeRangeText(start: Date, end: Date) -> String {
        let dateText = compactDateFormatter.string(from: start)
        let startTime = timeFormatter.string(from: start)
        let endTime = timeFormatter.string(from: end)
        let format = NSLocalizedString("%@ • %@ - %@", comment: "Event time range: date • start - end")
        return String(format: format, dateText, startTime, endTime)
    }

    static func compactDateText(for date: Date) -> String {
        compactDateFormatter.string(from: date)
    }

    /// Minutes remaining, rounded up while time remains; zero at or after start.
    /// Shared by the menu-bar label and the popover so they cannot disagree
    /// by one minute solely because of fractional seconds.
    static func roundedUpMinutes(until target: Date, now: Date) -> Int {
        let seconds = max(0, target.timeIntervalSince(now))
        return Int((seconds / 60).rounded(.up))
    }

    static func timeUntilComponents(target: Date, now: Date) -> TimeUntilComponents {
        let totalMinutes = roundedUpMinutes(until: target, now: now)
        if totalMinutes == 0 { return .now }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return .hoursMinutes(hours, minutes) }
        return .minutes(minutes)
    }

    /// Compact countdown in the design voice: "in 12 min", "in 3 hr", "starting now".
    static func countdownText(target: Date, now: Date = Date()) -> String {
        switch timeUntilComponents(target: target, now: now) {
        case .hoursMinutes(let hours, _):
            return String(format: NSLocalizedString("in %d hr", comment: "Countdown: hours until event"), hours)
        case .minutes(let minutes):
            return String(format: NSLocalizedString("in %d min", comment: "Countdown: minutes until event"), minutes)
        case .now:
            return NSLocalizedString("starting now", comment: "Countdown: event starting now")
        }
    }

    static func timeUntilText(target: Date, now: Date = Date()) -> String {
        switch timeUntilComponents(target: target, now: now) {
        case .hoursMinutes(let hours, let minutes):
            let format = NSLocalizedString("Starts in %dh %dm", comment: "Time until event with hours and minutes")
            return String(format: format, hours, minutes)
        case .minutes(let minutes):
            let format = NSLocalizedString("Starts in %dm", comment: "Time until event with minutes")
            return String(format: format, minutes)
        case .now:
            return NSLocalizedString("Starting now", comment: "Time until event when starting now")
        }
    }
}
