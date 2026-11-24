import Foundation

/// The menu bar states of the Peek 2.0 mockup ("Un solo elemento, cinque
/// stati"). Icon only is a presentation of any phase, decided by the space
/// policy or the Show setting, so it is not a phase.
enum MenuBarPhase: Equatable {
    /// More than 10 minutes away: "Quarterly review · 15:00".
    case calm
    /// 10 to 2 minutes away: amber pill, "Quarterly review · 6 min".
    case soon
    /// Under 2 minutes, or just started: red pill, "Join now · Zoom".
    case now
    /// A meeting is running and nothing else is close: "18 min left".
    case inProgress

    init(urgency: MeetingUrgency) {
        switch urgency {
        case .normal: self = .calm
        case .urgent: self = .soon
        case .critical: self = .now
        }
    }

    /// Soon and now draw a filled pill when urgency colors are on.
    var isFilled: Bool {
        self == .soon || self == .now
    }
}

struct StatusBarContent: Equatable {
    let title: String
    let tooltip: String?
    let urgency: MeetingUrgency
    var phase: MenuBarPhase = .calm
}

enum StatusBarContentBuilder {
    static let maxTitleLength = 24

    /// Content for the next event: calm, soon or now.
    ///
    /// - Parameter joinProvider: the provider label ("Zoom") when the event
    ///   has a join link; the now state then reads "Join now · Zoom".
    static func make(
        eventTitle: String?,
        fullTitle: String? = nil,
        startDate: Date,
        joinProvider: String? = nil,
        mode: StatusBarDisplayMode,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> StatusBarContent {
        let minutesUntil = Int(startDate.timeIntervalSince(now)) / 60
        let urgency = MeetingUrgency.from(minutesUntil: minutesUntil)
        let phase = MenuBarPhase(urgency: urgency)
        let title = eventTitle ?? NSLocalizedString("Untitled Event", comment: "Fallback event title")
        let compactTitle = compact(title)
        let separator = NSLocalizedString(" · ", comment: "Menu bar separator between a title and a time")

        let statusTitle: String
        switch phase {
        case .now:
            if let joinProvider {
                statusTitle = String(
                    format: NSLocalizedString("Join now · %@", comment: "Menu bar when a meeting with a join link starts; provider name such as Zoom"),
                    joinProvider
                )
            } else {
                statusTitle = compactTitle + separator + NSLocalizedString("now", comment: "Menu bar: the event starts now")
            }
        case .soon where mode == .timeUntil:
            statusTitle = compactTitle + separator + minutesText(until: startDate, now: now)
        default:
            statusTitle = compactTitle + separator + clockText(startDate, now: now, calendar: calendar, locale: locale)
        }

        // The tooltip always names the event and its start time.
        let fullText = fullTitle ?? title
        let tooltip = fullText + separator + clockText(startDate, now: now, calendar: calendar, locale: locale)

        return StatusBarContent(title: statusTitle, tooltip: tooltip, urgency: urgency, phase: phase)
    }

    /// Content while a meeting runs: "18 min left".
    static func inProgress(title: String?, endDate: Date, now: Date = Date()) -> StatusBarContent {
        let remaining = max(0, endDate.timeIntervalSince(now))
        let totalMinutes = Int((remaining / 60).rounded(.up))
        let statusTitle: String
        if totalMinutes >= 60 {
            statusTitle = String(
                format: NSLocalizedString("%dh %dm left", comment: "Menu bar during a meeting: hours and minutes left"),
                totalMinutes / 60,
                totalMinutes % 60
            )
        } else {
            statusTitle = String(
                format: NSLocalizedString("%d min left", comment: "Menu bar during a meeting: minutes left"),
                max(totalMinutes, 1)
            )
        }
        let name = title ?? NSLocalizedString("Untitled Event", comment: "Fallback event title")
        let tooltip = name + NSLocalizedString(" · ", comment: "Menu bar separator between a title and a time") + statusTitle
        return StatusBarContent(title: statusTitle, tooltip: tooltip, urgency: .normal, phase: .inProgress)
    }

    /// Whether a running meeting should take the menu bar instead of the next
    /// event: only while the next event is still calm (or there is none).
    static func showsInProgress(nextPhase: MenuBarPhase?, hasOngoingMeeting: Bool) -> Bool {
        guard hasOngoingMeeting else { return false }
        guard let nextPhase else { return true }
        return nextPhase == .calm
    }

    static func compact(_ title: String) -> String {
        title.count > maxTitleLength
            ? String(title.prefix(maxTitleLength)).trimmingCharacters(in: .whitespaces) + "…"
            : title
    }

    /// "6 min", rounded up so the label never reads less than the real wait.
    static func minutesText(until startDate: Date, now: Date) -> String {
        let minutes = Int((max(0, startDate.timeIntervalSince(now)) / 60).rounded(.up))
        return String(format: NSLocalizedString("%d min", comment: "Menu bar: minutes until the next event"), max(minutes, 1))
    }

    /// "15:00" today, "Tue 15:00" on another day.
    static func clockText(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        } else {
            formatter.setLocalizedDateFormatFromTemplate("EEEjmm")
        }
        return formatter.string(from: date)
    }
}
