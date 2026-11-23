import Foundation

/// One event as the join shortcut sees it (PEEK-231).
struct JoinCandidate: Equatable {
    let start: Date
    let end: Date
    let hasJoinLink: Bool
}

/// Chooses the meeting the "Join next meeting" shortcut opens (PEEK-231).
enum JoinTargetPolicy {
    /// Meetings starting later than this are not joined from the shortcut.
    static let lookahead: TimeInterval = 30 * 60
    /// A meeting that started this recently counts as one you are late for.
    static let lateGrace: TimeInterval = 15 * 60
    /// A meeting about to start beats one you may already be in.
    static let imminent: TimeInterval = 2 * 60

    /// The index of the meeting to join, or nil when none has a link and fits
    /// the window. Order: one starting within two minutes, then one that
    /// started within fifteen, then the next within thirty, then the most
    /// recently started one still running.
    static func pick(_ candidates: [JoinCandidate], now: Date) -> Int? {
        let eligible = candidates.indices.filter {
            let c = candidates[$0]
            return c.hasJoinLink && c.end > now && c.start <= now.addingTimeInterval(lookahead)
        }
        let upcoming = eligible.filter { candidates[$0].start > now }
        let started = eligible.filter { candidates[$0].start <= now }
        let soonest = upcoming.min { candidates[$0].start < candidates[$1].start }
        let latestStarted = started.max { candidates[$0].start < candidates[$1].start }

        if let soonest, candidates[soonest].start.timeIntervalSince(now) <= imminent {
            return soonest
        }
        if let latestStarted, now.timeIntervalSince(candidates[latestStarted].start) <= lateGrace {
            return latestStarted
        }
        return soonest ?? latestStarted
    }
}

/// Which event the menu-bar countdown follows (PEEK-232).
enum StatusBarEventChooser {
    /// `upcoming` starts at `next`. With `onlyMeetings`, events without a join
    /// link are skipped; nil means no meeting is coming up.
    static func pick<T>(next: T?, upcoming: [T], onlyMeetings: Bool, hasJoinLink: (T) -> Bool) -> T? {
        guard onlyMeetings else { return next }
        return upcoming.first(where: hasJoinLink)
    }
}
