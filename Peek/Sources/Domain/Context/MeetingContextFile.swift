import Foundation

/// The meeting-context file another app (such as Northwind Notes) writes into a
/// folder the user chose, and Peek only reads (PEEK-213, ADR 0004). It is the
/// reverse direction of the PEEK-111 export: entries are keyed by the export's
/// opaque event `id`, so a writer can match what it read from
/// `Peek --export --json`.
///
/// Version 1 is a maintained contract. Unknown fields are ignored, so writers
/// may add fields; removing or retyping one needs `schemaVersion: 2`.
struct MeetingContextFile: Equatable {
    static let fileName = "peek-context.json"
    static let supportedSchemaVersion = 1

    /// Limits that keep a large or hostile file from slowing the popover.
    enum Limits {
        static let maxFileBytes = 1_048_576
        static let maxEvents = 1000
        static let maxHeadline = 200
        static let maxSummary = 1200
        static let maxBullets = 6
        static let maxBullet = 300
        static let maxPeople = 25
        static let maxPersonField = 200
        static let maxLinks = 6
        // The optional `day` object (PEEK-261).
        static let maxDayHeadline = 200
        static let maxDayPriorities = 5
        static let shownDayPriorities = 3
        static let maxDayPriority = 200
        static let maxDayLinks = 3
    }

    /// A file older than this is stale: the writer may have stopped. The day
    /// block hides and the meeting page says how old the context is (PEEK-264).
    static let staleAfter: TimeInterval = 36 * 60 * 60

    struct Person: Equatable {
        let email: String?
        let name: String?
        let role: String?
        let company: String?
        let note: String?
    }

    struct Link: Equatable {
        let title: String
        let url: URL
    }

    struct Entry: Equatable {
        let id: String
        /// Optional occurrence start; recurring events share one `id`.
        let startAt: Date?
        let headline: String?
        let summary: String?
        let bullets: [String]
        let people: [Person]
        let links: [Link]
    }

    /// The day's priorities and links (PEEK-261). Shown only on its own date and
    /// only while the file is fresh. Never sent to a brief engine (ADR 0005).
    struct Day: Equatable {
        struct Priority: Equatable {
            let text: String
            let done: Bool
        }

        let year: Int
        let month: Int
        let dayOfMonth: Int
        let headline: String?
        let priorities: [Priority]
        let links: [Link]

        /// What the popover shows: the first priorities, in order.
        var shownPriorities: [Priority] {
            Array(priorities.prefix(Limits.shownDayPriorities))
        }

        var isEmpty: Bool {
            headline == nil && priorities.isEmpty && links.isEmpty
        }

        /// Whether `date` falls on this day in the calendar's time zone.
        func isOn(_ date: Date, calendar: Calendar) -> Bool {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return components.year == year && components.month == month && components.day == dayOfMonth
        }
    }

    enum DecodeError: Error, Equatable {
        case tooLarge
        case malformed
        case unsupportedVersion(Int)
    }

    let generatedAt: Date?
    let entries: [Entry]
    /// Nil when absent, malformed or without a valid `date`.
    var day: Day? = nil

    /// Whether `generatedAt` is more than 36 hours before `now`. A file without
    /// `generatedAt` counts as fresh.
    func isStale(now: Date = Date()) -> Bool {
        guard let generatedAt else { return false }
        return now.timeIntervalSince(generatedAt) > Self.staleAfter
    }

