import Foundation

/// One city's local time for the world clocks (PEEK-233).
struct WorldClockEntry: Equatable {
    let identifier: String
    let city: String
    let time: String
    /// Calendar days ahead of (positive) or behind (negative) the Mac's zone.
    let dayOffset: Int

    /// "09:00", or "09:00 +1" on another day.
    var text: String { WorldClock.withDayOffset(time, dayOffset) }
}

/// World clocks and meeting-time conversion (PEEK-233). Pure: the caller
/// passes the date, the zones and the reference zone.
enum WorldClock {
    static let maxZones = 6

    /// Offered in Preferences, roughly west to east.
    static let suggestedIdentifiers = [
        "Pacific/Honolulu", "America/Los_Angeles", "America/Denver", "America/Chicago",
        "America/Mexico_City", "America/New_York", "America/Toronto", "America/Sao_Paulo",
        "UTC", "Europe/Dublin", "Europe/London", "Europe/Lisbon", "Africa/Lagos",
        "Europe/Paris", "Europe/Madrid", "Europe/Rome", "Europe/Berlin", "Europe/Amsterdam",
        "Europe/Zurich", "Africa/Johannesburg", "Africa/Cairo", "Europe/Athens",
        "Europe/Istanbul", "Africa/Nairobi", "Europe/Moscow", "Asia/Dubai", "Asia/Karachi",
        "Asia/Kolkata", "Asia/Bangkok", "Asia/Singapore", "Asia/Hong_Kong", "Asia/Shanghai",
        "Asia/Seoul", "Asia/Tokyo", "Australia/Sydney", "Pacific/Auckland"
    ]

    /// "America/New_York" becomes "New York".
    static func cityName(for identifier: String) -> String {
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// Known zones only, without duplicates, at most `maxZones`.
    static func sanitized(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for identifier in identifiers where TimeZone(identifier: identifier) != nil && !seen.contains(identifier) {
            seen.insert(identifier)
            result.append(identifier)
            if result.count == maxZones { break }
        }
        return result
    }

    static func entries(
        at date: Date,
        zones: [String],
        reference: TimeZone = .current,
        locale: Locale = .current
    ) -> [WorldClockEntry] {
        zones.compactMap { identifier in
            guard let zone = TimeZone(identifier: identifier) else { return nil }
            return WorldClockEntry(
                identifier: identifier,
                city: cityName(for: identifier),
                time: timeString(date, in: zone, locale: locale),
                dayOffset: dayOffset(of: date, in: zone, relativeTo: reference)
            )
        }
    }

    /// "15:00 – 16:00" in `zone`, with "+1" when the start falls on another day.
    static func rangeText(
        start: Date,
        end: Date,
        in identifier: String,
        reference: TimeZone = .current,
        locale: Locale = .current
    ) -> String? {
        guard let zone = TimeZone(identifier: identifier) else { return nil }
        let range = timeString(start, in: zone, locale: locale) + " – " + timeString(end, in: zone, locale: locale)
        return withDayOffset(range, dayOffset(of: start, in: zone, relativeTo: reference))
    }

    static func dayOffset(of date: Date, in zone: TimeZone, relativeTo reference: TimeZone) -> Int {
        dayNumber(date, in: zone) - dayNumber(date, in: reference)
    }

    static func withDayOffset(_ text: String, _ offset: Int) -> String {
        guard offset != 0 else { return text }
        return text + (offset > 0 ? " +\(offset)" : " −\(-offset)")
    }

    private static func timeString(_ date: Date, in zone: TimeZone, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func dayNumber(_ date: Date, in zone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? zone
        guard let day = utc.date(from: parts) else { return 0 }
        return Int((day.timeIntervalSince1970 / 86_400).rounded(.down))
    }
}
