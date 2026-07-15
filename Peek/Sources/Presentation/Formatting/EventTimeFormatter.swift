import Foundation

enum TimeUntilComponents: Equatable {
    case now
    case minutes(Int)
    case hoursMinutes(Int, Int)
}

struct EventTimeFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
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

    static func timeUntilComponents(target: Date, now: Date) -> TimeUntilComponents {
        let interval = max(0, target.timeIntervalSince(now))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return .hoursMinutes(hours, minutes)
        }
        if minutes > 0 {
            return .minutes(minutes)
        }
        return .now
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
