import Foundation

struct StatusBarContent: Equatable {
    let title: String
    let tooltip: String?
    let urgency: MeetingUrgency
}

enum StatusBarContentBuilder {
    static func make(
        eventTitle: String?,
        startDate: Date,
        eventCount: Int,
        mode: StatusBarDisplayMode,
        showCount: Bool,
        now: Date = Date()
    ) -> StatusBarContent {
        let minutesUntil = Int(startDate.timeIntervalSince(now)) / 60
        let urgency = MeetingUrgency.from(minutesUntil: minutesUntil)
        let title = eventTitle ?? NSLocalizedString("Untitled Event", comment: "Fallback event title")

        let maxTitleLength = 20
        let compactTitle = title.count > maxTitleLength
            ? String(title.prefix(maxTitleLength)) + "..."
            : title
        let countSuffix = eventCount > 1 && showCount
            ? String(
                format: NSLocalizedString(" (+%d)", comment: "Suffix showing additional event count"),
                eventCount - 1
            )
            : ""
        let time = timeText(startDate: startDate, mode: mode, now: now)
        let titleFormat = NSLocalizedString("%@ - %@%@", comment: "Status bar title format: time - title (+count)")
        let statusTitle = String(format: titleFormat, time, compactTitle, countSuffix)
        let tooltip = title.count > maxTitleLength
            ? String(
                format: NSLocalizedString("%@ - %@", comment: "Status bar tooltip format: time - title"),
                time,
                title
            )
            : nil

        return StatusBarContent(title: statusTitle, tooltip: tooltip, urgency: urgency)
    }

    private static func timeText(startDate: Date, mode: StatusBarDisplayMode, now: Date) -> String {
        if mode == .actualTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: startDate)
        }

        guard startDate > now else {
            return NSLocalizedString("NOW!", comment: "Status bar label when event is now")
        }

        let interval = startDate.timeIntervalSince(now)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours >= 24 {
            return String(
                format: NSLocalizedString("%dd", comment: "Abbreviated days"),
                hours / 24
            )
        }
        if hours > 0 {
            return String(
                format: NSLocalizedString("%dh %dm", comment: "Abbreviated hours and minutes"),
                hours,
                minutes
            )
        }
        if minutes > 0 {
            return String(
                format: NSLocalizedString("%dm", comment: "Abbreviated minutes"),
                minutes
            )
        }
        return NSLocalizedString("NOW!", comment: "Status bar label when event is now")
    }
}