    /// The day block to show now: only for today's date in the user's time
    /// zone, with something to show, and from a fresh file.
    func visibleDay(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Day? {
        guard !isStale(now: now), let day, !day.isEmpty, day.isOn(now, calendar: calendar) else { return nil }
        return day
    }

    /// The entry for an event occurrence. An entry with `startAt` matches only
    /// that occurrence (within a minute); one without matches every occurrence,
    /// and an exact occurrence match wins over it.
    func entry(forEventID id: String, start: Date?) -> Entry? {
        let candidates = entries.filter { $0.id == id }
        if let start, let exact = candidates.first(where: { entry in
            entry.startAt.map { abs($0.timeIntervalSince(start)) < 60 } ?? false
        }) {
            return exact
        }
        return candidates.first { $0.startAt == nil }
    }

    static func decode(_ data: Data) throws -> MeetingContextFile {
        guard data.count <= Limits.maxFileBytes else { throw DecodeError.tooLarge }
        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: data)
        } catch {
            throw DecodeError.malformed
        }
        guard raw.schemaVersion == supportedSchemaVersion else {
            throw DecodeError.unsupportedVersion(raw.schemaVersion)
        }
        let entries = (raw.events ?? []).prefix(Limits.maxEvents).compactMap(entry(from:))
        return MeetingContextFile(
            generatedAt: raw.generatedAt.flatMap(parseDate),
            entries: entries,
            day: raw.day?.value.flatMap(makeDay(from:))
        )
    }

    // MARK: Mapping

    private static func entry(from raw: Raw.Event) -> Entry? {
        guard let id = raw.id, !id.isEmpty else { return nil }
        return Entry(
            id: id,
            startAt: raw.startAt.flatMap(parseDate),
            headline: clipped(raw.headline, Limits.maxHeadline),
            summary: clipped(raw.summary, Limits.maxSummary),
            bullets: (raw.bullets ?? []).compactMap { clipped($0, Limits.maxBullet) }.prefix(Limits.maxBullets).map { $0 },
            people: (raw.people ?? []).prefix(Limits.maxPeople).map {
                Person(
                    email: clipped($0.email, Limits.maxPersonField),
                    name: clipped($0.name, Limits.maxPersonField),
                    role: clipped($0.role, Limits.maxPersonField),
                    company: clipped($0.company, Limits.maxPersonField),
                    note: clipped($0.note, Limits.maxSummary)
                )
            },
            links: (raw.links ?? []).compactMap(link(from:)).prefix(Limits.maxLinks).map { $0 }
        )
    }

    private static func makeDay(from raw: Raw.Day) -> Day? {
        guard let value = raw.date, let date = parseCalendarDate(value) else { return nil }
        return Day(
            year: date.year,
            month: date.month,
            dayOfMonth: date.day,
            headline: clipped(raw.headline, Limits.maxDayHeadline),
            priorities: (raw.priorities ?? [])
                .compactMap { $0.value }
                .compactMap { item -> Day.Priority? in
                    guard let text = clipped(item.text, Limits.maxDayPriority) else { return nil }
                    return Day.Priority(text: text, done: item.done ?? false)
                }
                .prefix(Limits.maxDayPriorities)
                .map { $0 },
            links: (raw.links ?? []).compactMap { $0.value }.compactMap(link(from:)).prefix(Limits.maxDayLinks).map { $0 }
        )
    }

    /// Only schemes in `ContextLinkPolicy`, so a context file cannot open
    /// local files, scripts or arbitrary apps.
    private static func link(from raw: Raw.Link) -> Link? {
        guard let value = raw.url, let url = URL(string: value), ContextLinkPolicy.isAllowed(url) else { return nil }
        let title = clipped(raw.title, Limits.maxPersonField) ?? url.host ?? value
        return Link(title: title, url: url)
    }

    /// A local calendar date, `YYYY-MM-DD`, that exists in the Gregorian calendar.
    static func parseCalendarDate(_ value: String) -> (year: Int, month: Int, day: Int)? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = DateComponents(calendar: calendar, year: year, month: month, day: day)
        guard components.isValidDate else { return nil }
        return (year, month, day)
    }

    private static func clipped(_ value: String?, _ limit: Int) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed.count > limit ? String(trimmed.prefix(limit - 1)) + "…" : trimmed
    }

    /// ISO 8601 with an offset, with or without fractional seconds, matching
    /// what the PEEK-111 export writes.
    static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private struct Raw: Decodable {
        let schemaVersion: Int
        let generatedAt: String?
        let events: [Event]?
        /// Lenient: a malformed `day` is dropped and the rest of the file still works.
        let day: Lenient<Day>?

        struct Day: Decodable {
            let date: String?
            let headline: String?
            let priorities: [Lenient<Priority>]?
            let links: [Lenient<Link>]?
        }

        struct Priority: Decodable {
            let text: String?
            let done: Bool?
        }

        struct Event: Decodable {
            let id: String?
            let startAt: String?
            let headline: String?
            let summary: String?
            let bullets: [String]?
            let people: [Person]?
            let links: [Link]?
        }

        struct Person: Decodable {
            let email: String?
            let name: String?
            let role: String?
            let company: String?
            let note: String?
        }

        struct Link: Decodable {
            let title: String?
            let url: String?
        }
    }
}

/// Decodes a value or nil, never failing the enclosing container.
private struct Lenient<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// The link schemes a context file may use (PEEK-262, ADR 0004). Fixed in code,
/// not configurable: `https` for web pages and `obsidian` for notes. Every other
/// scheme (`http`, `file`, `javascript`, `x-apple…`) is dropped when the file is
/// read, and checked again before a click opens a link.
enum ContextLinkPolicy {
    static let allowedSchemes: Set<String> = ["https", "obsidian"]

    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else { return false }
        switch scheme {
        case "https":
            return !(url.host ?? "").isEmpty
        default:
            // "obsidian://open?vault=…": something after the scheme is required.
            return url.absoluteString.count > scheme.count + "://".count
        }
    }
}
